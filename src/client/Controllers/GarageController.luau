--!strict
-- The Garage screen (see Config.Garage). Walking onto the glowing pad in front of the Garage
-- opens it: the camera cuts to the showroom (see Client/Showroom) and the normal HUD hides,
-- except your Coins and Embers, small in the top-left.
--   * top: a small gold "GARAGE", the truck's name very big, and "TIER 1 · 1 / 10" in orange
--   * green arrow buttons on the left and right to browse the trucks
--   * bottom: Speed and Carry bars, *PERMANENT* for Ember and Robux trucks, a big white BUY
--     button (a moving rainbow for Robux) and a red BACK button
--   * bottom-right on some trucks: the SKINS panel (only for looks, the Halloween skin is locked)
-- BACK puts the camera back on you, standing on the pad. To open it again, step off and on.
-- It only SHOWS prices and what you own; BUY just asks the server (see GarageManager).
-- For a truck you own, BUY becomes SPAWN: the server parks it by the Garage (see TruckManager).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Trucks = require(ReplicatedStorage.Shared.Trucks)
local Types = require(ReplicatedStorage.Shared.Types)
local Showroom = require(script.Parent.Parent.Showroom)
local UiKit = require(script.Parent.Parent.UiKit)

local Style = Config.Style
local Text = Config.Garage.Text
local DARK_TEXT = Color3.fromRGB(45, 40, 38)
local PURPLE = Color3.fromRGB(140, 70, 200)
local DESIGN_HEIGHT = 720 -- the screen height the layout is made for; smaller screens scale it down
-- Screens that stay while the Garage is open (the messages, like "You bought the ...!").
local KEEP_GUIS = { Garage = true, Notify = true }
-- Roblox's own menus, hidden while the Garage is open (the hotbar would cover the BUY button).
local CORE_GUIS = { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health }

local GarageController = {}

local player = Players.LocalPlayer
local buyRemote: RemoteEvent
local spawnRemote: RemoteEvent
local gui: ScreenGui
local scales: { UIScale } = {}

-- The parts of the screen that change.
local nameLabel: TextLabel
local tierLabel: TextLabel
local speedBar: UiKit.Bar
local carryBar: UiKit.Bar
local speedNumber: TextLabel
local carryNumber: TextLabel
local permanentLabel: TextLabel
local buyButton: TextButton
local buyGradient: UIGradient
local buyWord: TextLabel
local buyIcons: { [string]: Frame } = {}
local buyPrice: TextLabel
local skinsHolder: Frame
local standardSwatch: Frame
local coinsLabel: TextLabel
local embersLabel: TextLabel

local isOpen = false
local wasOnPad = false
local index = 1 -- the truck being shown (in Config.Trucks)
local hiddenGuis: { ScreenGui } = {}
local hiddenCore: { Enum.CoreGuiType } = {}
local controls: any = nil -- Roblox's movement controls (see getControls)

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- Roblox's movement controls live in its PlayerModule script (like in IntroController).
local function getControls(): any
	local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
	if not playerModule then
		return nil
	end
	local ok, module = pcall(require :: any, playerModule)
	return if ok and module then module:GetControls() else nil
end

-- A frame with no background that holds a group of things, scaled down on small screens.
local function group(name: string, anchor: Vector2, position: UDim2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = size
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	table.insert(scales, scale)
	return frame
end

-- Text with a fixed size that grows sideways to fit (for rows laid out by a UIListLayout).
local function fitText(parent: Instance, name: string, text: string, size: number, color: Color3): TextLabel
	local label = UiKit.text(parent, name, text, color)
	label.TextScaled = false
	label.TextSize = size
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	return label
end

-- A little log: brown with a light end.
local function logIcon(parent: Instance, name: string): Frame
	local icon = Instance.new("Frame")
	icon.Name = name
	icon.BackgroundColor3 = Color3.fromRGB(120, 75, 45)
	UiKit.corner(icon, 4)
	UiKit.border(icon)
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.55, 0.55)
	inner.BackgroundColor3 = Style.InnerWood
	inner.BorderSizePixel = 0
	UiKit.corner(inner, 3)
	inner.Parent = icon
	icon.Parent = parent
	return icon
end

