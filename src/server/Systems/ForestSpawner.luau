--!strict
-- Spawns blocky placeholder trees (see Build/Blocky.tree) in every zone.
-- Each tree is a Model tagged "Tree" with these attributes:
--   HP, MaxHP     how much chopping it takes
--   ZoneId        which zone it's in (1, 2, 3...)
--   LogValue      coins for each of its logs
--   TrunkWidth    its full trunk width (TreeManager shrinks the trunk as HP goes down)
--   Cursed        true for the rare purple trees with extra valuable logs
-- Some trees also get a small knot on the trunk (see addKnot).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boss = require(ReplicatedStorage.Shared.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Types = require(ReplicatedStorage.Shared.Types)
local Zones = require(ReplicatedStorage.Shared.Zones)
local ZoneManager = require(script.Parent.ZoneManager)
local Blocky = require(script.Parent.Parent.Build.Blocky)

local MAX_ATTEMPTS_PER_TREE = 50
local KNOT_COLOR = Color3.fromRGB(60, 40, 28)

local ForestSpawner = {}

local treesFolder: Folder
local random = Random.new()

-- Find the ground height at (x, z) by casting a ray straight down.
local function groundHeightAt(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { treesFolder }
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return if result then result.Position.Y else 0
end

local function createTree(basePosition: Vector3, treeType: Types.TreeTypeConfig, cursed: boolean): Model
	local model = Blocky.tree(basePosition, treeType, random)
	model.Name = if cursed then "CursedTree" else "Tree"
	local trunk = model:FindFirstChild("Trunk") :: BasePart

	-- Cursed trees glow purple so players can spot them from far away.
	if cursed then
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and (part.Name == "Leaves" or part.Name == "LeafBlock") then
				part.Color = Config.Cursed.Color
				part.Material = Enum.Material.Neon
			end
		end
		local leaves = model:FindFirstChild("Leaves")
		if leaves then
			local glow = Instance.new("PointLight")
			glow.Color = Config.Cursed.Color
			glow.Range = Config.Tree.LeavesSize * treeType.Scale * 1.5
			glow.Brightness = 2
			glow.Parent = leaves
		end
	end

	model:SetAttribute("MaxHP", treeType.MaxHP)
	model:SetAttribute("HP", treeType.MaxHP)
	model:SetAttribute("TrunkWidth", trunk.Size.X) -- birches are thinner than other trees
	model:SetAttribute("LogValue", treeType.LogValue * (if cursed then Config.Cursed.LogMultiplier else 1))
	if cursed then
		model:SetAttribute("Cursed", true)
	end
	return model
end

-- Put a small dark knot on the side of the trunk (or return the one it already has).
-- MimicManager uses this for mimics whose knot "blinks". Plenty of normal trees get
-- a plain knot too, so having a knot doesn't give a mimic away.
function ForestSpawner.addKnot(tree: Model): BasePart?
	local existing = tree:FindFirstChild("Knot")
	if existing and existing:IsA("BasePart") then
		return existing
	end
	local trunk = tree:FindFirstChild("Trunk")
	if not (trunk and trunk:IsA("BasePart")) then
		return nil
	end

	-- The trunk is a square block that isn't turned: Size.Y is its height, Size.X its width.
	local height = trunk.Size.Y
	local width = trunk.Size.X
	local sides = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }
	local outward = sides[random:NextInteger(1, #sides)]

	local knot = Instance.new("Part")
	knot.Name = "Knot"
	knot.Size = Vector3.one * (width * 0.35)
	knot.Position = tree:GetPivot().Position + Vector3.new(0, height * 0.45, 0) + outward * (width * 0.45)
	knot.Color = KNOT_COLOR
	knot.Material = Enum.Material.Wood
	knot.Anchored = true
	knot.CanCollide = false
	knot.Parent = tree
	return knot
end

-- Pick random spots inside the zone: away from the walls, the zone's sawmill, the path, the
-- boss's clearing, the landmarks and each other.
local function pickPositions(index: number): { Vector2 }
	local zone = Config.Zones[index]
	local bounds = Zones.getBounds(index)
	local margin = Config.Forest.EdgeMargin
	local sawmill = Vector2.new(zone.Sawmill.X, zone.Sawmill.Z)
	local positions: { Vector2 } = {}

	for _ = 1, zone.TreeCount do
		for _ = 1, MAX_ATTEMPTS_PER_TREE do
			local candidate = Vector2.new(
				random:NextNumber(bounds.MinX + margin, bounds.MaxX - margin),
				random:NextNumber(bounds.MinZ + margin, bounds.MaxZ - margin)
			)
			local ok = (candidate - sawmill).Magnitude >= zone.ClearRadius
				and Zones.distanceToPath(candidate.X, candidate.Y) >= Config.Path.TreeClearance
				and not Boss.isInClearing(Vector3.new(candidate.X, 0, candidate.Y))
				and not Zones.isNearLandmark(candidate.X, candidate.Y)
			if ok then
				for _, other in positions do
					if (other - candidate).Magnitude < Config.Forest.MinSpacing then
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

	for index, zone in Config.Zones do
		local treeType = Config.TreeTypes[zone.TreeType]
		for _, spot in pickPositions(index) do
			local base = Vector3.new(spot.X, groundHeightAt(spot.X, spot.Y), spot.Y)
			local cursed = random:NextNumber() < Config.Cursed.Chance
			local tree = createTree(base, treeType, cursed)
			if random:NextNumber() < Config.Mimics.DecoyKnotChance then
				ForestSpawner.addKnot(tree)
			end
			tree:SetAttribute("ZoneId", index)
			tree.Parent = treesFolder
			CollectionService:AddTag(tree, Tags.Tree)
			ZoneManager.addTree(index)
		end
	end
end

function ForestSpawner.start() end

return ForestSpawner
