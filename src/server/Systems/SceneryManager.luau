--!strict
-- Scenery around the forest, only for looks (see STYLE_GUIDE.md):
--   * rows of big blocky trees just outside the walls, so the edge of the forest looks like
--     more forest (the hedge in front of them is built by Build/Edges)
--   * rolling hills covered in little trees behind them
--   * two rings of mountain ranges with snowy tops far away on every side; the far ring is
--     paler and bluer, so it looks further away
--   * green grass on the baseplate, and big grass tiles under everything further out
-- The hills and mountains are Blender models (Config.Models) once they're imported into
-- Studio; until then the mountains are turned blocks and the hills long grassy ridges.
-- None of it is tagged as a tree, so it can't be chopped and doesn't count for "% cleared".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Assets = require(script.Parent.Parent.Build.Assets)
local Blocky = require(script.Parent.Parent.Build.Blocky)

local TILE = 2048 -- the biggest a part can be
local TILE_TOP = -0.3 -- under the baseplate's top (0), so the two don't flicker where they overlap

local SceneryManager = {}

-- The same random numbers every time, so the mountains are always in the same places.
local random = Random.new(7)
local folder: Folder
-- The hills, mountains and ground tiles. Far from players, so it's sent to every player's
-- computer at the start (Persistent), instead of only when they come close (streaming).
local distant: Model

-- The forest's outside edges (outside the walls).
local function forestEdges(): (number, number, number)
	local halfWidth = Config.Forest.Width / 2 + Config.Forest.WallThickness
	local nearZ = Zones.getCampBounds().MaxZ + Config.Forest.WallThickness
	local farZ = Zones.getBounds(Zones.count()).MinZ - Config.Forest.WallThickness
	return halfWidth, nearZ, farZ
end

-- One big tree at (x, z), looking like the trees of the zone it stands next to.
local function addBorderTree(x: number, z: number)
	local cfg = Config.Scenery
	-- Next to the camp (or behind it) they look like zone 1's trees; past the far wall, like the last zone's.
	local zoneIndex = Zones.indexAt(Vector3.new(0, 0, z)) or (if z > Zones.getBounds(1).MinZ then 1 else Zones.count())
	local treeType = Config.TreeTypes[Config.Zones[zoneIndex].TreeType]
	local scale = random:NextNumber(cfg.BorderTreeScale[1], cfg.BorderTreeScale[2])
	local tree = Blocky.tree(Vector3.new(x, 0, z), treeType, random, scale)
	tree.Name = "BorderTree"
	for _, part in tree:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		elseif part.Name == "Root" then
			part:Destroy() -- nobody sees them behind the hedge, and it saves parts
		else
			part.CanCollide = false
		end
	end
	tree.Parent = folder
end

