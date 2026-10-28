--!strict
-- Builds the camp in front of zone 1 (see Config.Camp): its grass, the river with sandy banks
-- and a bridge across its far end, the dirt path (with pebbles along its edges) that bends
-- from spawn through every gate to the boss, and the things around spawn (campfire, quest
-- board, well... see Build/CampProps).
-- It also moves the place's SpawnLocation into the camp. No trees grow in the camp
-- (it isn't a zone), and none grow on the path (see ForestSpawner).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Assets = require(script.Parent.Parent.Build.Assets)
local Blocky = require(script.Parent.Parent.Build.Blocky)
local CampProps = require(script.Parent.Parent.Build.CampProps)
local Props = require(script.Parent.Parent.Build.Props)
local SawmillBuilding = require(script.Parent.Parent.Build.SawmillBuilding)

local FLOOR_THICKNESS = 1
local FLOOR_TOP = 0.05 -- the same height as the zone floors (see ZoneManager)
local PATH_THICKNESS = 0.2
local RIVER_TOP = 0.3 -- a little above the ground: you wade through it
local BRIDGE_TOP = 1.2
local RAMP_LENGTH = 3
local RAIL_HEIGHT = 2.5
local STONE = Color3.fromRGB(143, 150, 163) -- the stones on the river's banks

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

-- Is this X where nothing should go on the river's banks: the bridge, or (on the camp's side)
-- the stream under the sawmill's water wheel? `margin` is extra room on both sides.
local function isBankGap(x: number, nearSide: boolean, margin: number): boolean
	local streamX = SawmillBuilding.streamX(Config.Zones[1].Sawmill.X)
	return math.abs(x) < Config.Camp.BridgeWidth / 2 + 1 + margin or (nearSide and math.abs(x - streamX) < 3 + margin)
end

-- One piece of river bank, `length` long and centred on `x`, along the water's edge at
-- `edgeZ`. `toWater` is the way to the water (-1 or 1, in Z). Uses the Blender "RiverBank"
-- model (sand rising to a low crest, with stones at the water's edge), or a sand strip.
local function addBank(x: number, length: number, edgeZ: number, toWater: number, random: Random)
	local cfg = Config.Camp
	local model = Assets.model(Config.Models.RiverBank)
	local sand = if model then model:FindFirstChild("Sand") else nil
	if model and sand and sand:IsA("BasePart") then
		-- The model's water side is its -Z side (once Assets.TURN_AROUND turns it the right
		-- way), so the bank across the river is turned around.
		-- Its foot reaches a little way into the water, so there's no gap at the edge.
		local depth = sand.Size.Z * length / sand.Size.X
		local middleZ = edgeZ - toWater * (depth / 2 - 0.6)
		local turn = CFrame.Angles(0, (if toWater < 0 then 0 else math.pi) + random:NextNumber(-0.04, 0.04), 0)
		Assets.fit(model, sand, length, Vector3.new(x, FLOOR_TOP, middleZ), turn * Assets.TURN_AROUND)
		model.Name = "RiverBank"
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") then
				if part.Name == "Sand" then
					part.Color = cfg.BankColor
					part.Material = Enum.Material.Sand
				else
					part.Color = Blocky.shade(STONE, random:NextNumber(-0.1, 0.05))
					part.Material = Enum.Material.Slate
				end
				part.CanCollide = false -- you can still wade across
				part.CanQuery = false
			end
		end
		model.Parent = folder
		return
	end
	if model then
		model:Destroy()
	end
	local strip = Blocky.part(
		"RiverBank",
		Vector3.new(length, 0.4, 2.4),
		CFrame.new(x, FLOOR_TOP + 0.2, edgeZ - toWater * 0.8),
		cfg.BankColor,
		Enum.Material.Sand,
		folder
	)
	strip.CanCollide = false
	strip.CanQuery = false
end

