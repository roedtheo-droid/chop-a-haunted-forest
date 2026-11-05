--!strict
-- Tutorial quests: a short list that teaches new players the core loop.
--
-- Other systems call QuestManager.report(player, "FellTree") when something happens.
-- If it matches the player's current quest, progress goes up; at the goal, the next
-- quest starts. Progress is stored in two player attributes the client shows:
--   QuestIndex     which quest (1, 2, 3...; one past the last = all done; 0 = done on an earlier visit)
--   QuestProgress  how far into the current quest
-- Finishing the last quest is saved, and so is pressing PLAY on the title screen, so the quests
-- and the intro's flyover only show for new players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AnalyticsManager = require(script.Parent.AnalyticsManager)
local SaveManager = require(script.Parent.SaveManager)

-- Permanent unlocks (see SaveManager).
local TUTORIAL_DONE = "TutorialDone" -- finished every quest
local INTRO_SEEN = "IntroSeen" -- pressed PLAY on the title screen

-- Which onboarding step (see AnalyticsManager) a quest event counts as.
local ONBOARDING_STEPS: { [string]: string } = {
	FellTree = "FirstTree",
	PickUpLog = "FirstLog",
	SellLogs = "FirstSale",
}

local QuestManager = {}

local notifyRemote: RemoteEvent

local function getNumber(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

function QuestManager.report(player: Player, event: string, amount: number?)
	local step = ONBOARDING_STEPS[event]
	if step then
		AnalyticsManager.onboarding(player, step)
	end

	local index = getNumber(player, "QuestIndex")
	local quest = Config.Quests[index]
	if not quest or quest.Event ~= event then
		return
	end

	local progress = getNumber(player, "QuestProgress") + (amount or 1)
	if progress < quest.Goal then
		player:SetAttribute("QuestProgress", progress)
		return
	end

	-- Quest done: start the next one.
	player:SetAttribute("QuestIndex", index + 1)
	player:SetAttribute("QuestProgress", 0)
	notifyRemote:FireClient(player, `Quest complete: {quest.Text}!`)

	-- That was the last one: remember it, so the quests don't start over on the next visit.
	if not Config.Quests[index + 1] then
		AnalyticsManager.onboarding(player, "TutorialDone")
		SaveManager.addUnlock(player, TUTORIAL_DONE)
	end
end

-- Studio's "Forget tutorial" button: back to being a new player (see DebugManager).
function QuestManager.forget(player: Player)
	SaveManager.removeUnlock(player, TUTORIAL_DONE)
	SaveManager.removeUnlock(player, INTRO_SEEN)
	player:SetAttribute("QuestIndex", 1)
	player:SetAttribute("QuestProgress", 0)
end

-- Someone who finished the quests on an earlier visit doesn't see them again (QuestIndex 0
-- hides the box). A number past the last quest means they only just finished, and the
-- "All quests done!" box is showing.
local function hideIfDone(player: Player)
	if player:GetAttribute(`Unlock_{TUTORIAL_DONE}`) == true and getNumber(player, "QuestIndex") <= #Config.Quests then
		player:SetAttribute("QuestIndex", 0)
		player:SetAttribute("QuestProgress", 0)
	end
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("QuestIndex", 1)
	player:SetAttribute("QuestProgress", 0)
	-- Your save loads a moment after you join, so this may only be known then.
	player:GetAttributeChangedSignal(`Unlock_{TUTORIAL_DONE}`):Connect(function()
		hideIfDone(player)
	end)
	hideIfDone(player)
end

function QuestManager.init() end

function QuestManager.start()
	notifyRemote = Remotes.getEvent("Notify")

	-- Nothing to cheat with: it only saves that YOU pressed PLAY.
	Remotes.getEvent("PressedPlay").OnServerEvent:Connect(function(player: Player)
		AnalyticsManager.onboarding(player, "PressedPlay")
		SaveManager.addUnlock(player, INTRO_SEEN)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this ran (can happen in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return QuestManager
