--!strict
-- The HUD's left side, laid out like Chop a Forest (sizes and texts in Config.Hud):
--   * left middle: a big coin and your Coins, a big Ember and your Embers (with a "+15" that
--     floats up when one goes up), and under them the tool trial: "TRIAL 180s", the T key and
--     its price. T starts the trial, like the trial table in the Tool Shed. While it runs it
--     counts down ("TRIAL 2:59").
--   * bottom left: a big backpack and "0/5" (red when full), with the courage bar above it
--     (see Server/Systems/CourageManager)
--   * phones and tablets only: big round CHOP and SELL buttons in the bottom-right corner
-- The zone and run time are top-right (ZoneController), the quest top-left (QuestController),
-- the tool bar bottom-middle (BackpackController) and SHOP/UPGRADES right (MenuButtonsController).
-- It only DISPLAYS what the server sets on the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Icons = require(script.Parent.Parent.Icons)
local UiKit = require(script.Parent.Parent.UiKit)
local ChopController = require(script.Parent.ChopController)

local Hud = Config.Hud
local Text = Hud.Text

local POP_TIME = 0.9
local PULSE_SPEED = 5 -- how fast the courage bar pulses when you're scared
local SELL_COOLDOWN = 0.5 -- seconds, so a double tap doesn't send it twice
local TRIAL_COOLDOWN = 1 -- seconds between two presses of T

local HudController = {}

type Counter = {
	Attribute: string, -- the player attribute it shows, like "Coins"
	Label: TextLabel,
	Icon: Frame,
	Last: number, -- the amount it showed last time, to know how much it went up
}

local player = Players.LocalPlayer
local counters: { Counter } = {}
local trialRow: Frame
local trialLabel: TextLabel
local trialKey: Frame
local trialPrice: TextLabel
local backpackLabel: TextLabel
local courageBar: UiKit.Bar
local touchButtons: Frame
local sellButton: TextButton
local sellValueLabel: TextLabel

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

---------------------------------------------------------------------------------------------
-- Left middle: Coins, Embers and the trial

-- A "+N" that floats up next to the number and fades out, then removes itself.
local function popGain(label: TextLabel, amount: number)
	local pop = UiKit.text(label.Parent :: Instance, "Pop", `+{Format.number(amount)}`, label.TextColor3)
	pop.AnchorPoint = Vector2.new(0, 0.5)
	pop.Position = UDim2.new(0, label.Position.X.Offset + label.TextBounds.X + 12, 0.5, 0)
	pop.Size = UDim2.fromOffset(140, Hud.CurrencyText * 0.6)
	pop.TextXAlignment = Enum.TextXAlignment.Left
	local stroke = pop:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(POP_TIME), { Transparency = 1 }):Play()
	end
	local tween = TweenService:Create(pop, TweenInfo.new(POP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = pop.Position - UDim2.fromOffset(0, Hud.CurrencyText * 0.7),
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
		popGain(counter.Label, amount - counter.Last)
		UiKit.bounce(counter.Icon)
	end
	counter.Last = amount
end

-- One currency row: a big icon and the number next to it. `row` is 0 for the top row.
local function addCurrency(gui: ScreenGui, attribute: string, color: Color3, row: number)
	local holder = Instance.new("Frame")
	holder.Name = attribute
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, Hud.Margin, Hud.LeftY, row * (Hud.CurrencyIcon + Hud.CurrencyGap))
	holder.Size = UDim2.fromOffset(Hud.CurrencyWidth, Hud.CurrencyIcon)
	holder.Parent = gui

	local icon = if attribute == "Embers" then Icons.ember(holder, "Icon") else Icons.coin(holder, "Icon")
	icon.Size = UDim2.fromOffset(Hud.CurrencyIcon, Hud.CurrencyIcon)

	local label = UiKit.text(holder, "Amount", "0", color)
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, Hud.CurrencyIcon + 14, 0.5, 0)
	label.Size = UDim2.fromOffset(Hud.CurrencyWidth - Hud.CurrencyIcon - 14, Hud.CurrencyText)
	label.TextXAlignment = Enum.TextXAlignment.Left

	table.insert(counters, { Attribute = attribute, Label = label, Icon = icon, Last = 0 })
end

