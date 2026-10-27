--!strict
-- Keeps each player's upgrade levels and applies what they do:
--   ChopDamage  more damage per hit (read by TreeManager)
--   CarryLimit  a bigger backpack (sets the "CarryLimit" attribute)
--   WalkSpeed   faster walking (MovementManager reads the level and sets the speed)
-- Levels are player attributes like "Upgrade_WalkSpeed" that only the server sets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local MovementManager = require(script.Parent.MovementManager)

local UpgradeManager = {}

function UpgradeManager.getLevel(player: Player, upgradeId: string): number
	local value = player:GetAttribute(Shop.levelAttribute(upgradeId))
	return if typeof(value) == "number" then value else 0
end

local function bonus(player: Player, upgradeId: string): number
	return UpgradeManager.getLevel(player, upgradeId) * Config.Upgrades[upgradeId].PerLevel
end

-- How much to multiply tool damage by (1 = no upgrade).
function UpgradeManager.damageMultiplier(player: Player): number
	return 1 + bonus(player, "ChopDamage")
end

local function apply(player: Player)
	player:SetAttribute("CarryLimit", Config.Logs.CarryLimit + bonus(player, "CarryLimit"))
	MovementManager.refresh(player)
end

function UpgradeManager.setLevel(player: Player, upgradeId: string, level: number)
	player:SetAttribute(Shop.levelAttribute(upgradeId), level)
	apply(player)
end

local function onPlayerAdded(player: Player)
	for upgradeId in Config.Upgrades do
		player:SetAttribute(Shop.levelAttribute(upgradeId), 0)
	end
	apply(player)
end

function UpgradeManager.init() end

function UpgradeManager.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this ran (can happen in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return UpgradeManager