-- A padlock drawn from frames.
local function padlock(parent: Instance): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Padlock"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.45)
	holder.Size = UDim2.fromOffset(34, 40)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 3
	local shackle = Instance.new("Frame")
	shackle.AnchorPoint = Vector2.new(0.5, 0)
	shackle.Position = UDim2.fromScale(0.5, 0)
	shackle.Size = UDim2.fromOffset(20, 24)
	shackle.BackgroundTransparency = 1
	shackle.ZIndex = 3
	UiKit.corner(shackle, 10)
	UiKit.border(shackle, Color3.fromRGB(200, 200, 205), 4)
	shackle.Parent = holder
	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromOffset(34, 24)
	body.BackgroundColor3 = Style.Gold
	body.ZIndex = 4
	UiKit.corner(body, 5)
	UiKit.border(body)
	body.Parent = holder
	holder.Parent = parent
	return holder
end

-- A small coloured tag with outlined text, like "EQUIPPED".
local function tag(parent: Instance, text: string, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Tag"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, -10)
	frame.Size = UDim2.new(0.9, 0, 0, 22)
	frame.BackgroundColor3 = color
	frame.ZIndex = 5
	UiKit.corner(frame, 6)
	UiKit.border(frame)
	frame.Parent = parent
	local label = UiKit.smallText(frame, "Text", text)
	label.Size = UDim2.new(1, -8, 1, -4)
	label.Position = UDim2.fromOffset(4, 2)
	label.ZIndex = 6
	return frame
end

-- One skin tile: a colour swatch and a name, with a tag on top.
local function skinTile(parent: Instance, name: string, order: number): (Frame, Frame)
	local tile = Instance.new("Frame")
	tile.Name = name
	tile.LayoutOrder = order
	tile.Size = UDim2.fromOffset(124, 104)
	tile.BackgroundColor3 = Color3.fromRGB(60, 54, 50)
	UiKit.corner(tile)
	UiKit.border(tile)
	tile.Parent = parent
	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.AnchorPoint = Vector2.new(0.5, 0)
	swatch.Position = UDim2.new(0.5, 0, 0, 18)
	swatch.Size = UDim2.new(1, -24, 0, 52)
	UiKit.corner(swatch, 6)
	UiKit.border(swatch)
	swatch.Parent = tile
	local label = UiKit.smallText(tile, "Name", name)
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -6)
	label.Size = UDim2.new(1, -10, 0, 22)
	return tile, swatch
end

local function buildTop()
	local top = group("Top", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12), UDim2.fromOffset(760, 150))
	local title = UiKit.text(top, "Title", Text.Title, Style.Gold, Style.TitleFont)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0)
	title.Size = UDim2.fromOffset(220, 30)

	nameLabel = UiKit.text(top, "TruckName", "", Color3.new(1, 1, 1), Style.TitleFont)
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.new(0.5, 0, 0, 34)
	nameLabel.Size = UDim2.new(1, 0, 0, 76)
	local stroke = nameLabel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 5
	end

	tierLabel = UiKit.text(top, "Tier", "", Config.Garage.NeonOrange)
	tierLabel.AnchorPoint = Vector2.new(0.5, 0)
	tierLabel.Position = UDim2.new(0.5, 0, 0, 114)
	tierLabel.Size = UDim2.fromOffset(380, 30)
end

local function buildArrows()
	for _, side in { -1, 1 } do
		local holder = group(
			if side < 0 then "PreviousHolder" else "NextHolder",
			Vector2.new(if side < 0 then 0 else 1, 0.5),
			UDim2.new(if side < 0 then 0 else 1, -side * 24, 0.45, 0),
			UDim2.fromOffset(96, 96)
		)
		local button = UiKit.button(holder, if side < 0 then "Previous" else "Next", if side < 0 then "<" else ">", Style.Green)
		button.Size = UDim2.fromScale(1, 1)
		local label = button:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			label.Font = Style.TitleFont
		end
		button.Activated:Connect(function()
			index = (index - 1 + side) % #Trucks.List + 1
			local truck = Trucks.List[index]
			Showroom.show(truck.Look, truck.Id, true)
			GarageController.refresh()
		end)
	end
end

