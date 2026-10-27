--!strict
-- The Tool Shed shop window. Opens when you press E at the shed's counter.
-- It only SHOWS prices and what you own (from attributes the server sets).
-- Clicking "Buy" just asks the server; the server decides if the purchase happens.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Types = require(ReplicatedStorage.Shared.Types)

local BG_COLOR = Color3.fromRGB(28, 30, 28)
local ROW_COLOR = Color3.fromRGB(45, 50, 45)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local DIM_TEXT = Color3.fromRGB(190, 190, 190)
local GOLD = Color3.fromRGB(255, 220, 90)
local CAN_BUY = Color3.fromRGB(60, 150, 70)
local CANT_BUY = Color3.fromRGB(110, 60, 55)
local DONE = Color3.fromRGB(80, 80, 80)
local ROW_HEIGHT = 58

local ShopController = {}

type Row = {
	Item: Types.ShopItem,
	Info: TextLabel,
	Button: TextButton,
}

local player = Players.LocalPlayer
local buyRemote: RemoteEvent
local gui: ScreenGui
local coinsLabel: TextLabel
local rows: { Row } = {}
local openAt: BasePart? -- the counter we opened the shop at (to close when walking away)

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function makeText(parent: Instance, name: string, text: string, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.Font = font
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- Update every row's text and button from the current attributes.
local function refresh()
	local coins = getNumber("Coins")
	coinsLabel.Text = `Coins: {coins}`

	for _, row in rows do
		local item = row.Item
		local buttonText: string
		local buttonColor: Color3

		if item.Kind == "Tool" then
			local tool = Config.Tools[item.Id]
			row.Info.Text = `{item.Description}  (damage {tool.Damage})`
			if player:GetAttribute(Shop.ownsAttribute(item.Id)) == true then
				buttonText, buttonColor = "Owned", DONE
			else
				buttonText = `{tool.Price} coins`
				buttonColor = if coins >= tool.Price then CAN_BUY else CANT_BUY
			end
		else
			local level = getNumber(Shop.levelAttribute(item.Id))
			row.Info.Text = `{item.Description}  (level {level}/{Shop.maxLevel(item.Id)})`
			local price = Shop.priceOf(item, level)
			if price then
				buttonText = `{price} coins`
				buttonColor = if coins >= price then CAN_BUY else CANT_BUY
			else
				buttonText, buttonColor = "MAX", DONE
			end
		end

		row.Button.Text = buttonText
		row.Button.BackgroundColor3 = buttonColor
	end
end

local function addHeader(list: ScrollingFrame, text: string, order: number)
	local header = makeText(list, "Header", text, GOLD, Enum.Font.GothamBlack)
	header.Size = UDim2.new(1, 0, 0, 26)
	header.LayoutOrder = order
end

local function addRow(list: ScrollingFrame, item: Types.ShopItem, order: number)
	local frame = Instance.new("Frame")
	frame.Name = item.Id
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	frame.BackgroundColor3 = ROW_COLOR
	frame.LayoutOrder = order
	frame.Parent = list
	corner(frame, 8)

	local name = makeText(frame, "Name", item.Name, TEXT_COLOR, Enum.Font.GothamBold)
	name.Position = UDim2.new(0, 10, 0, 6)
	name.Size = UDim2.new(0.62, -10, 0.45, 0)

	local info = makeText(frame, "Info", "", DIM_TEXT, Enum.Font.Gotham)
	info.Position = UDim2.new(0, 10, 0.5, 2)
	info.Size = UDim2.new(0.62, -10, 0.4, -4)

	local button = Instance.new("TextButton")
	button.Name = "Buy"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -8, 0.5, 0)
	button.Size = UDim2.new(0.36, -8, 1, -14)
	button.TextColor3 = TEXT_COLOR
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Parent = frame
	corner(button, 8)

	button.Activated:Connect(function()
		buyRemote:FireServer(item.Id)
	end)

	table.insert(rows, { Item = item, Info = info, Button = button })
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5 -- below the Notify messages, so "Bought ..." shows on top

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.9, 0.8)
	window.BackgroundColor3 = BG_COLOR
	window.BackgroundTransparency = 0.05
	window.Parent = gui
	corner(window, 14)

	-- Never bigger than this on big screens; scales down on phones.
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 470)
	limit.Parent = window

	local title = makeText(window, "Title", "TOOL SHED", TEXT_COLOR, Enum.Font.GothamBlack)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(0.5, 0, 0, 34)

	coinsLabel = makeText(window, "Coins", "Coins: 0", GOLD, Enum.Font.GothamBold)
	coinsLabel.AnchorPoint = Vector2.new(1, 0)
	coinsLabel.Position = UDim2.new(1, -60, 0, 14)
	coinsLabel.Size = UDim2.new(0.35, 0, 0, 28)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(38, 38)
	close.BackgroundColor3 = CANT_BUY
	close.Text = "X"
	close.TextColor3 = TEXT_COLOR
	close.Font = Enum.Font.GothamBlack
	close.TextScaled = true
	close.Parent = window
	corner(close, 8)
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(12, 58)
	list.Size = UDim2.new(1, -24, 1, -70)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = window

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	addHeader(list, "Tools", 0)
	local order = 1
	for _, item in Shop.Items do
		if item.Kind == "Tool" then
			addRow(list, item, order)
			order += 1
		end
	end
	addHeader(list, "Upgrades", order)
	order += 1
	for _, item in Shop.Items do
		if item.Kind == "Upgrade" then
			addRow(list, item, order)
			order += 1
		end
	end

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function open(at: BasePart)
	openAt = at
	refresh()
	gui.Enabled = true
end

local function hookPrompt(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	instance.Triggered:Connect(function()
		local parent = instance.Parent
		if parent and parent:IsA("BasePart") then
			open(parent)
		end
	end)
end

function ShopController.init()
	buyRemote = Remotes.getEvent("BuyItem")
	buildGui()
end

function ShopController.start()
	for _, prompt in CollectionService:GetTagged(Tags.ShopPrompt) do
		hookPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal(Tags.ShopPrompt):Connect(hookPrompt)

	-- Keep the window up to date when coins, tools or levels change.
	player.AttributeChanged:Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)

	-- Close the shop when the player walks away from the shed.
	RunService.Heartbeat:Connect(function()
		local at = openAt
		if not gui.Enabled or not at then
			return
		end
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not (root and root:IsA("BasePart")) then
			return
		end
		if (root.Position - at.Position).Magnitude > Config.Shop.MaxBuyDistance then
			gui.Enabled = false
		end
	end)
end

return ShopController
