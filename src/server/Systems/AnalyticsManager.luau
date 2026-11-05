--!strict
-- Tells Roblox what players do, so the Creator Dashboard (its Analytics pages) can show where
-- they quit. It only reports: nothing in here changes the game. Four kinds of events:
--   Onboarding  a new player's first steps (ONBOARDING below), each counted once per player.
--   Run         how far a player gets through the forest (RUN_STEPS below). Only players who
--               were here before the first gate opened count, so it reads "of everyone who
--               started a run, how many got this far". Later joiners send JoinedLate instead.
--   Custom      things that can happen at any time, like a mimic waking up (see event).
--   Economy     Coins and Embers coming in and going out (see earned and spent).
-- Other systems call the functions below. The zones and the boss are watched from here.
--
-- Roblox only takes these events from the real game's server. In Studio nothing can be sent,
-- so they're printed in the Output instead (with Config.DebugPrints): that's how to check them.
-- Don't rename or reorder the steps once the game is live: the dashboard counts per step.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Boss = require(ReplicatedStorage.Shared.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)

local ONBOARDING = {
	"Joined",
	"PressedPlay",
	"FirstHit",
	"FirstTree",
	"FirstLog",
	"FirstSale",
	"FirstTool",
	"TutorialDone",
}
local RUN_FUNNEL = "ForestRun"
local TUTORIAL_DONE = "Unlock_TutorialDone" -- SaveManager sets this once a player has finished the quests

-- "Started", then one step for each gate that opens, then the boss.
local RUN_STEPS = { "Started" }
for index = 1, Zones.count() - 1 do
	table.insert(RUN_STEPS, `Zone{index}Cleared`)
end
table.insert(RUN_STEPS, "BossAwake")
table.insert(RUN_STEPS, "ForestCleared")

-- One server is one run. (In Studio every test server has the same empty JobId.)
local RUN_SESSION = if game.JobId ~= "" then game.JobId else "Studio"

local AnalyticsManager = {}

local isStudio = RunService:IsStudio()
local onboardingStep: { [Player]: number } = {} -- the last onboarding step each player reached
local runPlayers: { [Player]: boolean } = {} -- the players who count for the Run funnel
local runStep = 1 -- how far this server's run has come (1 is "Started")

-- Send one event, or print it in Studio. Analytics must never break the game, so if Roblox
-- refuses an event it only shows a warning.
local function send(description: string, call: () -> ())
	if not Config.Analytics.Enabled then
		return
	end
	if isStudio then
		if Config.DebugPrints then
			print(`[Analytics] {description}`)
		end
		return
	end
	local ok, err = pcall(call)
	if not ok then
		warn(`[Analytics] {description} failed: {err}`)
	end
end

-- A new player reached this step (a name from ONBOARDING). Roblox counts a step as also
-- finishing the ones before it, so going backwards is ignored, and players who finished the
-- quests on an earlier visit aren't new any more.
function AnalyticsManager.onboarding(player: Player, stepName: string)
	local step = table.find(ONBOARDING, stepName)
	if not step or step <= (onboardingStep[player] or 0) or player:GetAttribute(TUTORIAL_DONE) == true then
		return
	end
	onboardingStep[player] = step
	send(`Onboarding {step}: {stepName} ({player.Name})`, function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

local function logRunStep(player: Player, step: number)
	local stepName = RUN_STEPS[step]
	send(`Run {step}: {stepName} ({player.Name})`, function()
		AnalyticsService:LogFunnelStepEvent(player, RUN_FUNNEL, RUN_SESSION, step, stepName)
	end)
end

-- This server's run reached a new step (a name from RUN_STEPS).
local function reachRunStep(stepName: string)
	local step = table.find(RUN_STEPS, stepName)
	if not step or step <= runStep then
		return
	end
	runStep = step
	for player in runPlayers do
		logRunStep(player, step)
	end
end

-- Something happened to this player, like "MimicWoken".
function AnalyticsManager.event(player: Player, eventName: string, value: number?)
	local amount = value or 1
	send(`Event {eventName} = {amount} ({player.Name})`, function()
		AnalyticsService:LogCustomEvent(player, eventName, amount)
	end)
end

local function economy(
	player: Player,
	flow: Enum.AnalyticsEconomyFlowType,
	currency: string,
	amount: number,
	transaction: Enum.AnalyticsEconomyTransactionType,
	sku: string
)
	if amount <= 0 then
		return
	end
	local value = player:GetAttribute(currency)
	local balance = if typeof(value) == "number" then value else 0
	send(`{flow.Name} {amount} {currency}: {sku} ({player.Name}, now {balance})`, function()
		AnalyticsService:LogEconomyEvent(player, flow, currency, amount, balance, transaction.Name, sku)
	end)
end

-- A player just got Coins or Embers (`currency` is the attribute's name, "Coins" or "Embers")
-- for doing `sku`, like "SoldLogs". Call this after adding them, so the balance is right.
function AnalyticsManager.earned(player: Player, currency: string, amount: number, sku: string)
	economy(player, Enum.AnalyticsEconomyFlowType.Source, currency, amount, Enum.AnalyticsEconomyTransactionType.Gameplay, sku)
end

-- A player just spent Coins or Embers on `sku`, like "Axe". Call this after taking them.
function AnalyticsManager.spent(player: Player, currency: string, amount: number, sku: string)
	economy(player, Enum.AnalyticsEconomyFlowType.Sink, currency, amount, Enum.AnalyticsEconomyTransactionType.Shop, sku)
end

local function onPlayerAdded(player: Player)
	AnalyticsManager.onboarding(player, "Joined")
	if runStep == 1 then
		runPlayers[player] = true
		logRunStep(player, 1)
	else
		AnalyticsManager.event(player, "JoinedLate", runStep)
	end
end

function AnalyticsManager.init() end

function AnalyticsManager.start()
	-- The gates open, and the boss wakes up and falls, for everyone in the server.
	local zoneStates = ReplicatedStorage:WaitForChild(Zones.StateFolderName)
	for index = 1, Zones.count() - 1 do
		local zone = zoneStates:WaitForChild(tostring(index))
		zone:GetAttributeChangedSignal("Left"):Connect(function()
			if zone:GetAttribute("Left") == 0 then
				reachRunStep(`Zone{index}Cleared`)
			end
		end)
	end
	local bossState = ReplicatedStorage:WaitForChild(Boss.StateFolderName)
	bossState:GetAttributeChangedSignal("State"):Connect(function()
		local state = bossState:GetAttribute("State")
		if state == "Awake" then
			reachRunStep("BossAwake")
		elseif state == "Defeated" then
			reachRunStep("ForestCleared")
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this ran (can happen in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		onboardingStep[player] = nil
		runPlayers[player] = nil
	end)
end

return AnalyticsManager