-- One stats row: a name, a bar and a number (and an icon before the number, for Carry).
local function statRow(parent: Instance, name: string, y: number, color: Color3, withLog: boolean): (UiKit.Bar, TextLabel)
	local label = UiKit.text(parent, `{name}Label`, name)
	label.Position = UDim2.fromOffset(0, y)
	label.Size = UDim2.fromOffset(96, 30)
	label.TextXAlignment = Enum.TextXAlignment.Left
	local bar = UiKit.bar(parent, `{name}Bar`, color)
	bar.Frame.Position = UDim2.fromOffset(104, y + 4)
	bar.Frame.Size = UDim2.fromOffset(250, 22)
	if withLog then
		local icon = logIcon(parent, "LogIcon")
		icon.Position = UDim2.fromOffset(364, y + 3)
		icon.Size = UDim2.fromOffset(24, 24)
	end
	local number = UiKit.text(parent, `{name}Number`, "")
	number.Position = UDim2.fromOffset(if withLog then 394 else 364, y)
	number.Size = UDim2.fromOffset(70, 30)
	number.TextXAlignment = Enum.TextXAlignment.Left
	return bar, number
end

local function buildBottom()
	local bottom = group("Bottom", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -14), UDim2.fromOffset(470, 290))

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.AnchorPoint = Vector2.new(0.5, 0)
	stats.Position = UDim2.fromScale(0.5, 0)
	stats.Size = UDim2.fromOffset(464, 76)
	stats.BackgroundTransparency = 1
	stats.Parent = bottom
	speedBar, speedNumber = statRow(stats, Text.Speed, 0, Config.Garage.NeonOrange, false)
	carryBar, carryNumber = statRow(stats, Text.Carry, 40, Style.Green, true)

	permanentLabel = UiKit.text(bottom, "Permanent", Text.Permanent, Style.Red)
	permanentLabel.AnchorPoint = Vector2.new(0.5, 0)
	permanentLabel.Position = UDim2.new(0.5, 0, 0, 86)
	permanentLabel.Size = UDim2.fromOffset(240, 24)

	-- The big white BUY button: "BUY", an icon and the price in a row.
	local button = UiKit.button(bottom, "Buy", "", Color3.new(1, 1, 1))
	buyButton = button
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 114)
	button.Size = UDim2.fromOffset(320, 76)
	local oldLabel = button:FindFirstChild("Label")
	if oldLabel then
		oldLabel:Destroy()
	end
	buyGradient = Instance.new("UIGradient")
	buyGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 70)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 230, 100)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 200, 255)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(190, 120, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 90)),
	})
	buyGradient.Enabled = false
	buyGradient.Parent = button

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.Size = UDim2.new(1, -20, 0, 44)
	row.BackgroundTransparency = 1
	row.Parent = button
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row
	buyWord = fitText(row, "Word", Text.Buy, 40, DARK_TEXT)
	buyWord.Font = Style.TitleFont
	buyWord.LayoutOrder = 1
	for _, currency in { "Coins", "Embers" } do
		local icon = if currency == "Coins" then UiKit.coin(row, currency) else UiKit.ember(row, currency)
		icon.Size = UDim2.fromOffset(34, 34)
		icon.LayoutOrder = 2
		buyIcons[currency] = icon
	end
	buyPrice = fitText(row, "Price", "", 40, DARK_TEXT)
	buyPrice.Font = Style.TitleFont
	buyPrice.LayoutOrder = 3
	for _, label in { buyWord, buyPrice } do
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Thickness = 1
		end
	end
	button.Activated:Connect(function()
		local truck = Trucks.List[index]
		if Trucks.owns(player, truck.Id) then
			spawnRemote:FireServer(truck.Id)
			GarageController.close()
		elseif not (truck.Currency == "Robux" and truck.ProductId == 0) then
			buyRemote:FireServer(truck.Id)
		end
	end)

	local back = UiKit.button(bottom, "Back", Text.Back, Style.Red)
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.Position = UDim2.new(0.5, 0, 0, 204)
	back.Size = UDim2.fromOffset(200, 56)
	back.Activated:Connect(function()
		GarageController.close()
	end)
end

