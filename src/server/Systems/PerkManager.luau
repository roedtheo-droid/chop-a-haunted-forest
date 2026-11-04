--!strict
-- The shop extras beside every sell pad (built by Build/YardShop):
--   * Log Sack stump   buys the next Log Sack level (the CarryLimit upgrade) for coins,
--                      with the same checks as in the Tool Shed (ShopManager.buyAt)
--   * Infinite Bag     a Robux game pass: carry as many logs as you like (LogManager)
--   * 2X COINS board   a Robux game pass: logs sell for twice the coins (Shop.coinMultiplier)
--
-- A game pass is bought once and kept forever: Roblox remembers who owns it, so nothing is
-- saved here. When a player joins we ask Roblox what they own, and we hear right away when
-- they buy one. What they own is a player attribute ("Perk_DoubleCoins") that only the server
-- sets. While a pass's id in Config.Perks is 0 it isn't for sale ("Coming soon").

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Tags = require(ReplicatedStorage.Shared.Tags)
local SawmillManager = require(script.Parent.SawmillManager)
local ShopManager = require(script.Parent.ShopManager)
local YardShop = require(script.Parent.Parent.Build.YardShop)

type Pass = {
	GamePassId: number,
	RobuxPrice: number,
	Name: string,
}

local PerkManager = {}

local notifyRemote: RemoteEvent
local passes: { [string]: Pass } = {
	InfiniteBag = {
		GamePassId = Config.Perks.InfiniteBag.GamePassId,
		RobuxPrice = Config.Perks.InfiniteBag.RobuxPrice,
		Name = Config.Perks.Text.InfiniteBag,
	},
	DoubleCoins = {
		GamePassId = Config.Perks.DoubleCoins.GamePassId,
		RobuxPrice = Config.Perks.DoubleCoins.RobuxPrice,
		Name = Config.Perks.Text.DoubleCoins,
	},
}

local function newPrompt(parent: Instance, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Perks.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function grant(player: Player, perkId: string)
	player:SetAttribute(Shop.perkAttribute(perkId), true)
end

local function buyPass(player: Player, perkId: string)
	local pass = passes[perkId]
	local text = Config.Perks.Text
	if Shop.hasPerk(player, perkId) then
		notifyRemote:FireClient(player, string.format(text.Owned, pass.Name))
		return
	end
	if pass.GamePassId == 0 then
		notifyRemote:FireClient(player, string.format(text.NotOnSale, pass.Name))
		return
	end
	-- Roblox shows its own purchase window; PromptGamePassPurchaseFinished says if they bought it.
	MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
end

-- Ask Roblox which passes the player already owns (it can fail for a moment, so it's wrapped).
local function onPlayerAdded(player: Player)
	for perkId, pass in passes do
		if pass.GamePassId ~= 0 then
			task.spawn(function()
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.GamePassId)
				if ok and owns and player.Parent then
					grant(player, perkId)
				end
			end)
		end
	end
end

local function addPrompts(spots: YardShop.Spots)
	local text = Config.Perks.Text
	-- The Log Sack: each player's computer writes their own next carry number and price on it
	-- (see Client/ShopController); this is what a new player sees.
	local sack = Config.Upgrades.CarryLimit
	local sackPrompt = newPrompt(
		spots.Sack,
		string.format(text.SackAction, Format.number(sack.Prices[1])),
		string.format(text.SackObject, text.SackName, Config.Logs.CarryLimit + sack.PerLevel)
	)
	CollectionService:AddTag(sackPrompt, Tags.SackPrompt)
	sackPrompt.Triggered:Connect(function(player: Player)
		ShopManager.buyAt(player, "CarryLimit", spots.Sack, Config.Perks.PromptDistance)
	end)

	for perkId, spot in { InfiniteBag = spots.Bag, DoubleCoins = spots.Coins } do
		local pass = passes[perkId]
		local action = if pass.GamePassId == 0 then text.ComingSoon else string.format(text.RobuxAction, tostring(pass.RobuxPrice))
		newPrompt(spot, action, pass.Name).Triggered:Connect(function(player: Player)
			buyPass(player, perkId)
		end)
	end
end

function PerkManager.init() end

function PerkManager.start()
	notifyRemote = Remotes.getEvent("Notify")
	for _, spots in SawmillManager.getShopSpots() do
		addPrompts(spots)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if not purchased then
			return
		end
		for perkId, pass in passes do
			if pass.GamePassId ~= 0 and pass.GamePassId == passId then
				grant(player, perkId)
				notifyRemote:FireClient(player, string.format(Config.Perks.Text.Bought, pass.Name))
			end
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this ran (can happen in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PerkManager
