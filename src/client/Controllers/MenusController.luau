--!strict
-- The two wooden menus that the round buttons on the right open (see MenuButtonsController):
--   * SHOP (R): the Robux items. Infinite Bag and 2X COINS are game passes (Server/Systems/
--     PerkManager), the Chainsaw Trial is the trial table's deal (Server/Systems/TrialManager)
--     and the Big Beaver is coming later. While an item has no id in Config it says "Coming soon".
--   * UPGRADES (TAB): the coin upgrades (Chop Damage, Log Sack, Walk Speed, Lantern Radius),
--     with dots for their level. They can be bought from anywhere; tools stay in the Tool Shed.
-- Pressing the same button (or key) again closes the menu. Sizes and texts are in Config.Menus.
-- It only SHOWS prices and what you own; every button just asks the server, which decides.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Types = require(ReplicatedStorage.Shared.Types)
local Icons = require(script.Parent.Parent.Icons)
local UiKit = require(script.Parent.Parent.UiKit)
local MenuButtonsController = require(script.Parent.MenuButtonsController)
local NotifyController = require(script.Parent.NotifyController)

local Menus = Config.Menus
local Text = Menus.Text
local Style = Config.Style
local EDGE = 20 -- pixels between the window's border and what's inside
local HEADER = 14 + Menus.TitleIcon + 14 -- the title row's height
local EMPTY_DOT = Color3.fromRGB(70, 45, 25)

type IconMaker = (parent: Instance, name: string) -> Frame

-- One thing in the SHOP: what its button says right now, and what pressing it does.
type ShopEntry = {
	Id: string,
	Name: string,
	Info: string,
	Icon: IconMaker,
	Badge: string?, -- big text on the picture, like "2X"
	State: () -> (string, Color3),
	Press: () -> (),
}

local MenusController = {}

local player = Players.LocalPlayer
local shopGui: ScreenGui
local upgradesGui: ScreenGui
local coinsLabel: TextLabel
local refreshers: { () -> () } = {}

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refreshAll()
	for _, refresh in refreshers do
		refresh()
	end
end

---------------------------------------------------------------------------------------------
-- Building blocks

-- A wooden window in the middle of the screen: its picture and title at the top, a red X to
-- close it, and a "Body" frame `bodyHeight` pixels tall for what's inside.
local function makeWindow(name: string, title: string, icon: IconMaker, bodyHeight: number): (ScreenGui, Frame, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5 -- below the Notify messages, so "You got ..." shows on top
	UiKit.hudScale(gui)
	UiKit.freeMouse(gui) -- so you can click the buttons in first person

	local window = UiKit.panel(gui, "Window")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(Menus.Width, HEADER + bodyHeight + EDGE)

	local picture = icon(window, "Icon")
	picture.Position = UDim2.fromOffset(EDGE, 14)
	picture.Size = UDim2.fromOffset(Menus.TitleIcon, Menus.TitleIcon)

	local titleLabel = UiKit.text(window, "Title", title, Style.Gold, Style.TitleFont)
	titleLabel.AnchorPoint = Vector2.new(0, 0.5)
	titleLabel.Position = UDim2.fromOffset(EDGE + Menus.TitleIcon + 12, 14 + Menus.TitleIcon / 2)
	titleLabel.Size = UDim2.fromOffset(360, Menus.TitleText)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	local close = UiKit.button(window, "Close", "X", Style.Red)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -EDGE, 0, 18)
	close.Size = UDim2.fromOffset(56, 56)
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(EDGE, HEADER)
	body.Size = UDim2.new(1, -2 * EDGE, 0, bodyHeight)
	body.Parent = window

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, window, body
end

-- A picture with its name and a line about it, at the top-left of a card.
local function addInfo(card: Frame, icon: IconMaker, name: string, info: string, iconY: number): (Frame, TextLabel)
	local picture = icon(card, "Icon")
	picture.Position = UDim2.fromOffset(14, iconY)
	picture.Size = UDim2.fromOffset(Menus.ItemIcon, Menus.ItemIcon)

	local left = 14 + Menus.ItemIcon + 14
	local nameLabel = UiKit.text(card, "Name", name)
	nameLabel.Position = UDim2.fromOffset(left, 12)
	nameLabel.Size = UDim2.new(1, -(left + 14), 0, Menus.NameText)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left

	local infoLabel = UiKit.smallText(card, "Info", info, Style.Cream)
	infoLabel.Position = UDim2.fromOffset(left, 12 + Menus.NameText + 6)
	infoLabel.Size = UDim2.new(1, -(left + 14), 0, Menus.InfoText)
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	return picture, infoLabel
end

-- Big outlined text on top of a picture, like the "2X" on the coin.
local function addBadge(picture: Frame, text: string)
	local badge = UiKit.text(picture, "Badge", text, Style.Gold, Style.TitleFont)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.62, 0.66)
	badge.Size = UDim2.fromScale(0.8, 0.5)
	badge.ZIndex = 10
end

---------------------------------------------------------------------------------------------
-- SHOP: the Robux items

