--!strict
-- Courage: the haunted forest slowly scares you (an idea from Theo's Claude Design export).
--
-- Every player has a "Courage" attribute from 0 to Config.Courage.Max. Only the server
-- changes it; the client just draws the bar (HudController). A few times a second:
--   * in the camp, courage fills up fast
--   * in a zone, it drains (faster in the darker zones), and faster near ghosts
--   * holding a Lantern or Torch in a zone, it slowly fills up instead, and ghosts don't scare you
--   * holding the Chainsaw drains a little extra
--   * at 0 you're too scared and slowly lose health
-- Courage is full again every time you spawn.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Zones = require(ReplicatedStorage.Shared.Zones)
local AnalyticsManager = require(script.Parent.AnalyticsManager)
local KnockdownManager = require(script.Parent.KnockdownManager)
local ToolManager = require(script.Parent.ToolManager)

local cfg = Config.Courage
local ATTRIBUTE = "Courage"

local CourageManager = {}

local notifyRemote: RemoteEvent
-- What we already warned each player about: "Low" or "TooScared" (told again only after they calm down).
local warned: { [Player]: string } = {}

function CourageManager.get(player: Player): number
	local value = player:GetAttribute(ATTRIBUTE)
	return if typeof(value) == "number" then value else cfg.Max
end

-- Add (or take away, with a negative amount) courage. It stays between 0 and Max.
function CourageManager.add(player: Player, amount: number)
	player:SetAttribute(ATTRIBUTE, math.clamp(CourageManager.get(player) + amount, 0, cfg.Max))
end

-- Is the player holding something that lights up the dark?
function CourageManager.holdsLight(player: Player): boolean
	local toolId = ToolManager.getEquippedId(player)
	return toolId == "Lantern" or toolId == "Torch"
end

-- How many ghosts are close enough to scare someone standing here.
local function scaryGhostsNear(position: Vector3): number
	local count = 0
	for _, ghost in CollectionService:GetTagged(Tags.Ghost) do
		if ghost:IsA("Model") and ghost:IsDescendantOf(workspace) and ghost:GetAttribute("Caught") ~= true then
			if (ghost:GetPivot().Position - position).Magnitude <= cfg.GhostRadius then
				count += 1
			end
		end
	end
	return math.min(count, cfg.MaxScaryGhosts)
end

-- How much courage this player gains (+) or loses (-) per second, where they stand right now.
local function changePerSecond(player: Player, position: Vector3): number
	if Zones.isInCamp(position) then
		return cfg.CampRegen
	end
	local zone = Zones.indexAt(position)
	if not zone then
		return 0 -- outside the camp and the zones (shouldn't happen): leave it alone
	end
	if CourageManager.holdsLight(player) then
		return cfg.LightRegen
	end
	local change = -(cfg.ZoneDrain[zone] or cfg.ZoneDrain[#cfg.ZoneDrain])
	change -= scaryGhostsNear(position) * (cfg.GhostDrain[zone] or cfg.GhostDrain[#cfg.GhostDrain])
	if ToolManager.getEquippedId(player) == "Chainsaw" then
		change -= cfg.ChainsawDrain
	end
	return change
end

local function update(player: Player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (humanoid and root and root:IsA("BasePart")) or humanoid.Health <= 0 then
		return
	end
	-- Lying on the ground is bad enough: no draining while you wait for a revive.
	if KnockdownManager.isDown(player) then
		return
	end

	CourageManager.add(player, changePerSecond(player, root.Position) * cfg.Tick)
	local courage = CourageManager.get(player)
	if courage <= 0 then
		humanoid:TakeDamage(cfg.FearDamage * cfg.Tick)
		if warned[player] ~= "TooScared" then
			warned[player] = "TooScared"
			notifyRemote:FireClient(player, cfg.Text.TooScared)
			AnalyticsManager.event(player, "TooScared")
		end
	elseif courage < cfg.LowAt then
		-- The first warning, while there's still time to do something about it.
		if not warned[player] then
			warned[player] = "Low"
			notifyRemote:FireClient(player, cfg.Text.GettingScared)
		end
	else
		warned[player] = nil
	end
end

local function onPlayerAdded(player: Player)
	player:SetAttribute(ATTRIBUTE, cfg.Max)
	player.CharacterAdded:Connect(function()
		player:SetAttribute(ATTRIBUTE, cfg.Max)
		warned[player] = nil
	end)
end

function CourageManager.init() end

function CourageManager.start()
	notifyRemote = Remotes.getEvent("Notify")

	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this ran (can happen in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		warned[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(cfg.Tick)
			for _, player in Players:GetPlayers() do
				update(player)
			end
		end
	end)
end

return CourageManager
