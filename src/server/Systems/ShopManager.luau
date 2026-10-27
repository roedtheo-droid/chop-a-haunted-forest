--!strict
-- Builds the placeholder Tool Shed and handles every purchase.
--
-- The client only says "I want to buy item X". The server checks that:
--   the item exists, the player is standing at the shed, they're not clicking too fast,
--   they don't already own it (or it isn't max level), they own anything it needs first
--   (Lantern Radius needs the Lantern), and they have enough coins.
-- Only then does it take the coins and give the tool or upgrade.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Tags = require(ReplicatedStorage.Shared.Tags)
local CoinManager = require(script.Parent.CoinManager)
local QuestManager = require(script.Parent.QuestManager)
local ToolManager = require(script.Parent.ToolManager)
local UpgradeManager = require(script.Parent.UpgradeManager)
local Blocky = require(script.Parent.Parent.Build.Blocky)

local COUNTER_COLOR = Color3.fromRGB(150, 110, 70)

local ShopManager = {}

local notifyRemote: RemoteEvent
local counter: BasePart
local lastBuy: { [Player]: number } = {}

local function groundHeightAt(x: number, z: number): number
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0))
	return if result then result.Position.Y else 0
end

local function buildShed(): BasePart
	local cfg = Config.Shop
	local center = cfg.Position
	local size = cfg.BuildingSize
	local groundY = groundHeightAt(center.X, center.Z)

	local model = Instance.new("Model")
	model.Name = "ToolShed"

	-- A log cabin with a big yellow "TOOL SHED" sign over the door.
	local ground = Vector3.new(center.X, groundY, center.Z)
	Blocky.cabin("Building", ground, size, 2, model)
	Blocky.sign(
		"TOOL SHED",
		CFrame.new(ground + Vector3.new(0, size.Y * 0.84, size.Z / 2 + 0.3)),
		size.X * 0.8,
		size.Y * 0.26,
		Config.Style.HazardYellow,
		model
	)

	-- A counter in front of the shed (facing spawn) holds the "Open shop" prompt.
	local shopCounter = Instance.new("Part")
	shopCounter.Name = "Counter"
	shopCounter.Size = Vector3.new(6, 3, 1.5)
	shopCounter.Position = Vector3.new(center.X, groundY + 1.5, center.Z + size.Z / 2 + 1)
	shopCounter.Color = COUNTER_COLOR
	shopCounter.Material = Enum.Material.Wood
	shopCounter.Anchored = true
	shopCounter.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open shop"
	prompt.ObjectText = "Tool Shed"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = cfg.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = shopCounter
	CollectionService:AddTag(prompt, Tags.ShopPrompt)

	model.Parent = workspace
	return shopCounter
end

local function isAtShed(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return false
	end
	return (root.Position - counter.Position).Magnitude <= Config.Shop.MaxBuyDistance
end

local function onBuy(player: Player, itemId: unknown)
	-- 1. Is it a real item? (The client could send anything.)
	if typeof(itemId) ~= "string" then
		return
	end
	local item = Shop.getItem(itemId :: string)
	if not item then
		return
	end

	-- 2. Not too fast, and standing at the shed?
	local now = os.clock()
	local last = lastBuy[player]
	if last and now - last < Config.Shop.BuyCooldown then
		return
	end
	lastBuy[player] = now
	if not isAtShed(player) then
		notifyRemote:FireClient(player, "Go to the Tool Shed to buy things.")
		return
	end

	-- 3. Can it be bought?
	if item.Kind == "Tool" and ToolManager.owns(player, item.Id) then
		notifyRemote:FireClient(player, `You already have the {item.Name}.`)
		return
	end
	local required = item.Requires
	if required and not ToolManager.owns(player, required) then
		local requiredItem = Shop.getItem(required)
		notifyRemote:FireClient(player, `Buy the {if requiredItem then requiredItem.Name else required} first.`)
		return
	end
	local level = if item.Kind == "Upgrade" then UpgradeManager.getLevel(player, item.Id) else 0
	local price = Shop.priceOf(item, level)
	if not price then
		if Shop.maxLevel(item.Id) == 1 then
			notifyRemote:FireClient(player, `You already have the {item.Name}.`)
		else
			notifyRemote:FireClient(player, `{item.Name} is already max level!`)
		end
		return
	end

	-- 4. Enough coins? (spend() checks and takes them in one step.)
	if not CoinManager.spend(player, price) then
		local missing = price - CoinManager.get(player)
		notifyRemote:FireClient(player, `You need {missing} more coins.`)
		return
	end

	-- 5. Give it.
	if item.Kind == "Tool" then
		ToolManager.give(player, item.Id)
		notifyRemote:FireClient(player, `You bought the {item.Name}! Press its number key to hold it.`)
		if item.Id == "Axe" then
			QuestManager.report(player, "BuyAxe")
		end
	else
		UpgradeManager.setLevel(player, item.Id, level + 1)
		if Shop.maxLevel(item.Id) == 1 then
			notifyRemote:FireClient(player, `You bought the {item.Name}!`)
		else
			notifyRemote:FireClient(player, `{item.Name} is now level {level + 1}!`)
		end
		QuestManager.report(player, "BuyUpgrade")
	end
end

function ShopManager.init()
	counter = buildShed()
end

function ShopManager.start()
	notifyRemote = Remotes.getEvent("Notify")
	Remotes.getEvent("BuyItem").OnServerEvent:Connect(onBuy)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastBuy[player] = nil
	end)
end

return ShopManager
