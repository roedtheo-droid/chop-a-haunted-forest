--!strict
-- This run's party totals, and what happens when the whole forest is cleared.
--
-- Other systems call RunManager.record(player, "TreesFelled", 1) when something happens.
-- That one call adds to the party's total for THIS run (shown on the FOREST CLEARED!
-- screen) AND to the player's saved lifetime stats (SaveManager), so the two always match.
--
-- When the Elder Hollow falls, BossManager calls RunManager.forestCleared(): everyone in
-- the server gets Embers and +1 ForestsCleared, and every screen shows the run's totals.
-- A new run means a new server, so a run starts when the server starts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local EmberManager = require(script.Parent.EmberManager)
local SaveManager = require(script.Parent.SaveManager)

local RunManager = {}

local totals: { [string]: number } = {} -- the whole party's totals, like totals.TreesFelled
local startedAt = 0 -- os.clock() when the run started
local cleared = false
local clearedRemote: RemoteEvent

-- Count something a player did (a stat name from SaveManager, like "CoinsEarned").
function RunManager.record(player: Player, stat: string, amount: number)
	totals[stat] = (totals[stat] or 0) + amount
	SaveManager.addStat(player, stat, amount)
end

-- The Elder Hollow fell: reward everyone who's here and show the end screen.
function RunManager.forestCleared()
	if cleared then
		return
	end
	cleared = true

	local embers = Config.Embers.PerForestCleared
	for _, player in Players:GetPlayers() do
		EmberManager.add(player, embers)
		-- Straight to the save: this is a personal stat, not part of the party's totals.
		SaveManager.addStat(player, "ForestsCleared", 1)
	end

	local summary: Types.RunSummary = {
		TreesFelled = totals.TreesFelled or 0,
		MimicsBurned = totals.MimicsBurned or 0,
		CoinsEarned = totals.CoinsEarned or 0,
		Seconds = math.floor(os.clock() - startedAt),
		Embers = embers,
	}
	clearedRemote:FireAllClients(summary)
end

function RunManager.init()
	startedAt = os.clock()
end

function RunManager.start()
	clearedRemote = Remotes.getEvent("ForestCleared")
end

return RunManager