local function buildSkins()
	local holder = group("SkinsHolder", Vector2.new(1, 1), UDim2.new(1, -20, 1, -20), UDim2.fromOffset(300, 214))
	skinsHolder = holder
	local skinsPanel = UiKit.box(holder, "Skins")
	skinsPanel.Size = UDim2.fromScale(1, 1)

	local title = UiKit.text(skinsPanel, "Title", Text.Skins, Color3.new(1, 1, 1), Style.TitleFont)
	title.Position = UDim2.fromOffset(14, 10)
	title.Size = UDim2.fromOffset(120, 30)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local owned = UiKit.smallText(skinsPanel, "Owned", string.format(Text.SkinsOwned, 1), Style.Cream)
	owned.AnchorPoint = Vector2.new(1, 0)
	owned.Position = UDim2.new(1, -14, 0, 14)
	owned.Size = UDim2.fromOffset(110, 22)
	owned.TextXAlignment = Enum.TextXAlignment.Right

	local tiles = Instance.new("Frame")
	tiles.Name = "Tiles"
	tiles.Position = UDim2.fromOffset(12, 58)
	tiles.Size = UDim2.new(1, -24, 0, 106)
	tiles.BackgroundTransparency = 1
	tiles.Parent = skinsPanel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = tiles

	local standard, swatch = skinTile(tiles, Text.Standard, 1)
	standardSwatch = swatch
	tag(standard, Text.Equipped, Style.Green)
	local halloween, pumpkin = skinTile(tiles, Text.HalloweenSkin, 2)
	pumpkin.BackgroundColor3 = Color3.fromRGB(235, 120, 30)
	local stripe = Instance.new("Frame")
	stripe.AnchorPoint = Vector2.new(0, 0.5)
	stripe.Position = UDim2.fromScale(0, 0.5)
	stripe.Size = UDim2.new(1, 0, 0.3, 0)
	stripe.BackgroundColor3 = PURPLE
	stripe.BorderSizePixel = 0
	stripe.Parent = pumpkin
	-- Locked: darkened, with a padlock over it.
	local shade = Instance.new("Frame")
	shade.Name = "Locked"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.ZIndex = 2
	UiKit.corner(shade)
	shade.Parent = halloween
	padlock(halloween)
	tag(halloween, Text.HalloweenTag, PURPLE)

	local footer = UiKit.smallText(skinsPanel, "Footer", Text.SkinsFooter, Style.Cream)
	footer.AnchorPoint = Vector2.new(0.5, 1)
	footer.Position = UDim2.new(0.5, 0, 1, -10)
	footer.Size = UDim2.new(1, -20, 0, 20)
end

-- Your Coins and Embers, small in the top-left (the normal HUD is hidden).
local function buildCounters()
	local holder = group("Counters", Vector2.zero, UDim2.fromOffset(14, 14), UDim2.fromOffset(170, 66))
	for row, currency in { "Coins", "Embers" } do
		local icon = if currency == "Coins" then UiKit.coin(holder, `{currency}Icon`) else UiKit.ember(holder, `{currency}Icon`)
		icon.Position = UDim2.fromOffset(0, (row - 1) * 34)
		icon.Size = UDim2.fromOffset(28, 28)
		local amount = UiKit.text(holder, currency, "0", if currency == "Coins" then Style.Gold else Style.Ember)
		amount.Position = UDim2.fromOffset(36, (row - 1) * 34 + 1)
		amount.Size = UDim2.fromOffset(130, 26)
		amount.TextXAlignment = Enum.TextXAlignment.Left
		if currency == "Coins" then
			coinsLabel = amount
		else
			embersLabel = amount
		end
	end
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "Garage"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.DisplayOrder = 7
	gui:SetAttribute(UiKit.HIDES_ARMS, true)
	UiKit.freeMouse(gui) -- so you can click the buttons in first person
	buildTop()
	buildArrows()
	buildBottom()
	buildSkins()
	buildCounters()
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Scale everything down on screens smaller than the layout was made for.
local function updateScale()
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else DESIGN_HEIGHT
	local scale = math.clamp(height / DESIGN_HEIGHT, 0.5, 1)
	for _, uiScale in scales do
		uiScale.Scale = scale
	end
end

local function setBuy(word: string, currency: string?, price: string, color: Color3, rainbow: boolean)
	buyWord.Text = word
	for name, icon in buyIcons do
		icon.Visible = name == currency
	end
	buyPrice.Text = price
	buyPrice.Visible = price ~= ""
	buyButton.BackgroundColor3 = color
	buyGradient.Enabled = rainbow
end