-- The trial row under the Embers: a tool with a flame, "TRIAL 180s", the T key and the price.
local function addTrialRow(gui: ScreenGui)
	trialRow = Instance.new("Frame")
	trialRow.Name = "Trial"
	trialRow.BackgroundTransparency = 1
	trialRow.AnchorPoint = Vector2.new(0, 0.5)
	trialRow.Position = UDim2.new(0, Hud.Margin + 10, Hud.LeftY, 2 * (Hud.CurrencyIcon + Hud.CurrencyGap) - 10)
	trialRow.Size = UDim2.fromOffset(Hud.CurrencyWidth, Hud.TrialIcon)
	trialRow.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = trialRow

	local icon = Icons.flameTool(trialRow, "Icon")
	icon.LayoutOrder = 1
	icon.Size = UDim2.fromOffset(Hud.TrialIcon, Hud.TrialIcon)

	trialLabel = UiKit.text(trialRow, "Label", "", Config.Style.Gold)
	trialLabel.LayoutOrder = 2
	trialLabel.Size = UDim2.fromOffset(0, Hud.TrialText)
	trialLabel.AutomaticSize = Enum.AutomaticSize.X
	trialLabel.TextScaled = false
	trialLabel.TextSize = Hud.TrialText

	trialKey = UiKit.keyBadge(trialRow, "Key", Text.TrialKey)
	trialKey.LayoutOrder = 3

	trialPrice = UiKit.text(trialRow, "Price", "", Hud.RobuxGreen)
	trialPrice.LayoutOrder = 4
	trialPrice.Size = UDim2.fromOffset(0, Hud.TrialText)
	trialPrice.AutomaticSize = Enum.AutomaticSize.X
	trialPrice.TextScaled = false
	trialPrice.TextSize = Hud.TrialText
end

-- Before you try the tool: its length, the key and the price. While it runs: the time left.
-- Once you own the tool, the row hides.
local function updateTrial()
	local cfg = Config.Trial
	if player:GetAttribute(Shop.ownsAttribute(cfg.ToolId)) == true then
		trialRow.Visible = false
		return
	end
	trialRow.Visible = true
	local ends = player:GetAttribute(Shop.TRIAL_ENDS)
	if typeof(ends) == "number" then
		local left = math.max(0, math.floor(ends - workspace:GetServerTimeNow()))
		trialLabel.Text = string.format(cfg.Text.Hud, left // 60, left % 60)
		trialKey.Visible = false
		trialPrice.Visible = false
		return
	end
	trialLabel.Text = string.format(Text.Trial, cfg.Seconds)
	trialKey.Visible = true
	trialPrice.Visible = true
	trialPrice.Text = if cfg.ProductId == 0 then Text.Free else string.format(Text.Robux, cfg.RobuxPrice)
end

---------------------------------------------------------------------------------------------
-- Bottom left: backpack and courage

local function addBackpack(gui: ScreenGui)
	local bottom = Config.FreeMouse.HintMargin + Config.FreeMouse.HintHeight + 8 -- above the key hint

	local holder = Instance.new("Frame")
	holder.Name = "Backpack"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, Hud.Margin, 1, -bottom)
	holder.Size = UDim2.fromOffset(Hud.CurrencyWidth, Hud.BackpackIcon)
	holder.Parent = gui

	local icon = Icons.backpack(holder, "Icon")
	icon.Size = UDim2.fromOffset(Hud.BackpackIcon, Hud.BackpackIcon)

	backpackLabel = UiKit.text(holder, "Count", "0/0")
	backpackLabel.AnchorPoint = Vector2.new(0, 0.5)
	backpackLabel.Position = UDim2.new(0, Hud.BackpackIcon + 12, 0.55, 0)
	backpackLabel.Size = UDim2.fromOffset(Hud.CurrencyWidth - Hud.BackpackIcon - 12, Hud.BackpackText)
	backpackLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- The courage bar, with a little ghost, just above the backpack.
	local courage = Instance.new("Frame")
	courage.Name = "Courage"
	courage.BackgroundTransparency = 1
	courage.AnchorPoint = Vector2.new(0, 1)
	courage.Position = UDim2.new(0, Hud.Margin, 1, -(bottom + Hud.BackpackIcon + 10))
	courage.Size = UDim2.fromOffset(Hud.CourageIcon + 8 + Hud.CourageWidth, Hud.CourageIcon)
	courage.Parent = gui

	local ghost = Icons.ghost(courage, "Icon")
	ghost.Size = UDim2.fromOffset(Hud.CourageIcon, Hud.CourageIcon)

	courageBar = UiKit.bar(courage, "Bar", Hud.Courage)
	courageBar.Frame.AnchorPoint = Vector2.new(0, 0.5)
	courageBar.Frame.Position = UDim2.new(0, Hud.CourageIcon + 8, 0.5, 0)
	courageBar.Frame.Size = UDim2.fromOffset(Hud.CourageWidth, Hud.CourageHeight)
