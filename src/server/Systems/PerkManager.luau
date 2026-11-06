--!strict
-- The Robux game passes, and the peddler's cart beside every sell pad (built by Build/PeddlerCart):
--   * Infinite Bag     carry as many logs as you like (LogManager)
--   * 2X COINS         logs sell for twice the coins (Shop.coinMultiplier)
--
-- The passes are bought in the SHOP menu (the BuyPerk remote). The signpost's SHOP button opens it
-- from anywhere, and so does the cart's "Open shop" prompt (see Client/MenusController).
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
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Tags = require(ReplicatedStorage.Shared.Tags)
local SawmillManager = require(script.Parent.SawmillManager)

type Pass = {
	GamePassId: number,
	RobuxPrice: number,
	Name: string,
}

local PerkManager = {}

local notifyRemote: RemoteEvent
local lastBuy: { [Player]: number } = {} -- so holding the button can't spam purchase windows
local BUY_COOLDOWN = 1 -- seconds
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

-- The cart's prompt only opens a menu on the player's own computer (Client/MenusController), so
-- the server doesn't listen to it. The menu's buttons still ask the server.
local function addCartPrompt(spot: BasePart)
	local text = Config.Perks.Text
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = text.CartAction
	prompt.ObjectText = text.CartName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Perks.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot
	CollectionService:AddTag(prompt, Tags.CartPrompt)
end

function PerkManager.init() end

function PerkManager.start()
	notifyRemote = Remotes.getEvent("Notify")
	for _, spot in SawmillManager.getCartSpots() do
		addCartPrompt(spot)
	end

	-- The SHOP menu's buttons (Client/MenusController). Only a perk Id comes from the client,
	-- and it must be one of ours; the price and the purchase are handled by Roblox.
	Remotes.getEvent("BuyPerk").OnServerEvent:Connect(function(player: Player, perkId: unknown)
		if typeof(perkId) ~= "string" or not passes[perkId] then
			return
		end
		local now = os.clock()
		local last = lastBuy[player]
		if last and now - last < BUY_COOLDOWN then
			return
		end
		lastBuy[player] = now
		buyPass(player, perkId)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastBuy[player] = nil
	end)

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