local function perkEntry(perkId: string, name: string, info: string, icon: IconMaker, badge: string?): ShopEntry
	local perk = (Config.Perks :: any)[perkId] :: { GamePassId: number, RobuxPrice: number }
	local remote = Remotes.getEvent("BuyPerk")
	return {
		Id = perkId,
		Name = name,
		Info = info,
		Icon = icon,
		Badge = badge,
		State = function(): (string, Color3)
			if Shop.hasPerk(player, perkId) then
				return Text.Owned, Style.Grey
			elseif perk.GamePassId == 0 then
				return Text.ComingSoon, Style.Grey
			end
			return string.format(Text.Robux, perk.RobuxPrice), Style.Green
		end,
		Press = function()
			remote:FireServer(perkId) -- the server says "coming soon" or "you already have it"
		end,
	}
end

local function shopEntries(): { ShopEntry }
	local perkText = Config.Perks.Text
	local trial = Config.Trial
	local trialRemote = Remotes.getEvent("TryTrial")
	return {
		perkEntry("InfiniteBag", perkText.InfiniteBag, Text.InfiniteBagInfo, Icons.backpack, "∞"),
		perkEntry("DoubleCoins", perkText.DoubleCoins, Text.DoubleCoinsInfo, Icons.coin, perkText.TwoX),
		{
			Id = "Trial",
			Name = Text.TrialName,
			Info = string.format(Text.TrialInfo, math.floor(trial.Seconds / 60)),
			Icon = Icons.flameTool,
			State = function(): (string, Color3)
				if player:GetAttribute(Shop.ownsAttribute(trial.ToolId)) == true then
					return Text.Owned, Style.Grey
				elseif typeof(player:GetAttribute(Shop.TRIAL_ENDS)) == "number" then
					return Text.Running, Style.Grey
				elseif trial.ProductId == 0 then
					return Text.Free, Style.Green
				end
				return string.format(Text.Robux, trial.RobuxPrice), Style.Green
			end,
			Press = function()
				trialRemote:FireServer() -- the same as the trial table (and the T key)
			end,
		},
		{
			Id = "BigBeaver",
			Name = perkText.BigBeaver,
			Info = Text.BigBeaverInfo,
			Icon = Icons.beaver,
			State = function(): (string, Color3)
				return Text.ComingSoon, Style.Grey
			end,
			Press = function()
				NotifyController.show(Text.BigBeaverSoon)
			end,
		},
	}
end

local function buildShop()
	local entries = shopEntries()
	local rows = math.ceil(#entries / 2)
	local bodyHeight = rows * Menus.ShopCardHeight + (rows - 1) * Menus.CardGap + 8
	local gui, _, body = makeWindow("RobuxShop", Text.ShopTitle, Icons.basket, bodyHeight)
	shopGui = gui

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset((Menus.Width - 2 * EDGE - Menus.CardGap) / 2 - 4, Menus.ShopCardHeight)
	grid.CellPadding = UDim2.fromOffset(Menus.CardGap, Menus.CardGap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = body
	local padding = Instance.new("UIPadding") -- room for the cards' borders
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.Parent = body

	for index, entry in entries do
		local card = UiKit.card(body, entry.Id)
		card.LayoutOrder = index
		local picture, info = addInfo(card, entry.Icon, entry.Name, entry.Info, 12)
		if entry.Badge then
			addBadge(picture, entry.Badge)
		end
		-- The info line under the name can take two lines here.
		info.Size = UDim2.new(info.Size.X.Scale, info.Size.X.Offset, 0, Menus.InfoText * 2 + 4)
		info.TextWrapped = true
		info.TextYAlignment = Enum.TextYAlignment.Top

		local button, label = UiKit.button(card, "Buy", "", Style.Green)
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.new(1, -14, 1, -14)
		button.Size = UDim2.fromOffset(Menus.ButtonWidth, Menus.ButtonHeight)
		button.Activated:Connect(entry.Press)

		table.insert(refreshers, function()
			local text, color = entry.State()
			label.Text = text
			button.BackgroundColor3 = color
		end)
	end
end

---------------------------------------------------------------------------------------------
-- UPGRADES: the coin upgrades

local UPGRADE_ICONS: { [string]: IconMaker } = {
	ChopDamage = Icons.axe,
	CarryLimit = Icons.backpack,
	WalkSpeed = Icons.boot,
	LanternRadius = Icons.lantern,
}

local function addUpgradeRow(body: Frame, item: Types.ShopItem, order: number, buyRemote: RemoteEvent)
	local card = UiKit.card(body, item.Id)
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -8, 0, Menus.UpgradeRowHeight)
	addInfo(card, UPGRADE_ICONS[item.Id] or Icons.upArrow, item.Name, item.Description, (Menus.UpgradeRowHeight - Menus.ItemIcon) / 2)

	-- One dot per level: gold for the levels you have.
	local dots = Instance.new("Frame")
	dots.Name = "Levels"
	dots.BackgroundTransparency = 1
	dots.Position = UDim2.fromOffset(14 + Menus.ItemIcon + 14, 12 + Menus.NameText + 6 + Menus.InfoText + 8)
	dots.Size = UDim2.fromOffset(300, Menus.LevelDot)
	dots.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = dots
	local dotFrames: { Frame } = {}
	for level = 1, Shop.maxLevel(item.Id) do
		local dot = Instance.new("Frame")
		dot.Name = `Level{level}`
		dot.LayoutOrder = level
		dot.Size = UDim2.fromOffset(Menus.LevelDot, Menus.LevelDot)
		UiKit.corner(dot, 999)
		UiKit.border(dot, Color3.new(0, 0, 0), 2)
		dot.Parent = dots
		table.insert(dotFrames, dot)
	end

	-- The Buy button: a coin and the next level's price, or MAX / "Needs Lantern".
	local button, label = UiKit.button(card, "Buy", "", Style.Green)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -14, 0.5, 0)
	button.Size = UDim2.fromOffset(Menus.ButtonWidth, Menus.ButtonHeight)
	local coin = Icons.coin(button, "Coin")
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 10, 0.5, 0)
	coin.Size = UDim2.fromOffset(Menus.ButtonHeight - 16, Menus.ButtonHeight - 16)
	button.Activated:Connect(function()
		buyRemote:FireServer(item.Id)
	end)

	table.insert(refreshers, function()
		local level = getNumber(Shop.levelAttribute(item.Id))
		for index, dot in dotFrames do
			dot.BackgroundColor3 = if index <= level then Style.Gold else EMPTY_DOT
		end
		local price = Shop.priceOf(item, level)
		local required = item.Requires
		local text: string
		local color: Color3
		if required and player:GetAttribute(Shop.ownsAttribute(required)) ~= true then
			local requiredItem = Shop.getItem(required)
			text, color = string.format(Text.Needs, if requiredItem then requiredItem.Name else required), Style.Grey
			price = nil
		elseif price then
			text = Format.number(price)
			color = if getNumber("Coins") >= price then Style.Green else Style.Red
		else
			text, color = Text.Max, Style.Grey
		end
		label.Text = text
		button.BackgroundColor3 = color
		-- Make room for the coin when it shows a price.
		coin.Visible = price ~= nil
		label.Position = if price then UDim2.new(0.5, (Menus.ButtonHeight - 16) / 2 + 4, 0.5, 0) else UDim2.fromScale(0.5, 0.5)
		label.Size = if price then UDim2.new(1, -(Menus.ButtonHeight + 20), 0.62, 0) else UDim2.fromScale(0.86, 0.62)
	end)