end

local function refreshBackpack()
	local carry = getNumber("Carry")
	if Shop.hasPerk(player, "InfiniteBag") then
		backpackLabel.Text = string.format(Text.InfiniteBackpack, carry)
		backpackLabel.TextColor3 = Color3.new(1, 1, 1)
		return
	end
	local limit = getNumber("CarryLimit")
	backpackLabel.Text = string.format(Text.Backpack, carry, limit)
	backpackLabel.TextColor3 = if limit > 0 and carry >= limit then Config.Style.Red else Color3.new(1, 1, 1)
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
-- Phones and tablets: the big round CHOP and SELL buttons

-- A big round button with a thick black edge, a big word and a small line under it.
local function roundButton(parent: Instance, name: string, color: Color3, size: number, word: string): (TextButton, TextLabel)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = color
	button.Size = UDim2.fromOffset(size, size)
	UiKit.corner(button, 999)
	UiKit.border(button, Color3.new(0, 0, 0), 4)

	local big = UiKit.text(button, "Word", word)
	big.Position = UDim2.fromScale(0.1, 0.22)
	big.Size = UDim2.fromScale(0.8, 0.34)
	local small = UiKit.smallText(button, "Small", "", Config.Style.Gold)
	small.Position = UDim2.fromScale(0.15, 0.58)
	small.Size = UDim2.fromScale(0.7, 0.2)

	-- Squish a little while pressed.
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	button.InputBegan:Connect(function(input: InputObject)
		if isPress(input) then
			TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.9 }):Play()
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if isPress(input) then
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)

	button.Parent = parent
	return button, small
end

local function addTouchButtons(gui: ScreenGui)
	-- Bottom-right, above Roblox's jump button.
	touchButtons = Instance.new("Frame")
	touchButtons.Name = "TouchButtons"
	touchButtons.BackgroundTransparency = 1
	touchButtons.AnchorPoint = Vector2.new(1, 1)
	touchButtons.Position = UDim2.new(1, -Hud.Margin, 1, -Hud.TouchButtonsUp)
	touchButtons.Size = UDim2.fromOffset(Hud.ChopButtonSize + Hud.SellButtonSize + 16, Hud.ChopButtonSize)
	touchButtons.Visible = false
	touchButtons.Parent = gui

	local chop = roundButton(touchButtons, "Chop", Config.Style.Ember, Hud.ChopButtonSize, Text.Chop)
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

	local sell, value = roundButton(touchButtons, "Sell", Config.Style.Green, Hud.SellButtonSize, Text.Sell)
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
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	UiKit.hudScale(gui)

	addCurrency(gui, "Coins", Config.Style.Gold, 0)
	addCurrency(gui, "Embers", Config.Style.Ember, 1)
	addTrialRow(gui)
	addBackpack(gui)
	addTouchButtons(gui)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function HudController.start()
	RunService.Heartbeat:Connect(function()
		updateTrial()
		pulseCourage()
	end)

	refreshCourage()
	player:GetAttributeChangedSignal("Courage"):Connect(refreshCourage)

	refreshBackpack()
	for _, name in { "Carry", "CarryLimit", Shop.perkAttribute("InfiniteBag") } do
		player:GetAttributeChangedSignal(name):Connect(refreshBackpack)
	end

	for _, counter in counters do
		-- Start from the current amount so we don't "pop" the starting amount.
		counter.Last = getNumber(counter.Attribute)
		refresh(counter)
		player:GetAttributeChangedSignal(counter.Attribute):Connect(function()
			refresh(counter)
		end)
	end

	-- T starts the tool trial (the server checks everything, like at the trial table).
	local trialRemote = Remotes.getEvent("TryTrial")
	local lastTrial = 0
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or input.KeyCode ~= Hud.TrialKey or not trialRow.Visible or not trialKey.Visible then
			return
		end
		local now = os.clock()
		if now - lastTrial < TRIAL_COOLDOWN then
			return
		end
		lastTrial = now
		trialRemote:FireServer()
	end)

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
