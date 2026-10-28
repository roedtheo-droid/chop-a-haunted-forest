--!strict
-- Mimics: trees that are secretly monsters.
--
-- At the start, some trees in each zone become mimics (MimicPercent in Config.Zones).
-- WHICH trees are mimics is kept only here on the server (the `mimics` table), never in
-- attributes: every player's computer can read attributes, so a cheater could just look.
-- Each mimic gets one "tell" that sharp-eyed players can spot:
--   Tint   the bark colour is slightly off
--   Sway   the leaves sway while no other tree moves
--   Tilt   it leans a little, or it's a bit too tall
--   Creak  it creaks when you're close
--   Blink  a knot on its trunk sometimes opens like an eye
--
-- Hitting a sleeping mimic wakes it (TreeManager calls MimicManager.wake). It shakes
-- loose, then chases the nearest player in its zone, using PathfindingService to walk
-- around the other trees. If it catches someone, they're knocked down (KnockdownManager)
-- and the mimic roots itself again somewhere nearby, so friends can come and revive them
-- (Config.Mimics.HideAfterCatch). It also roots itself again after a while without
-- catching anyone.
-- Chopping an awake mimic down counts toward the zone's % like any other tree.
-- Hitting a SLEEPING mimic with the Torch burns it safely instead (TreeManager), and
-- the Lantern shows sleeping mimics near the player holding it (LanternManager).

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Boss = require(ReplicatedStorage.Shared.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Zones = require(ReplicatedStorage.Shared.Zones)
local EffectsManager = require(script.Parent.EffectsManager)
local ForestSpawner = require(script.Parent.ForestSpawner)
local KnockdownManager = require(script.Parent.KnockdownManager)

local TELLS = { "Tint", "Sway", "Tilt", "Creak", "Blink" }
local EYE_COLOR = Color3.fromRGB(255, 60, 40)
local BLINK_COLOR = Color3.fromRGB(255, 230, 120)
local CREAK_VOLUME = 0.7
local SHAKE_ANGLE = math.rad(5) -- how far it rocks while shaking loose
local LEAN_FORWARD = math.rad(8) -- it leans into the chase
local WADDLE_ANGLE = math.rad(4) -- side to side, like it's running on its roots
local SINK_DEPTH = 3 -- studs it sinks into the ground when it roots itself again
local SINK_TIME = 0.5
local ZONE_EDGE = 2 -- it stays at least this far inside its zone
local MAX_SPOT_TRIES = 40

type Mimic = {
	Tree: Model,
	Trunk: BasePart,
	Leaves: BasePart?,
	Tell: string,
	ZoneId: number,
	Awake: boolean,
	-- Goes up every time it wakes, roots itself or is chopped down, so an old
	-- chase loop can tell it should stop.
	Gen: number,
	Toughened: boolean, -- has it had its HP multiplied yet?
	LastCatch: number, -- when it woke or last caught someone (os.clock)
	NextTell: number, -- when it creaks or blinks next (os.clock)
	Lean: CFrame?, -- a leaning "Tilt" mimic's lean, put back every time it roots itself
	SwayTween: Tween?,
	SwayCenter: CFrame?,
	Knot: BasePart?,
	KnotColor: Color3?,
	Creak: Sound?,
}

local MimicManager = {}

local mimics: { [Model]: Mimic } = {}
local notifyRemote: RemoteEvent
local random = Random.new()
local debugFolder: Folder? -- only in Studio, see init()

local function getNumber(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function notifyZone(zoneId: number, text: string)
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		if root and Zones.indexAt(root.Position) == zoneId then
			notifyRemote:FireClient(player, text)
		end
	end
end

-- Awake mimics let players walk through them (they catch by distance instead),
-- which also stops them from blocking their own path.
local function setCollide(mimic: Mimic, on: boolean)
	mimic.Trunk.CanCollide = on
	local leaves = mimic.Leaves
	if leaves then
		leaves.CanCollide = on
	end
end

---------------------------------------------------------------------------
-- Tells
---------------------------------------------------------------------------

local function startSway(mimic: Mimic)
	local leaves = mimic.Leaves
	if mimic.Tell ~= "Sway" or not leaves then
		return
	end
	local cfg = Config.Mimics
	local angle = random:NextNumber(0, math.pi * 2)
	local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (cfg.SwayDistance / 2)
	-- Move Leaves by its CFrame (not Position), so the leaf blocks welded to it come along.
	local center = leaves.CFrame
	mimic.SwayCenter = center
	leaves.CFrame = center - offset
	-- -1 repeats forever, and `true` swings back again each time.
	local tween = TweenService:Create(
		leaves,
		TweenInfo.new(cfg.SwayTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = center + offset }
	)
	tween:Play()
	mimic.SwayTween = tween
end

local function stopSway(mimic: Mimic)
	local tween = mimic.SwayTween
	if not tween then
		return
	end
	tween:Cancel()
	mimic.SwayTween = nil
	local leaves = mimic.Leaves
	local center = mimic.SwayCenter
	if leaves and center then
		leaves.CFrame = center
	end
end

-- Lean a leaning "Tilt" mimic (again), around the bottom of its trunk.
local function applyLean(mimic: Mimic)
	local lean = mimic.Lean
	if lean then
		mimic.Tree:PivotTo(CFrame.new(mimic.Tree:GetPivot().Position) * lean)
	end
end

local function setUpTell(mimic: Mimic)
	local cfg = Config.Mimics
	local trunk = mimic.Trunk

	if mimic.Tell == "Tint" then
		trunk.Color = trunk.Color:Lerp(cfg.TintColor, cfg.TintAmount)
	elseif mimic.Tell == "Tilt" then
		if random:NextNumber() < 0.5 then
			-- Lean a little, in a random direction.
			local angle = random:NextNumber(0, math.pi * 2)
			local axis = Vector3.new(math.cos(angle), 0, math.sin(angle))
			mimic.Lean = CFrame.fromAxisAngle(axis, math.rad(cfg.TiltAngle))
			applyLean(mimic)
		else
			-- A bit too tall: a longer trunk (Size.Y is the block's height), leaves moved up.
			-- (Moving Leaves by its CFrame brings the welded leaf blocks along.)
			local extra = trunk.Size.Y * cfg.TallExtra
			trunk.Size = Vector3.new(trunk.Size.X, trunk.Size.Y + extra, trunk.Size.Z)
			trunk.CFrame += Vector3.new(0, extra / 2, 0)
			local leaves = mimic.Leaves
			if leaves then
				leaves.CFrame += Vector3.new(0, extra, 0)
			end
		end
	elseif mimic.Tell == "Sway" then
		startSway(mimic)
	elseif mimic.Tell == "Creak" then
		-- "Linear" roll-off means the sound fades to nothing at RollOffMaxDistance.
		local sound = Instance.new("Sound")
		sound.Name = "Creak"
		sound.SoundId = cfg.CreakSoundId
		sound.Volume = CREAK_VOLUME
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound.RollOffMinDistance = 2
		sound.RollOffMaxDistance = cfg.CreakDistance
		sound.Parent = trunk
		mimic.Creak = sound
	elseif mimic.Tell == "Blink" then
		local knot = ForestSpawner.addKnot(mimic.Tree)
		mimic.Knot = knot
		mimic.KnotColor = if knot then knot.Color else nil
	end
end

local function doTell(mimic: Mimic)
	if mimic.Tell == "Creak" then
		local sound = mimic.Creak
		if sound then
			sound:Play()
		end
	elseif mimic.Tell == "Blink" then
		local knot = mimic.Knot
		local color = mimic.KnotColor
		if knot and color then
			knot.Color = BLINK_COLOR
			knot.Material = Enum.Material.Neon
			task.delay(Config.Mimics.BlinkTime, function()
				knot.Color = color
				knot.Material = Enum.Material.Wood
			end)
		end
	end
end

local function scheduleNextTell(mimic: Mimic)
	mimic.NextTell = os.clock() + random:NextNumber(Config.Mimics.TellMinGap, Config.Mimics.TellMaxGap)
end

---------------------------------------------------------------------------
-- Picking the mimics
---------------------------------------------------------------------------

local function addDebugEntry(mimic: Mimic)
	local folder = debugFolder
	if folder then
		local entry = Instance.new("ObjectValue")
		entry.Name = `Zone{mimic.ZoneId} {mimic.Tell}`
		entry.Value = mimic.Tree
		entry.Parent = folder
	end
end

local function removeDebugEntry(tree: Model)
	local folder = debugFolder
	if not folder then
		return
	end
	for _, entry in folder:GetChildren() do
		if entry:IsA("ObjectValue") and entry.Value == tree then
			entry:Destroy()
		end
	end
end

local function makeMimic(tree: Model, zoneId: number)
	local trunk = tree:FindFirstChild("Trunk")
	if not (trunk and trunk:IsA("BasePart")) then
		return
	end
	local leaves = tree:FindFirstChild("Leaves")
	local mimic: Mimic = {
		Tree = tree,
		Trunk = trunk,
		Leaves = if leaves and leaves:IsA("BasePart") then leaves else nil,
		Tell = TELLS[random:NextInteger(1, #TELLS)],
		ZoneId = zoneId,
		Awake = false,
		Gen = 0,
		Toughened = false,
		LastCatch = 0,
		NextTell = 0,
	}
	mimics[tree] = mimic
	setUpTell(mimic)
	scheduleNextTell(mimic)
	addDebugEntry(mimic)
end

local function pickMimics()
	-- Group the trees by zone. Cursed trees are never mimics, so their purple glow
	-- always means "valuable", never "danger".
	local candidates: { [number]: { Model } } = {}
	local totals: { [number]: number } = {}
	for _, instance in CollectionService:GetTagged(Tags.Tree) do
		local zoneId = instance:GetAttribute("ZoneId")
		if instance:IsA("Model") and typeof(zoneId) == "number" then
			totals[zoneId] = (totals[zoneId] or 0) + 1
			if instance:GetAttribute("Cursed") ~= true then
				local list = candidates[zoneId] or {}
				candidates[zoneId] = list
				table.insert(list, instance)
			end
		end
	end

	for zoneId, zone in Config.Zones do
		local list = candidates[zoneId] or {}
		local count = math.min(math.round((totals[zoneId] or 0) * zone.MimicPercent / 100), #list)
		-- Shuffle the list, then the first `count` trees become mimics.
		for i = #list, 2, -1 do
			local j = random:NextInteger(1, i)
			list[i], list[j] = list[j], list[i]
		end
		for i = 1, count do
			makeMimic(list[i], zoneId)
		end
	end
end

---------------------------------------------------------------------------
-- Awake: shake loose, chase, catch
---------------------------------------------------------------------------

local function isCurrent(mimic: Mimic, gen: number): boolean
	return mimics[mimic.Tree] == mimic and mimic.Gen == gen and mimic.Tree.Parent ~= nil
end

local function addEyes(mimic: Mimic)
	local trunk = mimic.Trunk
	local pivot = mimic.Tree:GetPivot()
	local height = trunk.Size.Y * 0.65
	local radius = trunk.Size.X / 2
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.8
		eye.Color = EYE_COLOR
		eye.Material = Enum.Material.Neon
		eye.Anchored = true
		eye.CanCollide = false
		-- In the tree's own space, -Z is the way it faces.
		eye.CFrame = pivot * CFrame.new(side * radius * 0.45, height, -radius)
		eye.Parent = mimic.Tree
	end
end

local function removeEyes(mimic: Mimic)
	for _, child in mimic.Tree:GetChildren() do
		if child.Name == "Eye" then
			child:Destroy()
		end
	end
end

-- The nearest player in the mimic's zone that it's allowed to catch.
local function findTarget(mimic: Mimic): BasePart?
	local position = mimic.Tree:GetPivot().Position
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		if root and KnockdownManager.canBeCaught(player) and Zones.indexAt(root.Position) == mimic.ZoneId then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best = root
				bestDistance = distance
			end
		end
	end
	return best
end

-- Knock down everyone close enough. Returns true if it caught anyone.
local function catchPlayers(mimic: Mimic): boolean
	local position = mimic.Tree:GetPivot().Position
	local cfg = Config.Mimics
	local caught = false
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		if
			root
			and KnockdownManager.canBeCaught(player)
			and flatDistance(root.Position, position) <= cfg.CatchDistance
			and math.abs(root.Position.Y - position.Y) <= cfg.CatchHeight
		then
			KnockdownManager.knockDown(player)
			mimic.LastCatch = os.clock()
			caught = true
		end
	end
	return caught
end

-- Keep the mimic inside its own zone.
local function clampToZone(position: Vector3, zoneId: number): Vector3
	local bounds = Zones.getBounds(zoneId)
	return Vector3.new(
		math.clamp(position.X, bounds.MinX + ZONE_EDGE, bounds.MaxX - ZONE_EDGE),
		position.Y,
		math.clamp(position.Z, bounds.MinZ + ZONE_EDGE, bounds.MaxZ - ZONE_EDGE)
	)
end

-- Move one frame's worth towards waypoints[index]. Returns the next waypoint index.
local function stepTowards(mimic: Mimic, waypoints: { Vector3 }, index: number, dt: number, groundY: number): number
	local tree = mimic.Tree
	local pivot = tree:GetPivot()
	local position = pivot.Position
	local waypoint = waypoints[index]
	local goal = Vector3.new(waypoint.X, groundY, waypoint.Z)
	local offset = goal - position
	local stepLength = Config.Mimics.ChaseSpeed * dt

	local newPosition: Vector3
	if offset.Magnitude <= stepLength then
		newPosition = goal
		index += 1
	else
		newPosition = position + offset.Unit * stepLength
	end
	newPosition = clampToZone(newPosition, mimic.ZoneId)

	-- Face the way it's going, lean into the chase and waddle a little.
	local facing = Vector3.new(offset.X, 0, offset.Z)
	if facing.Magnitude < 0.05 then
		facing = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	end
	if facing.Magnitude < 0.05 then
		facing = Vector3.new(0, 0, -1)
	end
	local waddle = math.sin(os.clock() * 12) * WADDLE_ANGLE
	tree:PivotTo(CFrame.lookAt(newPosition, newPosition + facing.Unit) * CFrame.Angles(-LEAN_FORWARD, 0, waddle))
	return index
end

-- Work out a path to the target, then follow it until it's time to work out a new one.
-- Returns true if it caught someone on the way.
local function chaseStep(mimic: Mimic, gen: number, path: Path, target: BasePart, groundY: number): boolean
	local from = mimic.Tree:GetPivot().Position
	local goal = Vector3.new(target.Position.X, groundY, target.Position.Z)
	local waypoints: { Vector3 } = { goal } -- if no path is found, walk straight at the target

	local ok = pcall(function()
		path:ComputeAsync(from, goal)
	end)
	if not isCurrent(mimic, gen) then
		return false -- working out the path takes a moment, and the mimic may be gone by then
	end
	if ok and path.Status == Enum.PathStatus.Success then
		local points: { Vector3 } = {}
		for i, waypoint in path:GetWaypoints() do
			if i > 1 then -- the first waypoint is where it already stands
				table.insert(points, waypoint.Position)
			end
		end
		if #points > 0 then
			waypoints = points
		end
	end

	local stopAt = os.clock() + Config.Mimics.RepathInterval
	local index = 1
	while os.clock() < stopAt do
		local dt = RunService.Heartbeat:Wait()
		if not isCurrent(mimic, gen) then
			return false
		end
		if index <= #waypoints then
			index = stepTowards(mimic, waypoints, index, dt, groundY)
		end
		if catchPlayers(mimic) then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Rooting itself again
---------------------------------------------------------------------------

-- Is this spot free (not too close to another tree or a player)?
local function isFreeSpot(spot: Vector3, mimicTree: Model): boolean
	local spacing = Config.Forest.MinSpacing
	for _, tag in { Tags.Tree, Tags.AwakeMimic } do
		for _, other in CollectionService:GetTagged(tag) do
			if other ~= mimicTree and other:IsA("Model") and flatDistance(other:GetPivot().Position, spot) < spacing then
				return false
			end
		end
	end
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		if root and flatDistance(root.Position, spot) < spacing then
			return false
		end
	end
	return true
end

local function findSleepSpot(mimic: Mimic): Vector3
	local zone = Config.Zones[mimic.ZoneId]
	local bounds = Zones.getBounds(mimic.ZoneId)
	local margin = Config.Forest.EdgeMargin
	local here = mimic.Tree:GetPivot().Position
	for _ = 1, MAX_SPOT_TRIES do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(0, Config.Mimics.SleepSearchRadius)
		local spot = here + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		if
			spot.X >= bounds.MinX + margin
			and spot.X <= bounds.MaxX - margin
			and spot.Z >= bounds.MinZ + margin
			and spot.Z <= bounds.MaxZ - margin
			and flatDistance(spot, zone.Sawmill) >= zone.ClearRadius
			and Zones.distanceToPath(spot.X, spot.Z) >= Config.Path.TreeClearance
			and not Boss.isInClearing(spot)
			and not Zones.isNearLandmark(spot.X, spot.Z)
			and isFreeSpot(spot, mimic.Tree)
		then
			return spot
		end
	end
	return here
end

-- Slide the whole tree from one CFrame to another over `duration` seconds.
local function slide(tree: Model, from: CFrame, to: CFrame, duration: number)
	local elapsed = 0
	while elapsed < duration and tree.Parent do
		elapsed += RunService.Heartbeat:Wait()
		tree:PivotTo(from:Lerp(to, math.min(elapsed / duration, 1)))
	end
end

local function rootAgain(mimic: Mimic, gen: number)
	local tree = mimic.Tree
	-- While it digs in it's neither awake nor a tree, so nobody can chop it mid-move.
	CollectionService:RemoveTag(tree, Tags.AwakeMimic)

	local spot = findSleepSpot(mimic)
	local start = tree:GetPivot()
	local down = Vector3.new(0, SINK_DEPTH, 0)
	slide(tree, start, start - down, SINK_TIME) -- sink into the ground...
	removeEyes(mimic)
	local upright = CFrame.new(spot)
	tree:PivotTo(upright - down)
	slide(tree, upright - down, upright, SINK_TIME) -- ...and come up somewhere nearby
	if not isCurrent(mimic, gen) then
		return
	end

	mimic.Awake = false
	setCollide(mimic, true)
	applyLean(mimic)
	startSway(mimic)
	scheduleNextTell(mimic)
	CollectionService:AddTag(tree, Tags.Tree)
	notifyZone(mimic.ZoneId, "The mimic hid among the trees again...")
end

-- Everything an awake mimic does, from waking up to rooting itself again.
local function runAwake(mimic: Mimic, gen: number)
	local tree = mimic.Tree

	-- 1. Shake loose. This is the players' head start (they can keep chopping it).
	local start = tree:GetPivot()
	local elapsed = 0
	while elapsed < Config.Mimics.WakeTime do
		elapsed += RunService.Heartbeat:Wait()
		if not isCurrent(mimic, gen) then
			return
		end
		tree:PivotTo(start * CFrame.Angles(0, 0, math.sin(elapsed * 40) * SHAKE_ANGLE))
	end
	tree:PivotTo(start)

	-- 2. Chase players until it catches someone or goes too long without catching anyone.
	-- AgentHeight is small so the path can go under other trees' leaves.
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 4,
	})
	local groundY = start.Position.Y
	while isCurrent(mimic, gen) do
		if os.clock() - mimic.LastCatch > Config.Mimics.SleepAfter then
			rootAgain(mimic, gen)
			return
		end
		local target = findTarget(mimic)
		if target then
			local caught = chaseStep(mimic, gen, path, target, groundY)
			if caught and Config.Mimics.HideAfterCatch then
				-- Otherwise it would go straight for whoever comes to revive them.
				rootAgain(mimic, gen)
				return
			end
		else
			task.wait(0.5) -- nobody to chase in its zone right now
		end
	end
end

---------------------------------------------------------------------------
-- Used by TreeManager
---------------------------------------------------------------------------

function MimicManager.isMimic(tree: Model): boolean
	return mimics[tree] ~= nil
end

-- A mimic standing still as a tree (not awake, and not digging itself back in).
-- Only these can be burned with the Torch or seen with the Lantern.
function MimicManager.isSleeping(tree: Model): boolean
	local mimic = mimics[tree]
	return mimic ~= nil and not mimic.Awake and CollectionService:HasTag(tree, Tags.Tree)
end

-- Every sleeping mimic within `radius` studs of `position` (used by LanternManager).
function MimicManager.sleepingNear(position: Vector3, radius: number): { Model }
	local found: { Model } = {}
	for tree in mimics do
		if MimicManager.isSleeping(tree) and flatDistance(tree:GetPivot().Position, position) <= radius then
			table.insert(found, tree)
		end
	end
	return found
end

-- A player hit a sleeping mimic: wake it up.
function MimicManager.wake(tree: Model, hitBy: Player)
	local mimic = mimics[tree]
	if not mimic or mimic.Awake then
		return
	end
	mimic.Awake = true
	mimic.Gen += 1
	mimic.LastCatch = os.clock()
	stopSway(mimic)
	CollectionService:RemoveTag(tree, Tags.Tree)
	CollectionService:AddTag(tree, Tags.AwakeMimic)
	setCollide(mimic, false)

	-- Awake mimics are tougher. HP and MaxHP both go up, so the damage done so far stays.
	if not mimic.Toughened then
		mimic.Toughened = true
		local multiplier = Config.Mimics.HPMultiplier
		tree:SetAttribute("MaxHP", getNumber(tree, "MaxHP") * multiplier)
		tree:SetAttribute("HP", getNumber(tree, "HP") * multiplier)
	end

	-- Stand up straight, turn towards whoever hit it and open its eyes.
	local base = tree:GetPivot().Position
	local root = getRoot(hitBy)
	local facing = if root then Vector3.new(root.Position.X - base.X, 0, root.Position.Z - base.Z) else Vector3.zero
	if facing.Magnitude < 0.05 then
		facing = Vector3.new(0, 0, -1)
	end
	tree:PivotTo(CFrame.lookAt(base, base + facing.Unit))
	addEyes(mimic)
	EffectsManager.playSound("MimicWake", base)

	notifyZone(mimic.ZoneId, "A mimic woke up! Run!")
	task.spawn(runAwake, mimic, mimic.Gen)
end

-- A mimic was chopped down or burned: stop everything it was doing.
-- TreeManager makes it fall (or burn).
function MimicManager.forget(tree: Model)
	local mimic = mimics[tree]
	if not mimic then
		return
	end
	mimics[tree] = nil
	mimic.Gen += 1
	stopSway(mimic)
	CollectionService:RemoveTag(tree, Tags.AwakeMimic)
	removeDebugEntry(tree)
end

function MimicManager.init()
	-- Only in Studio: a list of the mimics in ServerStorage > MimicDebug, to find them
	-- while testing. ServerStorage is never sent to players, so this stays secret.
	if RunService:IsStudio() then
		local folder = Instance.new("Folder")
		folder.Name = "MimicDebug"
		folder.Parent = ServerStorage
		debugFolder = folder
	end
	pickMimics()
end

function MimicManager.start()
	notifyRemote = Remotes.getEvent("Notify")

	-- Creaks and blinks for sleeping mimics, every few seconds each.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for _, mimic in mimics do
				if not mimic.Awake and now >= mimic.NextTell then
					scheduleNextTell(mimic)
					doTell(mimic)
				end
			end
		end
	end)
end

return MimicManager