end

local function buildUpgrades()
	local items: { Types.ShopItem } = {}
	for _, item in Shop.Items do
		if item.Kind == "Upgrade" then
			table.insert(items, item)
		end
	end
	local bodyHeight = #items * Menus.UpgradeRowHeight + (#items - 1) * Menus.CardGap + 8
	local gui, window, body = makeWindow("Upgrades", Text.UpgradesTitle, Icons.upArrow, bodyHeight)
	upgradesGui = gui

	-- Your coins, left of the close button.
	local coins = Instance.new("Frame")
	coins.Name = "Coins"
	coins.BackgroundTransparency = 1
	coins.AnchorPoint = Vector2.new(1, 0)
	coins.Position = UDim2.new(1, -(EDGE + 56 + 16), 0, 22)
	coins.Size = UDim2.fromOffset(260, 48)
	coins.Parent = window
	local coinIcon = Icons.coin(coins, "Icon")
	coinIcon.AnchorPoint = Vector2.new(1, 0.5)
	coinIcon.Position = UDim2.fromScale(1, 0.5)
	coinIcon.Size = UDim2.fromOffset(48, 48)
	coinsLabel = UiKit.text(coins, "Amount", "0", Style.Gold)
	coinsLabel.Size = UDim2.new(1, -58, 0.8, 0)
	coinsLabel.Position = UDim2.fromScale(0, 0.1)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	table.insert(refreshers, function()
		coinsLabel.Text = Format.number(getNumber("Coins"))
	end)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, Menus.CardGap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body
	local padding = Instance.new("UIPadding") -- room for the cards' borders
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.Parent = body

	local buyRemote = Remotes.getEvent("BuyItem")
	for index, item in items do
		addUpgradeRow(body, item, index, buyRemote)
	end
end

---------------------------------------------------------------------------------------------

-- Open a menu (closing the other one), or close it if it's already open.
local function toggle(gui: ScreenGui)
	local opening = not gui.Enabled
	shopGui.Enabled = false
	upgradesGui.Enabled = false
	if opening then
		refreshAll()
		gui.Enabled = true
	end
end

function MenusController.init()
	buildShop()
	buildUpgrades()
end

function MenusController.start()
	MenuButtonsController.setAction("Shop", function()
		toggle(shopGui)
	end)
	MenuButtonsController.setAction("Upgrades", function()
		toggle(upgradesGui)
	end)
	-- Keep an open menu up to date when coins, levels, passes or the trial change.
	player.AttributeChanged:Connect(function()
		if shopGui.Enabled or upgradesGui.Enabled then
			refreshAll()
		end
	end)
end

return MenusController
