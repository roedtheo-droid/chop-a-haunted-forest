--!strict
-- The HUD's corners, in the timber look (sizes and texts in Config.Hud):
--   * top left: a plank with your health and your courage (see Server/Systems/CourageManager)
--   * top right: a plank with your logs (red when the sack is full), Embers and Coins, with a
--     "+15" that drops down when one goes up. Under it hangs a small tag for the tool trial:
--     "TRIAL 180s", the T key and its price. T (or tapping the tag) starts the trial, like the
--     trial table in the Tool Shed. While it runs it counts down ("TRIAL 2:59").
--     The quest note goes under that, in the same column (QuestController).
--   * phones and tablets only: CHOP and SELL log slices next to Roblox's jump button
-- The clock is top-middle (DayController) with the zone sign under it (ZoneController), the tools
-- bottom-middle (BackpackController) and the signpost on the right (MenuButtonsController).
-- It only DISPLAYS what the server sets on the player.

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
local Icons = require(script.Parent.Parent.Icons)
local UiKit = require(script.Parent.Parent.UiKit)
local ChopController = require(script.Parent.ChopController)

local Hud = Config.Hud
local Text = Hud.Text
local Timber = Config.TimberUi

local POP_TIME = 0.9
local PULSE_SPEED = 5 -- how fast the courage bar pulses when you're scared
local SELL_COOLDOWN = 0.5 -- seconds, so a double tap doesn't send it twice
local TRIAL_COOLDOWN = 1 -- seconds between two tries of the trial

local HudController = {}

type IconMaker = (parent: Instance, name: string) -> Frame

type Counter = {
	Attribute: string, -- the player attribute it shows, like "Coins"
	Holder: Frame,
	Label: TextLabel,
	Icon: Frame,
	Last: number, -- the amount it showed last time, to know how much it went up
}

local player = Players.LocalPlayer
local column: Frame
local healthBar: UiKit.Bar
local courageBar: UiKit.Bar
local healthWatchers: { RBXScriptConnection } = {}
local counters: { Counter } = {}
local backpackLabel: TextLabel
local backpackIcon: Frame
local lastCarry = 0
local trialTag: TextButton
local trialLabel: TextLabel
local trialKey: Frame
local trialPrice: TextLabel
local trialOffered = false -- true while the trial can be started
local touchButtons: Frame
local sellButton: TextButton
local sellFace: Frame
local sellValueLabel: TextLabel

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- The frame in the top-right corner where things are lined up under each other. The quest note
-- goes in it too, so it moves up when the trial tag is gone.
function HudController.rightColumn(): Frame
	return column
end

---------------------------------------------------------------------------------------------
-- Top left: health and courage

local function addVitalRow(plank: Frame, name: string, row: number, icon: IconMaker, color: Color3): UiKit.Bar
	local y = Hud.VitalsPad + (row - 0.5) * Hud.VitalsRow
	local iconLeft = Timber.NailInset + 6
	local barLeft = iconLeft + Hud.VitalsIcon + 4

	local picture = icon(plank, `{name}Icon`)
	picture.AnchorPoint = Vector2.new(0, 0.5)
	picture.Position = UDim2.fromOffset(iconLeft, y)
	picture.Size = UDim2.fromOffset(Hud.VitalsIcon, Hud.VitalsIcon)

	local bar = UiKit.bar(plank, `{name}Bar`, color)
	bar.Frame.AnchorPoint = Vector2.new(0, 0.5)
	bar.Frame.Position = UDim2.fromOffset(barLeft, y)
	bar.Frame.Size = UDim2.new(1, -(barLeft + Timber.NailInset + 12), 0, Hud.VitalsBarHeight)
	return bar
end

local function addVitals(gui: ScreenGui)
	local plank = UiKit.plank(gui, "Vitals", 2)
	plank.Position = UDim2.fromOffset(Hud.Margin, Hud.Margin)
	plank.Size = UDim2.fromOffset(Hud.VitalsWidth, 2 * (Hud.VitalsPad + Hud.VitalsRow))
	healthBar = addVitalRow(plank, "Health", 1, Icons.heart, Hud.Health)
	courageBar = addVitalRow(plank, "Courage", 2, Icons.ghost, Hud.Courage)
