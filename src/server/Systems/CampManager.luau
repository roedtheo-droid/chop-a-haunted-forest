--!strict
-- Builds the camp in front of zone 1 (see Config.Camp): its grass, the river with a bridge
-- across its far end, and the dirt path that runs from spawn through every gate to the boss.
-- It also moves the place's SpawnLocation into the camp. No trees grow in the camp
-- (it isn't a zone), and none grow on the path (see ForestSpawner).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Blocky = require(script.Parent.Parent.Build.Blocky)

local FLOOR_THICKNESS = 1
local FLOOR_TOP = 0.05 -- the same height as the zone floors (see ZoneManager)
local PATH_THICKNESS = 0.2
local RIVER_TOP = 0.3 -- a little above the ground: you wade through it
local BRIDGE_TOP = 1.2
local RAMP_LENGTH = 3
local RAIL_HEIGHT = 2.5

local CampManager = {}

local folder: Folder

local function buildFloor()
	local bounds = Zones.getCampBounds()
	Blocky.part(
		"CampFloor",
		Vector3.new(bounds.MaxX - bounds.MinX, FLOOR_THICKNESS, bounds.MaxZ - bounds.MinZ),
		CFrame.new((bounds.MinX + bounds.MaxX) / 2, FLOOR_TOP - FLOOR_THICKNESS / 2, (bounds.MinZ + bounds.MaxZ) / 2),
		Config.Camp.GroundColor,
		Enum.Material.Grass,
		folder
	)
end

-- The river runs across the whole camp, just before zone 1. Returns its middle (Z).
local function buildRiver(): number
	local cfg = Config.Camp
	local bounds = Zones.getCampBounds()
	local z = bounds.MinZ + cfg.RiverGap + cfg.RiverWidth / 2
	local river = Blocky.part(
		"River",
		Vector3.new(bounds.MaxX - bounds.MinX, RIVER_TOP, cfg.RiverWidth),
		CFrame.new((bounds.MinX + bounds.MaxX) / 2, RIVER_TOP / 2, z),
		cfg.RiverColor,
		Enum.Material.SmoothPlastic,
		folder
	)
	river.Transparency = 0.15
	river.Reflectance = 0.1
	river.CanCollide = false
	river.CanQuery = false -- so raycasts looking for the ground go through it
	return z
end

-- A wooden bridge over the river where the path crosses it (at X = 0), with a ramp at each end.
local function buildBridge(riverZ: number)
	local cfg = Config.Camp
	local style = Config.Style
	local width = cfg.BridgeWidth
	local length = cfg.RiverWidth + 4
	local model = Instance.new("Model")
	model.Name = "Bridge"

	local deckThickness = 0.8
	Blocky.part(
		"Deck",
		Vector3.new(width, deckThickness, length),
		CFrame.new(0, BRIDGE_TOP - deckThickness / 2, riverZ),
		style.Wood,
		Enum.Material.WoodPlanks,
		model
	)
	-- Ramps up onto the deck from both banks. A wedge's slope faces its front (-Z),
	-- so the near ramp is turned around to face spawn.
	for _, side in { 1, -1 } do
		local z = riverZ + side * (length / 2 + RAMP_LENGTH / 2)
		local turn = if side == 1 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
		Blocky.wedge(
			"Ramp",
			Vector3.new(width, BRIDGE_TOP, RAMP_LENGTH),
			CFrame.new(0, BRIDGE_TOP / 2, z) * turn,
			style.Wood,
			Enum.Material.WoodPlanks,
			model
		)
	end
	-- Rails along both sides, on posts.
	for _, side in { -1, 1 } do
		local x = side * (width / 2 - 0.3)
		Blocky.part(
			"Rail",
			Vector3.new(0.6, 0.6, length),
			CFrame.new(x, BRIDGE_TOP + RAIL_HEIGHT, riverZ),
			style.DarkWood,
			Enum.Material.Wood,
			model
		)
		for _, offset in { -1, 0, 1 } do
			Blocky.part(
				"Post",
				Vector3.new(0.8, RAIL_HEIGHT, 0.8),
				CFrame.new(x, BRIDGE_TOP + RAIL_HEIGHT / 2, riverZ + offset * (length / 2 - 0.4)),
				style.DarkWood,
				Enum.Material.Wood,
				model
			)
		end
	end
	model.Parent = folder
end

-- The dirt path: one flat slab per piece of Config.Path. Each slab is a bit longer than its
-- piece, so the corners overlap and there are no gaps. Every other slab sits a hair higher,
-- so the overlapping parts don't flicker.
local function buildPath()
	local cfg = Config.Path
	local points = cfg.Points
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local y = FLOOR_TOP + PATH_THICKNESS / 2 + (index % 2) * 0.02
		local from = Vector3.new(a.X, y, a.Y)
		local to = Vector3.new(b.X, y, b.Y)
		local slab = Blocky.part(
			"Path",
			Vector3.new(cfg.Width, PATH_THICKNESS, (to - from).Magnitude + cfg.Width),
			CFrame.lookAt((from + to) / 2, to),
			cfg.Color,
			Enum.Material.Ground,
			folder
		)
		slab.CanQuery = false -- so trees, buildings and logs find the grass under it
	end
end

-- Players appear in the camp. The place has a SpawnLocation already; move it there
-- (or make one if it's missing).
local function placeSpawn()
	local spawnLocation: SpawnLocation? = nil
	for _, child in workspace:GetDescendants() do
		if child:IsA("SpawnLocation") then
			spawnLocation = child
			break
		end
	end
	if not spawnLocation then
		local newSpawn = Instance.new("SpawnLocation")
		newSpawn.Size = Vector3.new(8, 1, 8)
		newSpawn.Anchored = true
		newSpawn.Neutral = true
		newSpawn.Parent = workspace
		spawnLocation = newSpawn
	end
	if spawnLocation then
		local position = Config.Camp.Spawn
		spawnLocation.CFrame = CFrame.new(position.X, FLOOR_TOP + spawnLocation.Size.Y / 2, position.Z)
	end
end

function CampManager.init()
	folder = Instance.new("Folder")
	folder.Name = "Camp"
	buildFloor()
	buildPath()
	buildBridge(buildRiver())
	folder.Parent = workspace
	placeSpawn()
end

function CampManager.start() end

return CampManager
