--!strict
-- The purple HUD from Theo's Claude Design picture (colours and sizes in Config.Hud):
--   * top-left: your health and your courage (see Server/Systems/CourageManager)
--   * top-right: pills with your logs (12 / 50), Embers and Coins, with a small "+15" that
--     floats in when one goes up, and "TRIAL 2:59" under them while you try a tool
--   * phones and tablets only: big round CHOP and SELL buttons in the bottom-right corner
-- The quest panel (QuestController) sits under the pills and the tool bar (BackpackController)
-- at the bottom. Roblox's own health bar is switched off, because ours replaces it.
-- It only DISPLAYS what the server sets: player attributes and your character's health.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)
local UiKit = require(script.Parent.Parent.UiKit)
local ChopController = require(script.Parent.ChopController)

local Hud = Config.Hud

local POP_TIME = 0.9
local PULSE_SPEED = 5 -- how fast the courage bar pulses when you're scared
local SELL_COOLDOWN = 0.5 -- seconds, so a double tap doesn't send it twice

local HudController = {}

type Counter = {
	Attribute: string, -- the player attribute it shows, like "Coins"
	Label: TextLabel,
	Pill: Frame,
	Color: Color3,
	Last: number, -- the amount it showed last time, to know how much it went up
}

local player = Players.LocalPlayer
local counters: { Counter } = {}
local healthBar: UiKit.Bar
local courageBar: UiKit.Bar
local logsLabel: TextLabel
local logsLimitLabel: TextLabel
local trialLabel: TextLabel
local touchButtons: Frame
local sellButton: TextButton
local sellValueLabel: TextLabel
local healthConnection: RBXScriptConnection? = nil

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

---------------------------------------------------------------------------------------------
-- Top-left: health and courage

-- One row: a round icon and a bar next to it. `row` is 0 for the top row, 1 for the next.
local function addBarRow(gui: ScreenGui, name: string, color: Color3, glyph: string, row: number): UiKit.Bar
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(Hud.Margin, Hud.Margin + row * (Hud.IconSize + 10))
	holder.Size = UDim2.fromOffset(Hud.IconSize + 10 + Hud.BarWidth, Hud.IconSize)
	holder.Parent = gui

	local icon = UiKit.hudDot(holder, "Icon", color, glyph)
	icon.Size = UDim2.fromOffset(Hud.IconSize, Hud.IconSize)

	local bar = UiKit.hudBar(holder, "Bar", color)
	bar.Frame.AnchorPoint = Vector2.new(0, 0.5)
	bar.Frame.Position = UDim2.new(0, Hud.IconSize + 10, 0.5, 0)
	bar.Frame.Size = UDim2.fromOffset(Hud.BarWidth, Hud.BarHeight)
	return bar
end

local function refreshHealth(humanoid: Humanoid)
	local max = math.max(humanoid.MaxHealth, 1)
	local health = math.clamp(humanoid.Health, 0, max)
	UiKit.setBar(healthBar, health / max, string.format(Hud.HealthText, math.ceil(health), math.ceil(max)))
end

local function watchHealth(character: Model)
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not (humanoid and humanoid:IsA("Humanoid")) then
		return
	end
	refreshHealth(humanoid)
	healthConnection = humanoid.HealthChanged:Connect(function()
		refreshHealth(humanoid)
	end)
end

local function refreshCourage()
	local value = player:GetAttribute("Courage")
	local courage = if typeof(value) == "number" then value else Config.Courage.Max
	local low = courage < Config.Courage.LowAt
	courageBar.Fill.BackgroundColor3 = if low then Hud.Scared else Hud.Courage
	UiKit.setBar(courageBar, courage / Config.Courage.Max, string.format(Config.Courage.Text.Bar, math.ceil(courage)))
end

-- Below LowAt the red fill gently pulses, so you notice without a pop-up.
local function pulseCourage()
	local value = player:GetAttribute("Courage")
	local low = typeof(value) == "number" and value < Config.Courage.LowAt
	courageBar.Fill.BackgroundTransparency = if low then 0.35 * (0.5 + 0.5 * math.sin(os.clock() * PULSE_SPEED)) else 0
end

---------------------------------------------------------------------------------------------
-- Top-right: logs, Embers and Coins