end

local function refreshHealth(humanoid: Humanoid)
	local maxHealth = math.max(humanoid.MaxHealth, 1)
	UiKit.setBar(healthBar, humanoid.Health / maxHealth, string.format(Text.Health, math.ceil(humanoid.Health)))
end

-- Your character (and its Humanoid) is new after you respawn.
local function watchHealth(character: Model)
	for _, connection in healthWatchers do
		connection:Disconnect()
	end
	table.clear(healthWatchers)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local function refresh()
		refreshHealth(humanoid)
	end
	refresh()
	table.insert(healthWatchers, humanoid.HealthChanged:Connect(refresh))
	table.insert(healthWatchers, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh))
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
-- Top right: logs, Embers and Coins

-- A "+N" that drops down from the counter and fades out, then removes itself.
local function popGain(holder: Frame, amount: number, color: Color3)
	local pop = UiKit.text(holder, "Pop", `+{Format.number(amount)}`, color)
	pop.AnchorPoint = Vector2.new(0.5, 0)
	pop.Position = UDim2.new(0.5, 0, 1, -10)
	pop.Size = UDim2.new(1, 0, 0, Hud.CounterText)
	pop.ZIndex = 2
	local stroke = pop:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(POP_TIME), { Transparency = 1 }):Play()
	end
	local tween = TweenService:Create(pop, TweenInfo.new(POP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = pop.Position + UDim2.fromOffset(0, Hud.CounterText),
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
		popGain(counter.Holder, amount - counter.Last, counter.Label.TextColor3)
		UiKit.bounce(counter.Icon)
	end
	counter.Last = amount
end

-- One counter on the ledger: an icon and the number next to it.
local function addCounter(row: Frame, name: string, icon: IconMaker, color: Color3, order: number): (Frame, Frame, TextLabel)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Size = UDim2.fromScale(Hud.CounterShare[order], 1)
	holder.Parent = row

	local picture = icon(holder, "Icon")
	picture.AnchorPoint = Vector2.new(0, 0.5)
	picture.Position = UDim2.fromScale(0, 0.5)
	picture.Size = UDim2.fromOffset(Hud.CounterIcon, Hud.CounterIcon)

	local label = UiKit.text(holder, "Amount", "0", color)
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, Hud.CounterIcon + 4, 0.5, 0)
	label.Size = UDim2.new(1, -(Hud.CounterIcon + 8), 0, Hud.CounterText)
	label.TextXAlignment = Enum.TextXAlignment.Left
	return holder, picture, label
end

local function addLedger()
	local ledger = UiKit.plank(column, "Ledger", 1)
	ledger.LayoutOrder = 1
	ledger.Size = UDim2.fromOffset(Hud.LedgerWidth, Hud.LedgerHeight)
	ledger.ZIndex = 2 -- so the "+15"s drop in front of the trial tag and the quest note

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.Size = UDim2.new(1, -2 * Timber.NailInset - 16, 1, 0)
	row.Parent = ledger

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local _, sack, logs = addCounter(row, "Logs", Icons.backpack, Timber.Text, 1)
	backpackIcon = sack
	backpackLabel = logs

	local emberHolder, emberIcon, emberLabel = addCounter(row, "Embers", Icons.ember, Config.Style.Ember, 2)
	table.insert(counters, { Attribute = "Embers", Holder = emberHolder, Label = emberLabel, Icon = emberIcon, Last = 0 })
	local coinHolder, coinIcon, coinLabel = addCounter(row, "Coins", Icons.coin, Config.Style.Gold, 3)
	table.insert(counters, { Attribute = "Coins", Holder = coinHolder, Label = coinLabel, Icon = coinIcon, Last = 0 })
end

local function refreshBackpack()
	local carry = getNumber("Carry")
	if carry > lastCarry then
		UiKit.bounce(backpackIcon)
	end
	lastCarry = carry
	if Shop.hasPerk(player, "InfiniteBag") then
		backpackLabel.Text = string.format(Text.InfiniteBackpack, carry)
		backpackLabel.TextColor3 = Timber.Text
		return
	end
	local limit = getNumber("CarryLimit")
	backpackLabel.Text = string.format(Text.Backpack, carry, limit)
	backpackLabel.TextColor3 = if limit > 0 and carry >= limit then Hud.FullText else Timber.Text
end

---------------------------------------------------------------------------------------------
-- Top right: the trial tag

-- Text at a fixed size that's exactly as wide as its words, for a row of things.
local function rowText(parent: Instance, name: string, color: Color3, order: number): TextLabel
	local label = UiKit.text(parent, name, "", color)
	label.LayoutOrder = order
	label.Size = UDim2.fromOffset(0, Hud.TrialText)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextScaled = false
	label.TextSize = Hud.TrialText
	return label
end

-- It hangs from the ledger on two short ropes: a tool with a flame, "TRIAL 180s", the T key and
-- the price.
local function addTrialTag()
	trialTag = Instance.new("TextButton")
	trialTag.Name = "Trial"
	trialTag.Text = ""
	trialTag.AutoButtonColor = false
	trialTag.BackgroundTransparency = 1
	trialTag.LayoutOrder = 2
	trialTag.Size = UDim2.fromOffset(Hud.TrialWidth, Hud.TrialHeight)
	trialTag.Parent = column

	local board = UiKit.plank(trialTag, "Board", 1)
	board.Size = UDim2.fromScale(1, 1)

	for _, x in { 0.14, 0.86 } do
		local rope = UiKit.rope(trialTag, "Rope", UDim2.new(x, 0, 0, -(Hud.ColumnGap + 10)), Hud.ColumnGap + 16)
		rope.ZIndex = 2
	end

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = board

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row

	local icon = Icons.flameTool(row, "Icon")
	icon.LayoutOrder = 1
	icon.Size = UDim2.fromOffset(Hud.TrialIcon, Hud.TrialIcon)

	trialLabel = rowText(row, "Label", Config.Style.Gold, 2)

	trialKey = UiKit.keyBadge(row, "Key", Text.TrialKey)
	trialKey.LayoutOrder = 3

	trialPrice = rowText(row, "Price", Hud.RobuxGreen, 4)
end

-- Before you try the tool: its length, the key and the price. While it runs: the time left.
-- Once you own the tool, the tag hides.
local function updateTrial()
	local cfg = Config.Trial
	if player:GetAttribute(Shop.ownsAttribute(cfg.ToolId)) == true then
		trialTag.Visible = false
		trialOffered = false
		return
	end
	trialTag.Visible = true
	local ends = player:GetAttribute(Shop.TRIAL_ENDS)
	if typeof(ends) == "number" then
		local left = math.max(0, math.floor(ends - workspace:GetServerTimeNow()))
		trialLabel.Text = string.format(cfg.Text.Hud, left // 60, left % 60)
		trialKey.Visible = false
		trialPrice.Visible = false
		trialOffered = false
		return
	end
	trialLabel.Text = string.format(Text.Trial, cfg.Seconds)
	trialKey.Visible = UiKit.hasKeyboard()
	trialPrice.Visible = true
	trialPrice.Text = if cfg.ProductId == 0 then Text.Free else string.format(Text.Robux, cfg.RobuxPrice)
	trialOffered = true
end

local function addColumn(gui: ScreenGui)
	column = Instance.new("Frame")
	column.Name = "RightColumn"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(1, 0)
	column.Position = UDim2.new(1, -Hud.Margin, 0, Hud.Margin)
	column.Size = UDim2.fromOffset(Hud.LedgerWidth, 0)
	column.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Hud.ColumnGap)
	layout.Parent = column

	addLedger()
	addTrialTag()
end

---------------------------------------------------------------------------------------------
-- Phones and tablets: the CHOP and SELL log slices

-- A log slice you can press, with a big word and a small line under it.
local function sliceButton(parent: Instance, name: string, faceColor: Color3, size: number, word: string): (TextButton, Frame, TextLabel)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromOffset(size, size)

	local slice, face = UiKit.logSlice(button, "Slice", faceColor)
	slice.Size = UDim2.fromScale(1, 1)

	local big = UiKit.text(button, "Word", word)
	big.Position = UDim2.fromScale(0.12, 0.26)
	big.Size = UDim2.fromScale(0.76, 0.32)
	big.ZIndex = 2
	local small = UiKit.smallText(button, "Small", "", Config.Style.Gold)
	small.Position = UDim2.fromScale(0.16, 0.58)
	small.Size = UDim2.fromScale(0.68, 0.18)
	small.ZIndex = 2

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
	return button, face, small
end

-- Roblox's jump button doesn't grow with the HUD, so the distance from it is worked out in real
-- screen pixels, on each screen size.
local function placeTouchButtons()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local screen = camera.ViewportSize
	local clear = if math.min(screen.X, screen.Y) <= Hud.SmallScreen then Hud.JumpClearSmall else Hud.JumpClearLarge
	local scale = UiKit.currentScale()
	touchButtons.Position = UDim2.new(1, -clear.X / scale, 1, -clear.Y / scale)
end

-- CHOP left of the jump button, and SELL above CHOP. Nothing goes under the thumbstick.
local function addTouchButtons(gui: ScreenGui)
	touchButtons = Instance.new("Frame")
	touchButtons.Name = "TouchButtons"
	touchButtons.BackgroundTransparency = 1
	touchButtons.AnchorPoint = Vector2.new(1, 1)
	touchButtons.Size = UDim2.fromOffset(Hud.ChopButtonSize, Hud.ChopButtonSize + Hud.TouchButtonGap + Hud.SellButtonSize)
	touchButtons.Visible = false
	touchButtons.Parent = gui
	placeTouchButtons()

	local chop = sliceButton(touchButtons, "Chop", Timber.Amber, Hud.ChopButtonSize, Text.Chop)
	chop.AnchorPoint = Vector2.new(0.5, 1)
	chop.Position = UDim2.fromScale(0.5, 1)
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

	local sell, face, value = sliceButton(touchButtons, "Sell", Config.Style.Green, Hud.SellButtonSize, Text.Sell)
	sell.AnchorPoint = Vector2.new(0.5, 0)
	sell.Position = UDim2.fromScale(0.5, 0)
	sellButton = sell
	sellFace = face
	sellValueLabel = value
end

-- SELL is green when you stand by a sawmill pad with logs (the server sets NearSellPad), and
-- pale otherwise. It shows what your logs are worth.
local function refreshSell()
	local value = getNumber("CarryValue") * Shop.coinMultiplier(player)
	sellValueLabel.Text = if value > 0 then `+{Format.number(value)}` else ""
	local ready = player:GetAttribute("NearSellPad") == true and getNumber("Carry") > 0
	sellFace.BackgroundColor3 = if ready then Config.Style.Green else Hud.SellDim
end

-- Only show them while you play with your fingers.
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
	-- Our plank replaces Roblox's health bar. (Do it before the intro and the Garage, which hide
	-- Roblox's menus and show them again afterwards: they only show again what was on.)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

	local gui = UiKit.screen("Hud")
	addVitals(gui)
	addColumn(gui)
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

	player.CharacterAdded:Connect(watchHealth)
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end

	lastCarry = getNumber("Carry")
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

	-- T or the tag starts the tool trial (the server checks everything, like at the trial table).
	local trialRemote = Remotes.getEvent("TryTrial")
	local lastTrial = 0
	local function tryTrial()
		local now = os.clock()
		if not trialOffered or now - lastTrial < TRIAL_COOLDOWN then
			return
		end
		lastTrial = now
		trialRemote:FireServer()
	end
	trialTag.Activated:Connect(tryTrial)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if not gameProcessed and input.KeyCode == Hud.TrialKey then
			tryTrial()
		end
	end)

	-- The log slices, for phones and tablets.
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
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(placeTouchButtons)
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
