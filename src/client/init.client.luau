--!strict
-- The ONLY LocalScript in the game. It starts every client controller in a fixed order.
--
-- To add a controller: create a ModuleScript in Controllers/ with init() and start(),
-- then add it to the list below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

-- Wait until the server has created the remotes, so controllers can use them.
Remotes.getEvent("Notify")

local Controllers = script.Controllers

-- Order matters: controllers higher in the list are set up first.
local controllers: { Types.Module } = {
	require(Controllers.NotifyController),
	require(Controllers.HudController),
	require(Controllers.ZoneController),
	require(Controllers.AtmosphereController),
	require(Controllers.SoundController),
	require(Controllers.QuestController),
	require(Controllers.BackpackController),
	require(Controllers.ChopEffectsController), -- before ChopController, which uses it
	require(Controllers.ChopController),
	require(Controllers.ShopController),
	require(Controllers.SprintController),
	require(Controllers.KnockdownController),
	require(Controllers.LanternController),
	require(Controllers.BossController),
	require(Controllers.ForestClearedController),
	require(Controllers.DebugController), -- Studio-only test buttons
}

-- Step 1: set up every controller.
for _, controller in controllers do
	controller.init()
end

-- Step 2: start every controller.
for _, controller in controllers do
	task.spawn(controller.start)
end

if Config.DebugPrints then
	print(`[Client] Started {#controllers} controller(s). Remotes ready.`)
end
