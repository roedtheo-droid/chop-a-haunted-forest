--!strict
-- Decorates the zones, only for looks (see the map design):
--   * the big landmarks in each zone (see Build/Landmarks)
--   * little things along the path: berry bushes, mossy rocks, mushrooms and fallen birches
--     in zone 1; lamp posts, broken fences and glowing mushrooms in zone 2; crooked
--     flickering lamps, pumpkins and dead bushes in zone 3
--   * fog banks drifting slowly through zone 2 (every player's computer moves them,
--     see Client/AmbientController)
-- None of it can be chopped, and no trees grow on the landmarks (see Zones.isNearLandmark).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boss = require(ReplicatedStorage.Shared.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Blocky = require(script.Parent.Parent.Build.Blocky)
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
-- `along` points along it. `count` numbers the props, to space out the lamps.
local function addPathProp(zoneIndex: number, spot: Vector3, toPath: Vector3, along: Vector3, count: number)
	local cfg = Config.Props
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
		if count % cfg.LampEvery == 0 then
			Props.lampPost(folder, spot, toPath, LAMP_WARM, false, random)
		elseif roll < 0.35 then
			local outside = spot - toPath * 0.6
			Props.fence(folder, outside - along * 3, outside + along * 3, true, random)
		elseif roll < 0.65 then
			local rock = Props.rock(folder, spot, random:NextNumber(1.8, 2.4), true, random, GLOW_ROCK)
			Props.mushrooms(folder, rock.CFrame * CFrame.new(0, rock.Size.Y / 2, 0), true, random)
		elseif roll < 0.85 then
			Props.rock(folder, spot, random:NextNumber(1.4, 2.2), true, random, GLOW_ROCK)
		end
	else
		if count % cfg.LampEvery == 0 then
			Props.flicker(Props.lampPost(folder, spot, toPath, LAMP_ORANGE, true, random))
		elseif roll < 0.45 then
			Props.pumpkin(folder, spot, toPath, random:NextNumber() < 0.4, random)
		elseif roll < 0.7 then
			Props.rock(folder, spot, random:NextNumber(1.4, 2.2), false, random, DARK_ROCK)
		elseif roll < 0.85 then
			addDeadBush(spot)
		end
	end
end

-- Walk along the path and put a prop every few studs, on alternating sides.
local function decoratePath()
	local cfg = Config.Props
	local points = Config.Path.Points
	local count = 0
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local direction = (b - a).Unit
		local normal = Vector2.new(-direction.Y, direction.X)
		local distance = cfg.PathSpacing / 2
		while distance < (b - a).Magnitude do
			count += 1
			local side = if count % 2 == 0 then 1 else -1
			local flat = a + direction * distance + normal * side * cfg.PathOffset
			local spot = Vector3.new(flat.X, 0, flat.Y)
			local zoneIndex = Zones.indexAt(spot)
			-- Near a bend the spot can end up on the next piece of path, so check it's beside it.
			if
				zoneIndex
				and not isNearGate(spot.Z)
				and not Boss.isInClearing(spot)
				and Zones.distanceToPath(spot.X, spot.Z) >= cfg.PathOffset - 0.5
			then
				local toPath = Vector3.new(-normal.X * side, 0, -normal.Y * side)
				addPathProp(zoneIndex, spot, toPath, Vector3.new(direction.X, 0, direction.Y), count)
			end
			distance += cfg.PathSpacing
		end
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
end

function LandmarkManager.start() end

return LandmarkManager