local function addBorderTrees()
	local cfg = Config.Scenery
	local halfWidth, nearZ, farZ = forestEdges()
	for row = 1, cfg.BorderTreeRows do
		local distance = cfg.BorderTreeDistance + (row - 1) * cfg.BorderTreeRowGap
		local spacing = cfg.BorderTreeSpacing * cfg.BorderTreeRowSpacing ^ (row - 1)
		local start = (row - 1) * spacing / 2 -- each row starts half a gap later, so the trees don't line up

		-- Along the left and right walls (past the corners, so they're filled too).
		local z = nearZ + distance - start
		while z > farZ - distance do
			for _, side in { -1, 1 } do
				local x = side * (halfWidth + distance + random:NextNumber(0, spacing / 2))
				addBorderTree(x, z + random:NextNumber(-spacing / 3, spacing / 3))
			end
			z -= spacing
		end
		-- Behind the camp and past the far wall.
		local x = -halfWidth + start
		while x < halfWidth do
			addBorderTree(x, nearZ + distance + random:NextNumber(0, spacing / 2))
			addBorderTree(x, farZ - distance - random:NextNumber(0, spacing / 2))
			x += spacing
		end
	end
end

-- Only for looks: players walk through it, and raycasts go through it.
local function soft(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
end

local function between(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

-- A spot `distance` studs outside the forest's edges, `along` (0 to 1) of the way around it,
-- plus `push` studs further out. Also returns the angle that turns a model's X axis to run
-- along that side, so a range or a hill lies along the forest, not end-on.
local function aroundForest(distance: number, along: number, push: number): (Vector3, number)
	local halfWidth, nearZ, farZ = forestEdges()
	local minX, maxX = -halfWidth - distance, halfWidth + distance
	local minZ, maxZ = farZ - distance, nearZ + distance
	local width, length = maxX - minX, maxZ - minZ
	local walk = along * (width + length) * 2
	if walk < width then
		return Vector3.new(minX + walk, 0, maxZ + push), 0
	elseif walk < width + length then
		return Vector3.new(maxX + push, 0, maxZ - (walk - width)), math.pi / 2
	elseif walk < width * 2 + length then
		return Vector3.new(maxX - (walk - width - length), 0, minZ - push), 0
	end
	return Vector3.new(minX - push, 0, minZ + (walk - width * 2 - length)), math.pi / 2
end

-- One of the Blender models `names` with its part `reference`, fitted to `width` at `base`,
-- turned `angle` (and maybe flipped round). Not parented. nil if none is imported yet.
local function fitModel(names: { string }, reference: string, width: number, base: Vector3, angle: number): Model?
	local name = Assets.pick(names, random)
	local model = if name then Assets.model(name) else nil
	if not model then
		return nil
	end
	local part = model:FindFirstChild(reference)
	if not (part and part:IsA("BasePart")) then
		warn(`[Scenery] The "{name}" model needs a part named {reference}, so parts are used instead`)
		model:Destroy()
		return nil
	end
	local flip = if random:NextNumber() < 0.5 then 0 else math.pi
	Assets.fit(model, part, width, base, CFrame.Angles(0, angle + flip + random:NextNumber(-0.2, 0.2), 0))
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			soft(child)
		end
	end
	return model
end

-- Without the models: a big block turned 45 degrees, so only its top half (a triangle)
-- sticks out of the ground. A smaller white block on the very top makes the snow.
local function blockMountain(position: Vector3, size: number, color: Color3, snowColor: Color3)
	local cfg = Config.Scenery
	local depth = size * random:NextNumber(0.6, 1)
	local turn = CFrame.new(position)
		* CFrame.Angles(0, random:NextNumber(-0.4, 0.4), 0)
		* CFrame.Angles(0, 0, math.rad(45))
	local mountain = Blocky.part("Mountain", Vector3.new(size, size, depth), turn, color, Enum.Material.Slate, distant)
	soft(mountain)

	-- The top corner of the turned block is size * 0.707 above its middle. The snow block has
	-- the same corner, nudged up a little so its sides don't flicker against the mountain's.
	local snowSize = size * cfg.SnowCap
	local rise = (size - snowSize) * math.sqrt(0.5) + 0.6
	local snow = Blocky.part(
		"Snow",
		Vector3.new(snowSize, snowSize, depth + 0.4),
		turn.Rotation + position + Vector3.new(0, rise, 0),
		snowColor,
		Enum.Material.Snow,
		distant
	)
	soft(snow)
end

-- One ring of mountain ranges, `distance` studs from the forest.
local function addMountainRing(count: number, distance: number, widths: { number }, color: Color3, snowColor: Color3)
	for index = 1, count do
		local along = (index - 1 + random:NextNumber(0, 0.6)) / count
		local position, angle = aroundForest(distance, along, random:NextNumber(0, 80)) -- some stand further back
		local width = between(widths)
		local model = fitModel(Config.Models.Mountains, "Mountain", width, position, angle)
		if model then
			for _, part in model:GetChildren() do
				if not part:IsA("BasePart") then
					continue
				elseif part.Name == "Snow" then
					part.Color = snowColor
					part.Material = Enum.Material.Snow
				else
					part.Color = Blocky.shade(color, random:NextNumber(-0.05, 0.05))
					part.Material = Enum.Material.Slate
				end
			end
			model.Name = "Mountains"
			model.Parent = distant
		else
			blockMountain(position, width * 0.5, color, snowColor)
		end
	end
end

local function addMountains()
	local cfg = Config.Scenery
	addMountainRing(cfg.MountainCount, cfg.MountainDistance, cfg.MountainWidth, cfg.MountainColor, cfg.SnowColor)
	addMountainRing(
		cfg.FarMountainCount,
		cfg.FarMountainDistance,
		cfg.FarMountainWidth,
		cfg.FarMountainColor,
		cfg.FarSnowColor
	)
end

-- Rolling hills with little trees, all the way around, just behind the border trees.
local function addHills()
	local cfg = Config.Scenery
	for index = 1, cfg.HillCount do
		local along = (index - 1 + random:NextNumber(0, 0.5)) / cfg.HillCount
		local position, angle = aroundForest(between(cfg.HillDistance), along, 0)
		local width = between(cfg.HillWidth)
		local model = fitModel(Config.Models.Hills, "Hill", width, position - Vector3.new(0, cfg.HillSink, 0), angle)
		if model then
			for _, part in model:GetChildren() do
				if not part:IsA("BasePart") then
					continue
				elseif part.Name == "Grove" then
					part.Color = Blocky.shade(cfg.FarTreeColor, random:NextNumber(-0.06, 0.06))
					part.Material = Config.Tree.LeafMaterial
				else
					part.Color = Blocky.shade(cfg.HillColor, random:NextNumber(-0.06, 0.04))
					part.Material = Enum.Material.Grass
				end
			end
			model.Name = "Hill"
			model.Parent = distant
		else
			-- Without the model: a long block turned 45 degrees and mostly sunk, so a low grassy
			-- ridge sticks out of the ground.
			local thick = width * 0.22
			local ridge = Blocky.part(
				"Hill",
				Vector3.new(width, thick, thick),
				CFrame.new(position) * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(45), 0, 0),
				Blocky.shade(cfg.HillColor, random:NextNumber(-0.06, 0.04)),
				Enum.Material.Grass,
				distant
			)
			soft(ridge)
		end
	end
end

-- Big grass tiles under everything, centred on the forest, so there's ground all the way
-- out to the far mountains (a baseplate is only 2048 studs wide).
local function addOutsideGround()
	local count = Config.Scenery.OutsideTiles
	local _, nearZ, farZ = forestEdges()
	local middleZ = (nearZ + farZ) / 2
	for column = 1, count do
		for row = 1, count do
			local x = (column - (count + 1) / 2) * TILE
			local z = middleZ + (row - (count + 1) / 2) * TILE
			Blocky.part(
				"OutsideGround",
				Vector3.new(TILE, 1, TILE),
				CFrame.new(x, TILE_TOP - 0.5, z),
				Config.Scenery.OutsideGround,
				Enum.Material.Grass,
				distant
			)
		end
	end
end

-- Paint the place's baseplate (if it has one) like grass, without its grid texture.
local function paintBaseplate()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if not (baseplate and baseplate:IsA("BasePart")) then
		return
	end
	baseplate.Color = Config.Scenery.OutsideGround
	baseplate.Material = Enum.Material.Grass
	for _, child in baseplate:GetChildren() do
		if child:IsA("Texture") or child:IsA("Decal") then
			child.Transparency = 1
		end
	end
end

function SceneryManager.init()
	folder = Instance.new("Folder")
	folder.Name = "Scenery"
	distant = Instance.new("Model")
	distant.Name = "Distant"
	distant.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	distant.Parent = folder
	paintBaseplate()
	addOutsideGround()
	addBorderTrees()
	addHills()
	addMountains()
	folder.Parent = workspace
end

function SceneryManager.start() end

return SceneryManager
