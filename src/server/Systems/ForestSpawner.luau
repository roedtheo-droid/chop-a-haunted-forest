--!strict
-- Spawns placeholder trees (a brown trunk with a green ball on top) around the map.
-- Each tree is a Model tagged "Tree" with HP and MaxHP attributes.
-- Later phases will replace this with hand-placed zones and real art.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local TRUNK_COLOR = Color3.fromRGB(105, 70, 45)
local LEAVES_COLOR = Color3.fromRGB(60, 120, 55)
local MAX_ATTEMPTS_PER_TREE = 50

local ForestSpawner = {}

local treesFolder: Folder

-- Find the ground height at (x, z) by casting a ray straight down.
local function groundHeightAt(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { treesFolder }
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return if result then result.Position.Y else 0
end

local function createTree(basePosition: Vector3): Model
	local cfg = Config.Tree

	local model = Instance.new("Model")
	model.Name = "Tree"

	-- A cylinder's length runs along its X axis, so we turn it 90 degrees to stand it up.
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(cfg.TrunkHeight, cfg.TrunkWidth, cfg.TrunkWidth)
	trunk.CFrame = CFrame.new(basePosition + Vector3.new(0, cfg.TrunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Color = TRUNK_COLOR
	trunk.Material = Enum.Material.Wood
	trunk.Anchored = true
	trunk.Parent = model

	local leaves = Instance.new("Part")
	leaves.Name = "Leaves"
	leaves.Shape = Enum.PartType.Ball
	leaves.Size = Vector3.new(cfg.LeavesSize, cfg.LeavesSize, cfg.LeavesSize)
	leaves.Position = basePosition + Vector3.new(0, cfg.TrunkHeight, 0)
	leaves.Color = LEAVES_COLOR
	leaves.Material = Enum.Material.Grass
	leaves.Anchored = true
	leaves.Parent = model

	model.PrimaryPart = trunk
	-- The pivot is the bottom of the trunk, so the tree falls over from its base.
	model.WorldPivot = CFrame.new(basePosition)

	model:SetAttribute("MaxHP", cfg.MaxHP)
	model:SetAttribute("HP", cfg.MaxHP)
	return model
end

-- Pick random spots that are not too close to the center or to each other.
local function pickPositions(): { Vector2 }
	local cfg = Config.Forest
	local random = Random.new()
	local half = cfg.AreaSize / 2
	local positions: { Vector2 } = {}

	for _ = 1, cfg.TreeCount do
		for _ = 1, MAX_ATTEMPTS_PER_TREE do
			local candidate = Vector2.new(random:NextNumber(-half, half), random:NextNumber(-half, half))
			local ok = candidate.Magnitude >= cfg.ClearRadius
			if ok then
				for _, other in positions do
					if (other - candidate).Magnitude < cfg.MinSpacing then
						ok = false
						break
					end
				end
			end
			if ok then
				table.insert(positions, candidate)
				break
			end
		end
	end

	return positions
end

function ForestSpawner.init()
	treesFolder = Instance.new("Folder")
	treesFolder.Name = "Trees"
	treesFolder.Parent = workspace

	for _, spot in pickPositions() do
		local base = Vector3.new(spot.X, groundHeightAt(spot.X, spot.Y), spot.Y)
		local tree = createTree(base)
		tree.Parent = treesFolder
		CollectionService:AddTag(tree, Tags.Tree)
	end
end

function ForestSpawner.start() end

return ForestSpawner