-- The river runs across the whole camp, just before zone 1: water over a darker riverbed,
-- sandy banks along both sides, and rocks, reeds and lily pads. Returns its middle (Z).
local function buildRiver(): number
	local cfg = Config.Camp
	local bounds = Zones.getCampBounds()
	local z = Zones.getRiverZ()
	local width = bounds.MaxX - bounds.MinX
	local middleX = (bounds.MinX + bounds.MaxX) / 2
	local random = Random.new(29)

	local bed = Blocky.part(
		"Riverbed",
		Vector3.new(width, 0.1, cfg.RiverWidth),
		CFrame.new(middleX, FLOOR_TOP + 0.05, z),
		cfg.RiverbedColor,
		Enum.Material.Ground,
		folder
	)
	bed.CanCollide = false
	bed.CanQuery = false
	local river = Blocky.part(
		"River",
		Vector3.new(width, RIVER_TOP, cfg.RiverWidth),
		CFrame.new(middleX, RIVER_TOP / 2, z),
		cfg.RiverColor,
		Enum.Material.SmoothPlastic,
		folder
	)
	river.Transparency = cfg.RiverTransparency
	river.Reflectance = 0.1
	river.CanCollide = false
	river.CanQuery = false -- so raycasts looking for the ground go through it

	-- Banks along both sides: the camp's side (the water is towards -Z) and zone 1's side.
	for _, side in { { EdgeZ = z + cfg.RiverWidth / 2, ToWater = -1 }, { EdgeZ = z - cfg.RiverWidth / 2, ToWater = 1 } } do
		local x = bounds.MinX
		while x < bounds.MaxX do
			local length = cfg.BankLength * random:NextNumber(0.85, 1.15)
			local middle = math.min(x + length / 2, bounds.MaxX - length / 2) -- the last one stays inside
			if not isBankGap(middle, side.ToWater < 0, length / 2) then
				addBank(middle, length, side.EdgeZ, side.ToWater, random)
			end
			x += length * 0.95 -- each piece overlaps the next a little
		end
	end

	-- A spot in the river (away from the bridge and the stream), `fromEdge` studs from a bank.
	local function riverSpot(fromEdge: number): Vector3
		for _ = 1, 30 do
			local nearSide = random:NextNumber() < 0.5
			local x = random:NextNumber(bounds.MinX + 6, bounds.MaxX - 6)
			if not isBankGap(x, nearSide, 2) then
				return Vector3.new(x, 0, if nearSide then z + cfg.RiverWidth / 2 - fromEdge else z - cfg.RiverWidth / 2 + fromEdge)
			end
		end
		return Vector3.new(bounds.MinX + 10, 0, z)
	end
	for _ = 1, cfg.RiverRocks do
		Props.rock(folder, riverSpot(random:NextNumber(3, 7)), random:NextNumber(0.9, 1.5), false, random)
	end
	for _ = 1, cfg.RiverReeds do
		Props.reeds(folder, riverSpot(random:NextNumber(0.3, 1.2)), random)
	end
	for index = 1, cfg.RiverLilyPads do
		Props.lilyPad(folder, riverSpot(random:NextNumber(2, 6)), RIVER_TOP, index == 1, random)
	end
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

	-- The Blender bridge, if it's imported and fits this river: it's built over the parts
	-- above, which stay as invisible floors and rails, so walking over it is exactly the same.
	local parts = model:GetChildren()
	local bridge = Assets.prop(model, Config.Models.Camp.Bridge, 1, CFrame.new(0, 0, riverZ))
	local deck = if bridge then Assets.paint(bridge, "Deck", style.Wood, Enum.Material.WoodPlanks, false) else nil
	if bridge and deck then
		local fullLength = length + RAMP_LENGTH * 2
		if math.abs(deck.Size.X - width) > width * 0.05 or math.abs(deck.Size.Z - fullLength) > fullLength * 0.05 then
			warn("[CampManager] The Bridge model doesn't fit this river (Camp.BridgeWidth or RiverWidth changed?): using parts")
			bridge:Destroy()
		else
			Assets.paint(bridge, "Post", style.DarkWood, Enum.Material.Wood, false)
			Assets.paint(bridge, "Stone", STONE, Enum.Material.Slate, false)
			-- Line its deck up with the parts deck (its ramps dip a little below the ground).
			local top = deck.Position.Y + deck.Size.Y / 2
			bridge:PivotTo(bridge:GetPivot() + Vector3.new(0, BRIDGE_TOP - top, 0))
			for _, part in parts do
				if part:IsA("BasePart") then
					Blocky.collider(part)
				end
			end
		end
	elseif bridge then
		bridge:Destroy()
	end
	model.Parent = folder