-- Update the screen for the truck being shown, and your Coins and Embers.
function GarageController.refresh()
	local truck: Types.TruckConfig = Trucks.List[index]
	local maxSpeed, maxCarry = Trucks.maxStats()
	nameLabel.Text = truck.Name
	tierLabel.Text = string.format(Text.Tier, index, index, #Trucks.List)
	UiKit.setBar(speedBar, truck.Speed / maxSpeed, "")
	UiKit.setBar(carryBar, truck.Carry / maxCarry, "")
	speedNumber.Text = tostring(truck.Speed)
	carryNumber.Text = tostring(truck.Carry)
	permanentLabel.Visible = Trucks.isPermanent(truck)
	skinsHolder.Visible = truck.Skins
	standardSwatch.BackgroundColor3 = truck.Look.Cab

	local coins = getNumber("Coins")
	local embers = getNumber("Embers")
	coinsLabel.Text = Format.number(coins)
	embersLabel.Text = Format.number(embers)

	local white = Color3.new(1, 1, 1)
	if Trucks.owns(player, truck.Id) then
		setBuy(Text.Spawn, nil, "", Style.Green, false)
	elseif truck.Currency == "Robux" then
		if truck.ProductId == 0 then
			setBuy(Text.ComingSoon, nil, "", Style.Grey, false)
		else
			setBuy(Text.Buy, nil, string.format(Text.Robux, Format.number(truck.Price)), white, true)
		end
	else
		local balance = if truck.Currency == "Coins" then coins else embers
		setBuy(Text.Buy, truck.Currency, Format.number(truck.Price), white, false)
		buyPrice.TextColor3 = if balance >= truck.Price then DARK_TEXT else Style.Red
		return
	end
	buyPrice.TextColor3 = DARK_TEXT
end

local function hideEverythingElse()
	table.clear(hiddenGuis)
	for _, child in player:WaitForChild("PlayerGui"):GetChildren() do
		if child:IsA("ScreenGui") and child.Enabled and not KEEP_GUIS[child.Name] then
			child.Enabled = false
			table.insert(hiddenGuis, child)
		end
	end
	table.clear(hiddenCore)
	for _, coreGui in CORE_GUIS do
		if StarterGui:GetCoreGuiEnabled(coreGui) then
			StarterGui:SetCoreGuiEnabled(coreGui, false)
			table.insert(hiddenCore, coreGui)
		end
	end
	if controls then
		controls:Disable()
	end
end

local function showEverythingElse()
	for _, hidden in hiddenGuis do
		hidden.Enabled = true
	end
	table.clear(hiddenGuis)
	for _, coreGui in hiddenCore do
		StarterGui:SetCoreGuiEnabled(coreGui, true)
	end
	table.clear(hiddenCore)
	if controls then
		controls:Enable()
	end
end

function GarageController.open()
	if isOpen then
		return
	end
	isOpen = true
	Showroom.build()
	index = 1
	local truck = Trucks.List[index]
	Showroom.show(truck.Look, truck.Id, false)
	hideEverythingElse()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = Config.Garage.CameraFieldOfView
		camera.CFrame = Showroom.cameraCFrame()
	end
	updateScale()
	GarageController.refresh()
	gui.Enabled = true
end

function GarageController.close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = 70
		camera.CameraType = Enum.CameraType.Custom
	end
	showEverythingElse()
end

-- Are you standing inside the glowing pad?
local function isOnPad(): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return false
	end
	for _, pad in CollectionService:GetTagged(Tags.GaragePad) do
		if pad:IsA("BasePart") then
			local offset = pad.CFrame:PointToObjectSpace(root.Position)
			if math.abs(offset.X) <= pad.Size.X / 2 and math.abs(offset.Z) <= pad.Size.Z / 2 and math.abs(offset.Y) < 8 then
				return true
			end
		end
	end
	return false
end

function GarageController.init()
	buyRemote = Remotes.getEvent("BuyTruck")
	spawnRemote = Remotes.getEvent("SpawnTruck")
	buildGui()
end

function GarageController.start()
	task.spawn(function()
		controls = getControls()
	end)
	player.AttributeChanged:Connect(function()
		if isOpen then
			GarageController.refresh()
		end
	end)
	-- If you die while it's open, give you your normal screen back.
	player.CharacterAdded:Connect(function()
		GarageController.close()
		wasOnPad = false
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		-- Open when you step onto the pad (not while you keep standing on it).
		local onPad = isOnPad()
		if onPad and not wasOnPad and not isOpen then
			GarageController.open()
		end
		wasOnPad = onPad
		if isOpen then
			Showroom.update(dt)
			local currentCamera = workspace.CurrentCamera
			if currentCamera and currentCamera.CameraType ~= Enum.CameraType.Scriptable then
				currentCamera.CameraType = Enum.CameraType.Scriptable -- something else tried to take it back
				currentCamera.CFrame = Showroom.cameraCFrame()
			end
			-- The Robux button's rainbow slides along.
			if buyGradient.Enabled then
				buyGradient.Offset = Vector2.new(((os.clock() * 0.4) % 2) - 1, 0)
			end
		end
	end)
end

return GarageController
