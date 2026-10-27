--!strict
-- The Lantern: while a player holds it, sleeping mimics near them get a faint outline.
--
-- Which trees are mimics is a server secret (see MimicManager). So the server checks,
-- a few times a second, who is holding a Lantern, and tells ONLY that player which
-- mimics are within their lantern's radius. Their client draws the outlines
-- (LanternController). A cheater can't learn more than their own lantern would show.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MimicManager = require(script.Parent.MimicManager)
local ToolManager = require(script.Parent.ToolManager)
local UpgradeManager = require(script.Parent.UpgradeManager)

local LanternManager = {}

local lanternRemote: RemoteEvent
-- The mimics we last told each player about, so we only send a message when it changes.
local shown: { [Player]: { [Model]: boolean } } = {}

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function update(player: Player)
	local visible: { Model } = {}
	local root = getRoot(player)
	if root and ToolManager.getEquippedId(player) == "Lantern" then
		visible = MimicManager.sleepingNear(root.Position, UpgradeManager.lanternRadius(player))
	end

	-- Same mimics as last time? Then there's nothing new to tell the player.
	local old = shown[player] or {}
	local new: { [Model]: boolean } = {}
	local changed = false
	for _, tree in visible do
		new[tree] = true
		if not old[tree] then
			changed = true
		end
	end
	for tree in old do
		if not new[tree] then
			changed = true
		end
	end

	if changed then
		shown[player] = new
		lanternRemote:FireClient(player, visible)
	end
end

function LanternManager.init() end

function LanternManager.start()
	lanternRemote = Remotes.getEvent("LanternMimics")

	Players.PlayerRemoving:Connect(function(player: Player)
		shown[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Lantern.Refresh)
			for _, player in Players:GetPlayers() do
				update(player)
			end
		end
	end)
end

return LanternManager