-- A rounded pill with a round dot on the left and a big number next to it.
local function addPill(row: Frame, name: string, color: Color3, width: number, order: number): (Frame, TextLabel)
	local pill = Instance.new("Frame")
	pill.Name = name
	pill.LayoutOrder = order
	pill.BackgroundColor3 = Hud.Track
	pill.BackgroundTransparency = Hud.PanelTransparency
	pill.Size = UDim2.fromOffset(width, Hud.PillHeight)
	UiKit.corner(pill, 999)
	UiKit.border(pill, Hud.Edge, Hud.EdgeThickness)
	pill.Parent = row

	local dotSize = Hud.PillHeight - 12
	local dot = UiKit.hudDot(pill, "Dot", color)
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.new(0, 6, 0.5, 0)
	dot.Size = UDim2.fromOffset(dotSize, dotSize)

	local label = UiKit.hudText(pill, "Amount", "0", 22)
	label.Position = UDim2.fromOffset(dotSize + 14, 0)
	label.Size = UDim2.new(1, -(dotSize + 20), 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	return pill, label
end

-- A "+N" that floats up into the pill and fades out, then removes itself.
local function popGain(counter: Counter, amount: number)
	local pop = UiKit.hudText(counter.Pill, "Pop", `+{Format.number(amount)}`, 18, counter.Color)
	pop.AnchorPoint = Vector2.new(0.5, 0)
	pop.Position = UDim2.new(0.5, 0, 1, 22)
	pop.Size = UDim2.new(1, 0, 0, 20)
	local stroke = pop:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(POP_TIME), { Transparency = 1 }):Play()
	end
	local tween = TweenService:Create(pop, TweenInfo.new(POP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, 2),
		TextTransparency = 1,
	})
	tween.Completed:Connect(function()
		pop:Destroy()
	end)
	tween:Play()
end

local function refresh(counter: Counter)
	local amount = getNumber(counter.Attribute)
	counter.Label.Text = Format.number(amount)
	if amount > counter.Last then
		popGain(counter, amount - counter.Last)
		UiKit.bounce(counter.Pill)
	end
	counter.Last = amount
end

local function refreshLogs()
	local carry = getNumber("Carry")
	logsLabel.Text = tostring(carry)
	if Shop.hasPerk(player, "InfiniteBag") then
		logsLimitLabel.Text = Hud.InfiniteText
		logsLabel.TextColor3 = Hud.Ink
		return
	end
	local limit = getNumber("CarryLimit")
	logsLimitLabel.Text = `/ {limit}`
	logsLabel.TextColor3 = if limit > 0 and carry >= limit then Hud.Full else Hud.Ink
end

local function addPills(gui: ScreenGui)
	local row = Instance.new("Frame")
	row.Name = "Pills"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(1, 0)
	row.Position = UDim2.new(1, -Hud.Margin, 0, Hud.Margin)
	row.Size = UDim2.fromOffset(Hud.LogsPillWidth + 2 * (Hud.CoinPillWidth + Hud.PillGap), Hud.PillHeight)
	row.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Hud.PillGap)
	layout.Parent = row

	-- Logs: "12" big, "/ 50" small and faded on the right.
	local logsPill, label = addPill(row, "Logs", Hud.Wood, Hud.LogsPillWidth, 1)
	logsLabel = label
	logsLabel.Size = UDim2.new(0.5, 0, 1, 0)
	logsLimitLabel = UiKit.hudText(logsPill, "Limit", "", 14, Hud.Muted)
	logsLimitLabel.AnchorPoint = Vector2.new(1, 0)
	logsLimitLabel.Position = UDim2.new(1, -14, 0, 0)
	logsLimitLabel.Size = UDim2.new(0.4, 0, 1, 0)
	logsLimitLabel.TextXAlignment = Enum.TextXAlignment.Right

	for index, info in { { Attribute = "Embers", Color = Hud.Ember }, { Attribute = "Coins", Color = Hud.Gold } } do
		local pill, amount = addPill(row, info.Attribute, info.Color, Hud.CoinPillWidth, index + 1)
		table.insert(counters, { Attribute = info.Attribute, Label = amount, Pill = pill, Color = info.Color, Last = 0 })
	end
end

-- "TRIAL 2:59" under the pills while you're trying a tool from the trial table. The server
-- sets when the trial ends (Shop.TRIAL_ENDS, in server time) and removes it when it's over.
local function addTrialTimer(gui: ScreenGui)
	trialLabel = UiKit.hudText(gui, "Trial", "", 18, Hud.Gold)
	trialLabel.AnchorPoint = Vector2.new(1, 0)
	trialLabel.Position = UDim2.new(1, -Hud.Margin - 8, 0, Hud.Margin + Hud.PillHeight + 6)
	trialLabel.Size = UDim2.fromOffset(200, 22)
	trialLabel.TextXAlignment = Enum.TextXAlignment.Right
	trialLabel.Visible = false
end

local function updateTrialTimer()
	local ends = player:GetAttribute(Shop.TRIAL_ENDS)
	if typeof(ends) ~= "number" then
		trialLabel.Visible = false
		return
	end
	local left = math.max(0, math.floor(ends - workspace:GetServerTimeNow()))
	trialLabel.Text = string.format(Config.Trial.Text.Hud, left // 60, left % 60)
	trialLabel.Visible = true
end

---------------------------------------------------------------------------------------------
-- Phones and tablets: the big round CHOP and SELL buttons

-- A big round button with a darker rim at the bottom, a big word and a small line under it.
local function roundButton(parent: Instance, name: string, color: Color3, size: number, word: string, small: string): (TextButton, TextLabel)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = color
	button.Size = UDim2.fromOffset(size, size)
	UiKit.corner(button, 999)
	UiKit.border(button, color:Lerp(Color3.new(0, 0, 0), 0.35), 5)

	local big = UiKit.hudText(button, "Word", word, math.floor(size * 0.22), Hud.Panel)
	big.Position = UDim2.fromScale(0, 0.22)
	big.Size = UDim2.fromScale(1, 0.34)
	local smallLabel = UiKit.hudText(button, "Small", small, math.floor(size * 0.12), Hud.Panel)
	smallLabel.Position = UDim2.fromScale(0, 0.56)
	smallLabel.Size = UDim2.fromScale(1, 0.18)
	for _, label in { big, smallLabel } do
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Enabled = false
		end
	end

	-- Squish a little while pressed.
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.9 }):Play()
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)

	button.Parent = parent
	return button, smallLabel
