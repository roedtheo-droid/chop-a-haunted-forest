--!strict
-- Decorates the zones, only for looks (see the map design):
--   * the big landmarks in each zone (see Build/Landmarks)
--   * little groups of things along the path, with empty stretches between them: berry
--     bushes, mossy rocks, mushrooms and fallen birches in zone 1; broken fences and glowing
--     mushrooms in zone 2; pumpkins and dead bushes in zone 3. Zones 2 and 3 also have lamp
--     posts at even steps along the path (crooked, flickering ones in zone 3)
--   * fog banks drifting slowly through zone 2 (every player's computer moves them,
--     see Client/AmbientController)
--   * little things on the ground all over each zone (see Build/Details)
-- None of it can be chopped, and no trees grow on the landmarks (see Zones.isNearLandmark).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boss = require(ReplicatedStorage.Shared.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Blocky = require(script.Parent.Parent.Build.Blocky)
local Details = require(script.Parent.Parent.Build.Details)
local Landmarks = require(script.Parent.Parent.Build.Landmarks)
local Props = require(script.Parent.Parent.Build.Props)

local GROUND = 0.05 -- the top of the zone floors (see ZoneManager)
local LAMP_WARM = Color3.fromRGB(255, 225, 160)
local LAMP_ORANGE = Color3.fromRGB(255, 150, 60)
local DARK_ROCK = Color3.fromRGB(95, 90, 100)
local GLOW_ROCK = Color3.fromRGB(120, 132, 125)
local DEAD_WOOD = Color3.fromRGB(70, 55, 45)
local FOG_COLOR = Color3.fromRGB(225, 232, 228)

local LandmarkManager = {}

-- The same random numbers every time, so everything is always in the same places.
local random = Random.new(11)
local folder: Folder

-- Is this Z close to a gate between zones, or to the bridge at the start of zone 1?
local function isNearGate(z: number): boolean
	for index = 1, Zones.count() do
		if math.abs(z - Zones.getBounds(index).MaxZ) < Config.Props.GateGap then
			return true
		end
	end
	return false
end

-- A dead bush: a few bare, dark twigs.
local function addDeadBush(spot: Vector3)
	for index = 1, 5 do
		local height = random:NextNumber(1.5, 2.8)
		local twig = Blocky.part(
			"DeadBush",
			Vector3.new(0.2, height, 0.2),
			CFrame.new(spot.X, GROUND, spot.Z)
				* CFrame.Angles(0, index * 1.3, random:NextNumber(0.25, 0.6))
				* CFrame.new(0, height / 2, 0),
			DEAD_WOOD,
			Enum.Material.Wood,
			folder
		)
		twig.CanCollide = false
	end
end

-- One prop beside the path at `spot`. `toPath` points from the spot to the path and
-- `along` points along it.
local function addPathProp(zoneIndex: number, spot: Vector3, toPath: Vector3, along: Vector3)
	local roll = random:NextNumber()
	if zoneIndex == 1 then
		if roll < 0.45 then
			Props.berryBush(folder, spot, random)
		elseif roll < 0.7 then
			Props.rock(folder, spot, random:NextNumber(1.6, 2.4), true, random)
		elseif roll < 0.9 then
			Props.mushrooms(folder, CFrame.new(spot.X, GROUND, spot.Z), false, random)
		else
			-- Lying along the path, a little further from it.
			Props.fallenLog(folder, spot - toPath * 0.8, math.atan2(along.X, along.Z), true, random)
		end
	elseif zoneIndex == 2 then
		if roll < 0.3 then
			local outside = spot - toPath * 0.6
			Props.fence(folder, outside - along * 3, outside + along * 3, true, random)
		elseif roll < 0.65 then
			local rock = Props.rock(folder, spot, random:NextNumber(1.8, 2.4), true, random, GLOW_ROCK)
			Props.mushrooms(folder, rock.CFrame * CFrame.new(0, rock.Size.Y / 2, 0), true, random)
		elseif roll < 0.85 then
			Props.rock(folder, spot, random:NextNumber(1.4, 2.2), true, random, GLOW_ROCK)
		else
			Props.mushrooms(folder, CFrame.new(spot.X, GROUND, spot.Z), true, random)
		end
	else
		if roll < 0.45 then
			Props.pumpkin(folder, spot, toPath, random:NextNumber() < 0.4, random)
		elseif roll < 0.7 then
			Props.rock(folder, spot, random:NextNumber(1.4, 2.2), false, random, DARK_ROCK)
		else
			addDeadBush(spot)
		end
	end
end

local function addLamp(zoneIndex: number, spot: Vector3, toPath: Vector3)
	if zoneIndex == 2 then
		Props.lampPost(folder, spot, toPath, LAMP_WARM, false, random)
	elseif zoneIndex == 3 then
		Props.flicker(Props.lampPost(folder, spot, toPath, LAMP_ORANGE, true, random))
	end
end

-- A spot beside the path, `distance` studs along it, on `side` (1 or -1), `offset` studs from
-- its middle. Also returns which way points to the path and which way along it. nil if that
-- spot is somewhere nothing should go: outside the zones, by a gate or the bridge, in the
-- boss's clearing, or (near a bend) too close to another piece of the path.
local function besidePath(distance: number, side: number, offset: number): (Vector3?, Vector3, Vector3)
	local points = Zones.getPathPoints()
	local travelled = 0
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local length = (b - a).Magnitude
		if length > 0 and distance <= travelled + length then
			local direction = (b - a).Unit
			local normal = Vector2.new(-direction.Y, direction.X)
			local flat = a + direction * (distance - travelled) + normal * side * offset
			local spot = Vector3.new(flat.X, 0, flat.Y)
			local toPath = Vector3.new(-normal.X * side, 0, -normal.Y * side)
			local along = Vector3.new(direction.X, 0, direction.Y)
			if
				Zones.indexAt(spot)
				and not isNearGate(spot.Z)
				and not Boss.isInClearing(spot)
				and Zones.distanceToPath(spot.X, spot.Z) >= Config.Props.PathOffset - 0.5
			then
				return spot, toPath, along
			end
			return nil, toPath, along
		end
		travelled += length
	end
	return nil, Vector3.zAxis, Vector3.xAxis
end

-- How long the whole (smooth) path is, in studs.
local function pathLength(): number
	local points = Zones.getPathPoints()
	local total = 0
	for index = 1, #points - 1 do
		total += (points[index + 1] - points[index]).Magnitude
	end
	return total
end

-- Little groups of props along the path, with empty stretches between them, and (in zones
-- 2 and 3) lamp posts at even steps, on alternate sides.
local function decoratePath()
	local cfg = Config.Props
	local total = pathLength()
	local lamps: { Vector3 } = {}

	local side = 1
	local distance = cfg.LampSpacing / 2
	while distance < total do
		local spot, toPath = besidePath(distance, side, cfg.PathOffset)
		local zoneIndex = if spot then Zones.indexAt(spot) else nil
		if spot and zoneIndex and zoneIndex >= 2 then
			addLamp(zoneIndex, spot, toPath)
			table.insert(lamps, spot)
		end
		side = -side
		distance += cfg.LampSpacing
	end

	distance = random:NextNumber(cfg.GroupSpacing[1], cfg.GroupSpacing[2]) / 2
	while distance < total do
		side = if random:NextNumber() < 0.5 then 1 else -1
		for _ = 1, random:NextInteger(cfg.GroupSize[1], cfg.GroupSize[2]) do
			local along = distance + random:NextNumber(-cfg.GroupSpread, cfg.GroupSpread)
			local offset = cfg.PathOffset + random:NextNumber(0, 2.5)
			local spot, toPath, direction = besidePath(along, side, offset)
			local zoneIndex = if spot then Zones.indexAt(spot) else nil
			local clear = true
			if spot then
				for _, lamp in lamps do
					if (lamp - spot).Magnitude < 4 then
						clear = false -- not on top of a lamp post
						break
					end
				end
			end
			if spot and zoneIndex and clear then
				addPathProp(zoneIndex, spot, toPath, direction)
			end
		end
		distance += random:NextNumber(cfg.GroupSpacing[1], cfg.GroupSpacing[2])
	end
end

-- See-through clouds low over zone 2. Every player's computer makes them drift slowly.
local function addFogBanks()
	local bounds = Zones.getBounds(2)
	for _ = 1, Config.Props.FogBanks do
		local size = Vector3.new(random:NextNumber(22, 38), random:NextNumber(3, 5), random:NextNumber(10, 16))
		local fog = Blocky.part(
			"FogBank",
			size,
			CFrame.new(
				random:NextNumber(bounds.MinX + 20, bounds.MaxX - 20),
				GROUND + random:NextNumber(1.5, 2.5),
				random:NextNumber(bounds.MinZ + 15, bounds.MaxZ - 15)
			),
			FOG_COLOR,
			Enum.Material.SmoothPlastic,
			folder
		)
		fog.Transparency = 0.75
		fog.CanCollide = false
		fog.CanQuery = false
		fog.CanTouch = false
		fog.CastShadow = false
		fog:SetAttribute("Phase", random:NextNumber(0, math.pi * 2))
		CollectionService:AddTag(fog, Tags.FogBank)
	end
end

function LandmarkManager.init()
	folder = Instance.new("Folder")
	folder.Name = "Landmarks"
	Landmarks.build(folder, random)
	decoratePath()
	addFogBanks()
	folder.Parent = workspace
	Details.build(workspace) -- grass, flowers, ferns, dead leaves... on the ground
end

function LandmarkManager.start() end

return LandmarkManager
