--!strict
-- Keeps track of each player's Coins.
-- Coins are stored in a "Coins" attribute on the Player. Only the server changes it;
-- the client just reads it to show the HUD. Coins reset every run (not saved).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CoinManager = {}

function CoinManager.get(player: Player): number
	local value = player:GetAttribute("Coins")
	return if typeof(value) == "number" then value else 0
end

function CoinManager.add(player: Player, amount: number)
	player:SetAttribute("Coins", CoinManager.get(player) + amount)
end

-- Take coins if the player has enough. Returns false (and takes nothing) if not.
function CoinManager.spend(player: Player, amount: number): boolean
	local coins = CoinManager.get(player)
	if amount < 0 or coins < amount then
		return false
	end
	player:SetAttribute("Coins", coins - amount)
	return true
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Coins", Config.Coins.Starting)
end

function CoinManager.init() end

function CoinManager.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this ran (can happen in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CoinManager
