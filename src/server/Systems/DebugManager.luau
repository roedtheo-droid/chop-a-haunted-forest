--!strict
-- Test shortcuts that only work in Roblox Studio, never in the real game.
--
-- "Skip to boss" (the button from DebugController):
--   1. moves you in front of the Elder Hollow,
--   2. clears every tree in the forest the normal way (zone %, gates opening, mimics
--      forgotten), so the boss wakes up on its own as the last tree,
--   3. gives you the Chainsaw, so the roots don't take ages with fists.
-- The cleared trees don't count toward run totals or saved stats.
--
-- Why check IsStudio here on the SERVER? The button only exists in Studio, but anyone
-- can fire a remote. On a live server this module ignores the request, so nobody can
-- use it to cheat.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local MimicManager = require(script.Parent.MimicManager)
local ToolManager = require(script.Parent.ToolManager)
local ZoneManager = require(script.Parent.ZoneManager)

local DebugManager = {}

local function isAllowed(): boolean
	return RunService:IsStudio() and Config.StudioShortcuts
end

-- Remove every standing tree and awake mimic, zone by zone, as if they were chopped.
local function clearForest()
	local trees: { Model } = {}
	for _, tag in { Tags.Tree, Tags.AwakeMimic } do
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsA("Model") then
				table.insert(trees, instance)
			end
		end
	end
	-- Zone 1 first, so the gates open in order (with their normal messages).
	table.sort(trees, function(a: Model, b: Model): boolean
		local zoneA = a:GetAttribute("ZoneId")
		local zoneB = b:GetAttribute("ZoneId")
		return (if typeof(zoneA) == "number" then zoneA else 0) < (if typeof(zoneB) == "number" then zoneB else 0)
	end)

	for _, tree in trees do
		local zoneId = tree:GetAttribute("ZoneId")
		MimicManager.forget(tree) -- does nothing for normal trees
		CollectionService:RemoveTag(tree, Tags.Tree)
		tree:Destroy()
		if typeof(zoneId) == "number" then
			ZoneManager.treeCleared(zoneId)
		end
	end
end

local function onSkipToBoss(player: Player)
	if not isAllowed() then
		return
	end
	local character = player.Character
	if not character then
		return
	end

	-- Move first, so the boss has someone to slam when it wakes up.
	local boss = Config.Boss.Position
	local spot = boss + Vector3.new(0, 4, Config.Boss.ClearRadius * 0.6) -- in front of it (+Z)
	character:PivotTo(CFrame.lookAt(spot, Vector3.new(boss.X, spot.Y, boss.Z)))

	if not ToolManager.owns(player, "Chainsaw") then
		ToolManager.give(player, "Chainsaw")
	end
	clearForest()
end

function DebugManager.init() end

function DebugManager.start()
	Remotes.getEvent("DebugSkipToBoss").OnServerEvent:Connect(onSkipToBoss)
	if isAllowed() and Config.DebugPrints then
		print("[Debug] Studio shortcuts are ON (the Skip to boss button)")
	end
end

return DebugManager
