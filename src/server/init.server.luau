--!strict
-- The ONLY Script in the game. It starts every server system in a fixed order.
--
-- To add a system: create a ModuleScript in Systems/ with init() and start(),
-- then add it to the list below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Systems = script.Systems

-- Order matters: systems higher in the list are set up first.
local systems: { Types.Module } = {
	require(Systems.RemoteService), -- first, so every other system can use remotes
	require(Systems.QuestManager),
	require(Systems.ZoneManager), -- before anything that looks for the ground (it builds the zone floors)
	require(Systems.ForestSpawner),
	require(Systems.LogManager),
	require(Systems.CoinManager),
	require(Systems.ToolManager),
	require(Systems.UpgradeManager),
	require(Systems.LogVacuumManager),
	require(Systems.SawmillManager),
	require(Systems.ShopManager),
	require(Systems.TreeManager),
}

-- Step 1: set up every system.
for _, system in systems do
	system.init()
end

-- Step 2: start every system. task.spawn means one slow system
-- can't hold up the others.
for _, system in systems do
	task.spawn(system.start)
end

if Config.DebugPrints then
	local remotesFolder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	local remoteCount = if remotesFolder then #remotesFolder:GetChildren() else 0
	print(`[Server] Started {#systems} system(s). Remotes created: {remoteCount}`)
end
