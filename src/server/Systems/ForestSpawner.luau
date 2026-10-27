--!strict
-- Spawns placeholder trees (a trunk with a ball of leaves on top) in every zone.
-- Each tree is a Model tagged "Tree" with these attributes:
--   HP, MaxHP     how much chopping it takes
--   ZoneId        which zone it's in (1, 2, 3...)
--   LogValue      coins for each of its logs
--   TrunkWidth    its full trunk width (TreeManager shrinks the trunk as HP goes down)
--   Cursed        true for the rare purple trees with extra valuable logs

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Types = require(ReplicatedStorage.Shared.Types)
local Zones = require(ReplicatedStorage.Shared.Zones)
local ZoneManager = require(script.Parent.ZoneManager)

local MAX_ATTEMPTS_PER_TREE = 50

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

local function pickFrom(colors: { Color3 }): Color3
	return colors[random:NextInteger(1, #colors)]
end

local function createTree(basePosition: Vector3, treeType: Types.TreeTypeConfig, cursed: boolean): Model
	local cfg = Config.Tree
	local trunkHeight = cfg.TrunkHeight * treeType.Scale
	local trunkWidth = cfg.TrunkWidth * treeType.Scale
	local leavesSize = cfg.LeavesSize * treeType.Scale

	local model = Instance.new("Model")
	model.Name = if cursed then "CursedTree" else "Tree"

	-- A cylinder's length runs along its X axis, so we turn it 90 degrees to stand it up.
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(trunkHeight, trunkWidth, trunkWidth)
	trunk.CFrame = CFrame.new(basePosition + Vector3.new(0, trunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Color = pickFrom(treeType.TrunkColors)
	trunk.Material = Enum.Material.Wood
	trunk.Anchored = true
	trunk.Parent = model

	local leaves = Instance.new("Part")
	leaves.Name = "Leaves"
	leaves.Shape = Enum.PartType.Ball
	leaves.Size = Vector3.new(leavesSize, leavesSize, leavesSize)
	leaves.Position = basePosition + Vector3.new(0, trunkHeight, 0)
	leaves.Color = pickFrom(treeType.LeafColors)
	leaves.Material = Enum.Material.Grass
	leaves.Anchored = true
	leaves.Parent = model

	-- Cursed trees glow purple so players can spot them from far away.
	if cursed then
		leaves.Color = Config.Cursed.Color
		leaves.Material = Enum.Material.Neon
		local glow = Instance.new("PointLight")
		glow.Color = Config.Cursed.Color
		glow.Range = leavesSize * 1.5
		glow.Brightness = 2
		glow.Parent = leaves
	end

	-- The pivot is the bottom of the trunk, so the tree falls over from its base.
	-- (No PrimaryPart on purpose: with a PrimaryPart, Roblox ignores WorldPivot
	-- and uses the middle of the trunk instead.)
	model.WorldPivot = CFrame.new(basePosition)

	model:SetAttribute("MaxHP", treeType.MaxHP)
	model:SetAttribute("HP", treeType.MaxHP)
	model:SetAttribute("TrunkWidth", trunkWidth)
	model:SetAttribute("LogValue", treeType.LogValue * (if cursed then Config.Cursed.LogMultiplier else 1))
	if cursed then
		model:SetAttribute("Cursed", true)
	end
	return model
end

-- Pick random spots inside the zone: away from the walls, the zone's sawmill and each other.
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
			tree:SetAttribute("ZoneId", index)
			tree.Parent = treesFolder
			CollectionService:AddTag(tree, Tags.Tree)
			ZoneManager.addTree(index)
		end
	end
end

function ForestSpawner.start() end

return ForestSpawner
