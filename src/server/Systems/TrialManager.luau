--!strict
-- The trial table in the Tool Shed: press E at it to try the Chainsaw for 3 minutes
-- (Config.Trial). It's a Robux developer product; while its id is 0 the trial is free, once
-- per run (one server = one run), so it can be tested.
--
-- The server lends the tool (ToolManager.giveTrial) and takes it back when the time is up.
-- The time left is a player attribute (Shop.TRIAL_ENDS), which Client/HudController shows
-- as "TRIAL 2:59" under the coins.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)
local ProductManager = require(script.Parent.ProductManager)
local ShopManager = require(script.Parent.ShopManager)
local ToolManager = require(script.Parent.ToolManager)

local TrialManager = {}

local notifyRemote: RemoteEvent
-- UserIds that had their free trial this run (kept when they leave, so rejoining doesn't give another).
local usedFree: { [number]: boolean } = {}

local function toolName(): string
	local item = Shop.getItem(Config.Trial.ToolId)
	return if item then item.Name else Config.Trial.ToolId
end

-- Lend the tool, and take it back when the time is up (unless a newer trial started since).
local function startTrial(player: Player)
	local cfg = Config.Trial
	local ends = ToolManager.giveTrial(player, cfg.ToolId, cfg.Seconds)
	notifyRemote:FireClient(player, string.format(cfg.Text.Started, toolName(), math.floor(cfg.Seconds / 60)))
	task.delay(cfg.Seconds, function()
		if player.Parent and player:GetAttribute(Shop.TRIAL_ENDS) == ends then
			ToolManager.endTrial(player)
			notifyRemote:FireClient(player, string.format(cfg.Text.Over, toolName()))
		end
	end)
end

local function onTry(player: Player)
	local cfg = Config.Trial
	if ToolManager.owns(player, cfg.ToolId) then
		notifyRemote:FireClient(player, string.format(cfg.Text.Owned, toolName()))
		return
	end
	if ToolManager.hasTrial(player, cfg.ToolId) then
		notifyRemote:FireClient(player, string.format(cfg.Text.Running, toolName()))
		return
	end
	if cfg.ProductId == 0 then
		if usedFree[player.UserId] then
			notifyRemote:FireClient(player, cfg.Text.UsedFree)
			return
		end
		usedFree[player.UserId] = true
		startTrial(player)
		return
	end
	-- Roblox shows its own purchase window. ProductManager calls back once they've paid.
	MarketplaceService:PromptProductPurchase(player, cfg.ProductId)
end

function TrialManager.init() end

function TrialManager.start()
	local cfg = Config.Trial
	notifyRemote = Remotes.getEvent("Notify")

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = cfg.Text.Action
	prompt.ObjectText = string.format(cfg.Text.Object, toolName(), math.floor(cfg.Seconds / 60))
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = cfg.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = ShopManager.getTrialTable()
	prompt.Triggered:Connect(onTry)

	-- A paid trial: they paid, so it always starts (it's not saved, so there's nothing to wait for).
	ProductManager.register(cfg.ProductId, function(player: Player): boolean
		startTrial(player)
		return true
	end)
end

return TrialManager
