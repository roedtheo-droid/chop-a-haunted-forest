--!strict
-- The Tool Shed shop window: a wooden panel that opens when you press E at the shed's counter.
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
local UiKit = require(script.Parent.Parent.UiKit)

local Style = Config.Style
local CAN_BUY = Style.Green
local CANT_BUY = Style.Red
local DONE = Style.Grey
local ROW_HEIGHT = 62

local ShopController = {}

type Row = {
	Item: Types.ShopItem,
	Info: TextLabel,
	Button: TextButton,
	ButtonLabel: TextLabel,
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

-- Update every row's text and button from the current attributes.
local function refresh()
	local coins = getNumber("Coins")
	coinsLabel.Text = tostring(coins)

	for _, row in rows do
		local item = row.Item
		local buttonText: string
		local buttonColor: Color3

		if item.Kind == "Tool" then
			local tool = Config.Tools[item.Id]
			-- The Lantern and Torch don't chop, so don't show "damage 0" for them.
			row.Info.Text = if tool.Damage > 0 then `{item.Description}  (damage {tool.Damage})` else item.Description
			if player:GetAttribute(Shop.ownsAttribute(item.Id)) == true then
				buttonText, buttonColor = "Owned", DONE
			else
				buttonText = `{tool.Price} coins`
				buttonColor = if coins >= tool.Price then CAN_BUY else CANT_BUY
			end
		else
			local level = getNumber(Shop.levelAttribute(item.Id))
			local maxLevel = Shop.maxLevel(item.Id)
			-- One-level items (like the Log Vacuum) are just "owned or not", so skip the level text.
			row.Info.Text = if maxLevel == 1 then item.Description else `{item.Description}  (level {level}/{maxLevel})`
			local price = Shop.priceOf(item, level)
			local required = item.Requires
			local requiredItem = if required then Shop.getItem(required) else nil
			if required and player:GetAttribute(Shop.ownsAttribute(required)) ~= true then
				-- Like Lantern Radius before you own the Lantern.
				buttonText = `Needs {if requiredItem then requiredItem.Name else required}`
				buttonColor = DONE
			elseif price then
				buttonText = `{price} coins`
				buttonColor = if coins >= price then CAN_BUY else CANT_BUY
			else
				buttonText = if maxLevel == 1 then "Owned" else "MAX"
				buttonColor = DONE
			end
		end

		row.ButtonLabel.Text = buttonText
		row.Button.BackgroundColor3 = buttonColor
	end
end

local function addHeader(list: ScrollingFrame, text: string, order: number)
	local header = UiKit.text(list, "Header", text, Style.Gold, Style.TitleFont)
	header.Size = UDim2.new(1, 0, 0, 28)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.LayoutOrder = order
end

local function addRow(list: ScrollingFrame, item: Types.ShopItem, order: number)
	local card = UiKit.card(list, item.Id)
	card.Size = UDim2.new(1, -8, 0, ROW_HEIGHT) -- a little narrower, so the border isn't cut off
	card.LayoutOrder = order

	local name = UiKit.text(card, "Name", item.Name)
	name.Position = UDim2.new(0, 10, 0, 6)
	name.Size = UDim2.new(0.62, -10, 0.42, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local info = UiKit.smallText(card, "Info", "", Style.Cream)
	info.Position = UDim2.new(0, 10, 0.5, 2)
	info.Size = UDim2.new(0.62, -10, 0.36, -2)
	info.TextXAlignment = Enum.TextXAlignment.Left

	local button, buttonLabel = UiKit.button(card, "Buy", "", CAN_BUY)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.new(0.36, -10, 1, -18)

	button.Activated:Connect(function()
		buyRemote:FireServer(item.Id)
	end)

	table.insert(rows, { Item = item, Info = info, Button = button, ButtonLabel = buttonLabel })
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5 -- below the Notify messages, so "Bought ..." shows on top

	local window = UiKit.panel(gui, "Window")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.9, 0.8)

	-- Never bigger than this on big screens; scales down on phones.
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 470)
	limit.Parent = window

	local title = UiKit.text(window, "Title", "TOOL SHED", Style.Gold, Style.TitleFont)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(0.5, 0, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left

	-- Your coins, next to the close button.
	local coins = Instance.new("Frame")
	coins.Name = "Coins"
	coins.AnchorPoint = Vector2.new(1, 0)
	coins.Position = UDim2.new(1, -62, 0, 14)
	coins.Size = UDim2.new(0.35, 0, 0, 30)
	coins.BackgroundTransparency = 1
	coins.Parent = window
	local coinIcon = UiKit.coin(coins, "Icon")
	coinIcon.AnchorPoint = Vector2.new(1, 0.5)
	coinIcon.Position = UDim2.fromScale(1, 0.5)
	coinIcon.Size = UDim2.fromOffset(26, 26)
	coinsLabel = UiKit.text(coins, "Amount", "0", Style.Gold)
	coinsLabel.Size = UDim2.new(1, -34, 1, 0)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right

	local close = UiKit.button(window, "Close", "X", CANT_BUY)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(38, 38)
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(14, 60)
	list.Size = UDim2.new(1, -24, 1, -74)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Style.DarkWood
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = window

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Room for the cards' borders at the top and left.
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.Parent = list

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
