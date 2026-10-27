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
	require(Systems.EffectsManager), -- world sounds and particles (used by many systems)
	require(Systems.SaveManager), -- early, so players' saves start loading as soon as possible
	require(Systems.QuestManager),
	require(Systems.ZoneManager), -- before anything that looks for the ground (it builds the zone floors)
	require(Systems.ForestSpawner),
	require(Systems.MimicManager), -- after ForestSpawner (it picks mimics from the spawned trees)
	require(Systems.BossManager), -- after ZoneManager (the boss counts as one of its zone's trees)
	require(Systems.LogManager),
	require(Systems.CoinManager),
	require(Systems.EmberManager),
	require(Systems.RunManager),
	require(Systems.ToolManager),
	require(Systems.MovementManager),
	require(Systems.UpgradeManager),
	require(Systems.LogVacuumManager),
	require(Systems.LanternManager),
	require(Systems.KnockdownManager),
	require(Systems.SawmillManager),
	require(Systems.ShopManager),
	require(Systems.TreeManager),
	require(Systems.DebugManager), -- Studio-only test shortcuts
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
