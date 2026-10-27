--!strict
-- Scenery around the forest, only for looks (see STYLE_GUIDE.md):
--   * big blocky trees just outside the walls, so the edge of the forest looks like more forest
--   * grey mountains with snowy tops far away on every side
--   * green grass on the baseplate around everything
-- None of it is tagged as a tree, so it can't be chopped and doesn't count for "% cleared".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Blocky = require(script.Parent.Parent.Build.Blocky)

local SceneryManager = {}

-- The same random numbers every time, so the mountains are always in the same places.
local random = Random.new(7)
local folder: Folder

-- The forest's outside edges (outside the walls).
local function forestEdges(): (number, number, number)
	local halfWidth = Config.Forest.Width / 2 + Config.Forest.WallThickness
	local nearZ = Zones.getBounds(1).MaxZ + Config.Forest.WallThickness
	local farZ = Zones.getBounds(Zones.count()).MinZ - Config.Forest.WallThickness
	return halfWidth, nearZ, farZ
end

-- One big tree at (x, z), looking like the trees of the zone it stands next to.
local function addBorderTree(x: number, z: number)
	local zoneIndex = Zones.indexAt(Vector3.new(0, 0, z)) or (if z > 0 then 1 else Zones.count())
	local treeType = Config.TreeTypes[Config.Zones[zoneIndex].TreeType]
	local tree = Blocky.tree(Vector3.new(x, 0, z), treeType, random, Config.Scenery.BorderTreeScale)
	tree.Name = "BorderTree"
	for _, part in tree:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	tree.Parent = folder
end

local function addBorderTrees()
	local cfg = Config.Scenery
	local halfWidth, nearZ, farZ = forestEdges()
	local distance = cfg.BorderTreeDistance
	local spacing = cfg.BorderTreeSpacing

	-- Along the left and right walls.
	local z = nearZ
	while z > farZ do
		for _, side in { -1, 1 } do
			local x = side * (halfWidth + distance + random:NextNumber(0, spacing / 2))
			addBorderTree(x, z + random:NextNumber(-spacing / 3, spacing / 3))
		end
		z -= spacing
	end
	-- Behind spawn and past the far wall.
	local x = -halfWidth
	while x < halfWidth do
		addBorderTree(x, nearZ + distance + random:NextNumber(0, spacing / 2))
		addBorderTree(x, farZ - distance - random:NextNumber(0, spacing / 2))
		x += spacing
	end
end

-- A mountain is a big block turned 45 degrees, so only its top half (a triangle) sticks
-- out of the ground. A smaller white block on the very top makes the snow.
local function addMountain(position: Vector3)
	local cfg = Config.Scenery
	local size = random:NextNumber(cfg.MountainMinSize, cfg.MountainMaxSize)
	local depth = size * random:NextNumber(0.6, 1)
	local turn = CFrame.new(position)
		* CFrame.Angles(0, random:NextNumber(-0.4, 0.4), 0)
		* CFrame.Angles(0, 0, math.rad(45))
	local mountain =
		Blocky.part("Mountain", Vector3.new(size, size, depth), turn, cfg.MountainColor, Enum.Material.Slate, folder)
	mountain.CanCollide = false

	-- The top corner of the turned block is size * 0.707 above its middle. The snow block has
	-- the same corner, nudged up a little so its sides don't flicker against the mountain's.
	local snowSize = size * cfg.SnowCap
	local rise = (size - snowSize) * math.sqrt(0.5) + 0.6
	local snow = Blocky.part(
		"Snow",
		Vector3.new(snowSize, snowSize, depth + 0.4),
		turn.Rotation + position + Vector3.new(0, rise, 0),
		cfg.SnowColor,
		Enum.Material.Snow,
		folder
	)
	snow.CanCollide = false
end

local function addMountains()
	local cfg = Config.Scenery
	local halfWidth, nearZ, farZ = forestEdges()
	local distance = cfg.MountainDistance
	-- Spread the mountains around a big rectangle around the forest.
	local minX, maxX = -halfWidth - distance, halfWidth + distance
	local minZ, maxZ = farZ - distance, nearZ + distance
	local width, length = maxX - minX, maxZ - minZ
	local perimeter = (width + length) * 2
	for index = 1, cfg.MountainCount do
		local along = (index - 1 + random:NextNumber(0, 0.6)) / cfg.MountainCount * perimeter
		local push = random:NextNumber(0, 80) -- some mountains stand further back than others
		local position: Vector3
		if along < width then
			position = Vector3.new(minX + along, 0, maxZ + push)
		elseif along < width + length then
			position = Vector3.new(maxX + push, 0, maxZ - (along - width))
		elseif along < width * 2 + length then
			position = Vector3.new(maxX - (along - width - length), 0, minZ - push)
		else
			position = Vector3.new(minX - push, 0, minZ + (along - width * 2 - length))
		end
		addMountain(position)
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
	paintBaseplate()
	addBorderTrees()
	addMountains()
	folder.Parent = workspace
end

function SceneryManager.start() end

return SceneryManager