end

-- The dirt path: one flat slab per piece of the smooth path (Zones.getPathPoints), on top of
-- a wider, darker slab that makes its edge. Each slab is a bit longer than its piece, so the
-- bends overlap and there are no gaps. Every other slab sits a hair higher, so the
-- overlapping parts don't flicker.
local function buildPath()
	local cfg = Config.Path
	local points = Zones.getPathPoints()
	local layers = {
		{ Name = "PathEdge", Width = cfg.Width + cfg.EdgeWidth * 2, Color = cfg.EdgeColor, Lift = -0.04 },
		{ Name = "Path", Width = cfg.Width, Color = cfg.Color, Lift = 0 },
	}
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		for _, layer in layers do
			local y = FLOOR_TOP + PATH_THICKNESS / 2 + (index % 2) * 0.02 + layer.Lift
			local from = Vector3.new(a.X, y, a.Y)
			local to = Vector3.new(b.X, y, b.Y)
			local slab = Blocky.part(
				layer.Name,
				Vector3.new(layer.Width, PATH_THICKNESS, (to - from).Magnitude + layer.Width),
				CFrame.lookAt((from + to) / 2, to),
				layer.Color,
				Enum.Material.Ground,
				folder
			)
			slab.CanQuery = false -- so trees, buildings and logs find the grass under it
		end
	end
end

-- Little groups of pebbles along both edges of the path, on alternating sides. None on the
-- bridge, where the path crosses the river, or on the stone tiles around spawn.
local function addPebbles(riverZ: number)
	local cfg = Config.Path
	local points = Zones.getPathPoints()
	local random = Random.new(19)
	local bridgeReach = Config.Camp.RiverWidth / 2 + 2 + RAMP_LENGTH + 1
	local plazaReach = Config.Camp.PlazaSize / 2 + 1
	local travelled, nextSpot, side = 0, cfg.PebbleSpacing / 2, 1
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local length = (b - a).Magnitude
		if length > 0 then
			local direction = (b - a).Unit
			local normal = Vector2.new(-direction.Y, direction.X)
			while nextSpot <= travelled + length do
				local onPath = a + direction * (nextSpot - travelled)
				local spawn = Config.Camp.Spawn
				local onPlaza = math.abs(onPath.X - spawn.X) < plazaReach and math.abs(onPath.Y - spawn.Z) < plazaReach
				if math.abs(onPath.Y - riverZ) > bridgeReach and not onPlaza then
					local spot = onPath + normal * side * (cfg.Width / 2 + cfg.EdgeWidth + random:NextNumber(0.2, 0.9))
					Props.pebbles(folder, Vector3.new(spot.X, 0, spot.Y), random:NextNumber(1.2, 2.2), random)
				end
				side = -side
				nextSpot += cfg.PebbleSpacing * random:NextNumber(0.7, 1.3)
			end
			travelled += length
		end
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
	local riverZ = buildRiver()
	buildBridge(riverZ)
	addPebbles(riverZ)
	CampProps.build(folder)
	folder.Parent = workspace
	placeSpawn()
end

function CampManager.start() end

return CampManager
