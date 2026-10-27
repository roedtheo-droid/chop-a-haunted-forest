--!strict
-- Tutorial quests: a short list that teaches new players the core loop.
--
-- Other systems call QuestManager.report(player, "FellTree") when something happens.
-- If it matches the player's current quest, progress goes up; at the goal, the next
-- quest starts. Progress is stored in two player attributes the client shows:
--   QuestIndex     which quest (1, 2, 3...; one past the last = all done)
--   QuestProgress  how far into the current quest

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local QuestManager = {}

local notifyRemote: RemoteEvent

local function getNumber(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

function QuestManager.report(player: Player, event: string, amount: number?)
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
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("QuestIndex", 1)
	player:SetAttribute("QuestProgress", 0)
end

function QuestManager.init() end

function QuestManager.start()
	notifyRemote = Remotes.getEvent("Notify")

	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this ran (can happen in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return QuestManager