end

local function addTouchButtons(gui: ScreenGui)
	-- Bottom-right, above Roblox's jump button.
	touchButtons = Instance.new("Frame")
	touchButtons.Name = "TouchButtons"
	touchButtons.BackgroundTransparency = 1
	touchButtons.AnchorPoint = Vector2.new(1, 1)
	touchButtons.Position = UDim2.new(1, -Hud.Margin, 1, -Hud.TouchButtonsUp)
	touchButtons.Size = UDim2.fromOffset(Hud.ChopButtonSize + Hud.SellButtonSize + 12, Hud.ChopButtonSize)
	touchButtons.Visible = false
	touchButtons.Parent = gui

	local chop = roundButton(touchButtons, "Chop", Hud.Orange, Hud.ChopButtonSize, "CHOP", "HOLD")
	chop.AnchorPoint = Vector2.new(1, 1)
	chop.Position = UDim2.fromScale(1, 1)
	-- Hold the button to keep chopping, like holding the mouse button.
	chop.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			ChopController.setButtonHeld(true)
		end
	end)
	chop.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			ChopController.setButtonHeld(false)
		end
	end)

	local sell, value = roundButton(touchButtons, "Sell", Hud.Green, Hud.SellButtonSize, "SELL", "")
	sell.AnchorPoint = Vector2.new(0, 1)
	sell.Position = UDim2.fromScale(0, 1)
	sellButton = sell
	sellValueLabel = value
end

-- SELL is bright when you stand by a sawmill pad with logs (the server sets NearSellPad),
-- and faded otherwise. It shows what your logs are worth.
local function refreshSell()
	local value = getNumber("CarryValue") * Shop.coinMultiplier(player)
	sellValueLabel.Text = if value > 0 then `+{Format.number(value)}` else ""
	local ready = player:GetAttribute("NearSellPad") == true and getNumber("Carry") > 0
	sellButton.BackgroundTransparency = if ready then 0 else Hud.SellDimTransparency
end

-- Only show the round buttons while you play with your fingers.
local function refreshTouchMode(inputType: Enum.UserInputType)
	local touch = inputType == Enum.UserInputType.Touch
	if touch ~= touchButtons.Visible then
		touchButtons.Visible = touch
		if not touch then
			ChopController.setButtonHeld(false)
		end
	end
end

---------------------------------------------------------------------------------------------

function HudController.init()
	-- Our health bar replaces Roblox's. (The tool bar replaces Roblox's too, see BackpackController.)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	UiKit.hudScale(gui)

	healthBar = addBarRow(gui, "Health", Hud.Heart, Hud.HeartIcon, 0)
	courageBar = addBarRow(gui, "Courage", Hud.Courage, Hud.CourageIcon, 1)
	addPills(gui)
	addTrialTimer(gui)
	addTouchButtons(gui)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function HudController.start()
	RunService.Heartbeat:Connect(function()
		updateTrialTimer()
		pulseCourage()
	end)

	if player.Character then
		task.spawn(watchHealth, player.Character)
	end
	player.CharacterAdded:Connect(watchHealth)

	refreshCourage()
	player:GetAttributeChangedSignal("Courage"):Connect(refreshCourage)

	refreshLogs()
	for _, name in { "Carry", "CarryLimit", Shop.perkAttribute("InfiniteBag") } do
		player:GetAttributeChangedSignal(name):Connect(refreshLogs)
	end

	for _, counter in counters do
		-- Start from the current amount so we don't "pop" the starting amount.
		counter.Last = getNumber(counter.Attribute)
		refresh(counter)
		player:GetAttributeChangedSignal(counter.Attribute):Connect(function()
			refresh(counter)
		end)
	end

	-- The round buttons, for phones and tablets.
	local sellRemote = Remotes.getEvent("SellLogs")
	local lastSell = 0
	sellButton.Activated:Connect(function()
		local now = os.clock()
		if now - lastSell < SELL_COOLDOWN then
			return
		end
		lastSell = now
		sellRemote:FireServer()
	end)
	refreshSell()
	for _, name in { "Carry", "CarryValue", "NearSellPad", Shop.perkAttribute("DoubleCoins") } do
		player:GetAttributeChangedSignal(name):Connect(refreshSell)
	end
	local startsTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	refreshTouchMode(if startsTouch then Enum.UserInputType.Touch else UserInputService:GetLastInputType())
	UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		-- Moving the mouse or pressing a key on a laptop with a touch screen hides them again.
		if inputType ~= Enum.UserInputType.None and inputType ~= Enum.UserInputType.Focus then
			refreshTouchMode(inputType)
		end
	end)
end

return HudController
