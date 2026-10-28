--!strict
-- Builds the things around spawn in the camp (see the map design and Config.Camp):
-- stone tiles under spawn, a campfire with logs to sit on, a quest board, a well with a
-- bucket, benches along the path, flower beds and a signpost before the bridge.
-- Everything is only for looks. CampManager calls CampProps.build.
-- It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Blocky = require(script.Parent.Blocky)
local Props = require(script.Parent.Props)

local GROUND = 0.05 -- the top of the camp's grass (see CampManager)
local TILE_GAP = 0.25
local TILE_THICKNESS = 0.3 -- the tiles sit just above the dirt path

local STONE = Color3.fromRGB(143, 150, 163)
local WATER_COLOR = Color3.fromRGB(70, 140, 205)
local SOIL = Color3.fromRGB(100, 70, 45)
local STEM = Color3.fromRGB(60, 140, 50)
local PAPER = Color3.fromRGB(236, 233, 222)
local PIN = Color3.fromRGB(216, 70, 60)
local FLOWERS = { Color3.fromRGB(216, 90, 70), Color3.fromRGB(232, 141, 184), Color3.fromRGB(255, 215, 70), Color3.fromRGB(150, 120, 230) }

local CampProps = {}

local folder: Instance

-- A part at `cframe` that players bump into.
local function piece(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return Blocky.part(name, size, cframe, color, material, folder)
end

-- Like piece(), but players walk through it.
local function decor(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = piece(name, size, cframe, color, material)
	part.CanCollide = false
	return part
end

-- Facing from `position` towards `target` on flat ground (the part's front, -Z, points at it).
local function facing(position: Vector3, target: Vector3): CFrame
	return CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z))
end

-- A square of stone tiles around spawn, a little uneven in colour.
local function buildPlaza()
	local cfg = Config.Camp
	local tiles = 4
	local tileSize = cfg.PlazaSize / tiles
	local random = Random.new(7) -- always the same pattern
	for row = 1, tiles do
		for column = 1, tiles do
			local x = cfg.Spawn.X - cfg.PlazaSize / 2 + (column - 0.5) * tileSize
			local z = cfg.Spawn.Z - cfg.PlazaSize / 2 + (row - 0.5) * tileSize
			local tile = piece(
				"Tile",
				Vector3.new(tileSize - TILE_GAP, TILE_THICKNESS, tileSize - TILE_GAP),
				CFrame.new(x, GROUND + 0.2 + TILE_THICKNESS / 2, z),
				Blocky.shade(STONE, random:NextNumber(-0.08, 0.08)),
				Enum.Material.Slate
			)
			tile.CanQuery = false -- so raycasts looking for the ground find the grass under it
		end
	end
end

-- A notice board facing the path, with a little roof and papers pinned on it.
local function buildQuestBoard()
	local style = Config.Style
	local position = Config.Camp.QuestBoard + Vector3.new(0, GROUND, 0)
	local base = facing(position, Vector3.new(Config.Camp.Spawn.X, 0, position.Z))
	for _, side in { -1, 1 } do
		piece("BoardPost", Vector3.new(0.8, 8.8, 0.8), base * CFrame.new(side * 3.6, 4.4, 0), style.DarkWood, Enum.Material.Wood)
	end
	decor("Board", Vector3.new(7.6, 4.4, 0.4), base * CFrame.new(0, 4.6, 0), style.Wood, Enum.Material.WoodPlanks)
	decor("BoardFrame", Vector3.new(8, 0.4, 0.6), base * CFrame.new(0, 6.9, 0), style.DarkWood, Enum.Material.Wood)
	decor("BoardFrame", Vector3.new(8, 0.4, 0.6), base * CFrame.new(0, 2.3, 0), style.DarkWood, Enum.Material.Wood)
	local roof = decor("BoardRoof", Vector3.new(9, 0.4, 2.4), base * CFrame.new(0, 9, 0), style.Roof, Enum.Material.WoodPlanks)
	roof.CFrame *= CFrame.Angles(math.rad(-15), 0, 0) -- sloping down towards the front
	Blocky.sign("QUESTS", base * CFrame.new(0, 7.8, -0.1), 4.4, 1.4, style.Gold, folder)

	-- Papers pinned at slightly different angles.
	local random = Random.new(3)
	for index = 1, 6 do
		local column = (index - 1) % 3
		local row = (index - 1) // 3
		local paper = decor(
			"Note",
			Vector3.new(1.6, 1.6, 0.05),
			base * CFrame.new(-2.4 + column * 2.4, 5.7 - row * 2.1, -0.25) * CFrame.Angles(0, 0, math.rad(random:NextNumber(-8, 8))),
			PAPER,
			Enum.Material.SmoothPlastic
		)
		decor("Pin", Vector3.new(0.25, 0.25, 0.15), paper.CFrame * CFrame.new(0, 0.55, -0.08), PIN, Enum.Material.SmoothPlastic)
	end
end

-- A stone well with water inside, a little roof, a crank and a bucket on a rope.
local function buildWell()
	local style = Config.Style
	local center = Config.Camp.Well + Vector3.new(0, GROUND, 0)
	local size, thick, height = 5, 0.8, 2.6
	for _, side in { -1, 1 } do
		piece("WellWall", Vector3.new(size, height, thick), CFrame.new(center + Vector3.new(0, height / 2, side * (size - thick) / 2)), STONE, Enum.Material.Slate)
		piece("WellWall", Vector3.new(thick, height, size - thick * 2), CFrame.new(center + Vector3.new(side * (size - thick) / 2, height / 2, 0)), STONE, Enum.Material.Slate)
		piece("WellPost", Vector3.new(0.6, 5.6, 0.6), CFrame.new(center + Vector3.new(side * (size / 2 - 0.3), 2.8, 0)), style.DarkWood, Enum.Material.Wood)
	end
	decor("WellWater", Vector3.new(size - thick * 2, 0.2, size - thick * 2), CFrame.new(center + Vector3.new(0, height - 0.6, 0)), WATER_COLOR, Enum.Material.SmoothPlastic)
	Blocky.roof(center + Vector3.new(0, 5.6, 0), size - 1, 3, 1.8, style.Roof, folder)

	local axle = decor("Crank", Vector3.new(size + 0.6, 0.4, 0.4), CFrame.new(center + Vector3.new(0, 4.6, 0)), style.DarkWood, Enum.Material.Wood)
	axle.Shape = Enum.PartType.Cylinder
	decor("CrankHandle", Vector3.new(0.3, 1.2, 0.3), CFrame.new(center + Vector3.new(size / 2 + 0.4, 4.1, 0)), style.DarkWood, Enum.Material.Wood)
	decor("Rope", Vector3.new(0.12, 1.2, 0.12), CFrame.new(center + Vector3.new(0, 3.9, 0)), Color3.fromRGB(205, 175, 120), Enum.Material.Fabric)
	decor("Bucket", Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 2.9, 0)), Blocky.shade(style.Wood, -0.1), Enum.Material.WoodPlanks)
	decor("BucketBand", Vector3.new(1.06, 0.15, 1.06), CFrame.new(center + Vector3.new(0, 3.1, 0)), Config.Style.Metal, Enum.Material.Metal)
end

-- A wooden bench facing the path.
local function buildBench(position: Vector3)
	local style = Config.Style
	local spot = position + Vector3.new(0, GROUND, 0)
	local base = facing(spot, Vector3.new(Config.Camp.Spawn.X, 0, spot.Z))
	piece("BenchSeat", Vector3.new(5, 0.4, 1.6), base * CFrame.new(0, 1.6, 0), style.Wood, Enum.Material.WoodPlanks)
	decor("BenchBack", Vector3.new(5, 1.2, 0.3), base * CFrame.new(0, 2.9, 0.75), style.Wood, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		decor("BenchLeg", Vector3.new(0.4, 1.4, 1.4), base * CFrame.new(side * 2, 0.7, 0), style.DarkWood, Enum.Material.Wood)
		decor("BenchArm", Vector3.new(0.3, 2.2, 0.3), base * CFrame.new(side * 2, 2.5, 0.75), style.DarkWood, Enum.Material.Wood)
	end
end

-- A wooden box of soil with flowers growing in it.
local function buildFlowerBed(position: Vector3, index: number)
	local spot = position + Vector3.new(0, GROUND, 0)
	decor("BedFrame", Vector3.new(6, 0.6, 3.6), CFrame.new(spot + Vector3.new(0, 0.3, 0)), Config.Style.Wood, Enum.Material.WoodPlanks)
	decor("Soil", Vector3.new(5.4, 0.62, 3), CFrame.new(spot + Vector3.new(0, 0.32, 0)), SOIL, Enum.Material.Ground)
	for row = 0, 1 do
		for column = 0, 3 do
			local flower = spot + Vector3.new(-1.8 + column * 1.2, 0, -0.6 + row * 1.2)
			decor("Stem", Vector3.new(0.2, 0.9, 0.2), CFrame.new(flower + Vector3.new(0, 1, 0)), STEM, Enum.Material.SmoothPlastic)
			decor(
				"Bloom",
				Vector3.new(0.6, 0.6, 0.6),
				CFrame.new(flower + Vector3.new(0, 1.6, 0)),
				FLOWERS[(index + row * 4 + column) % #FLOWERS + 1],
				Enum.Material.SmoothPlastic
			)
		end
	end
end

-- A post with a board pointing to each place: the forest, the Tool Shed and the sawmill.
local function buildSignpost()
	local style = Config.Style
	local position = Config.Camp.Signpost + Vector3.new(0, GROUND, 0)
	piece("SignPost", Vector3.new(0.6, 7.4, 0.6), CFrame.new(position + Vector3.new(0, 3.7, 0)), style.DarkWood, Enum.Material.Wood)
	local riverPoint = Vector3.new(position.X, 0, position.Z - 1) -- straight on, over the bridge
	local places = {
		{ Text = Config.Zones[1].Name, Target = riverPoint, Height = 6.4 },
		{ Text = "Tool Shed", Target = Config.Shop.Position, Height = 5.1 },
		{ Text = "Sawmill", Target = Config.Zones[1].Sawmill, Height = 3.8 },
	}
	for _, place in places do
		local flat = Vector3.new(place.Target.X - position.X, 0, place.Target.Z - position.Z).Unit
		local middle = position + Vector3.new(0, place.Height, 0) + flat * 3.1
		-- The board's long side (X) points at the place.
		local frame = CFrame.fromMatrix(middle, flat, Vector3.yAxis)
		Blocky.sign(place.Text, frame, 5.4, 1.1, nil, folder)
		-- A pointed tip on the end, so it looks like an arrow.
		decor("SignTip", Vector3.new(0.78, 0.78, 0.4), frame * CFrame.new(2.7, 0, 0) * CFrame.Angles(0, 0, math.pi / 4), style.Wood, Enum.Material.WoodPlanks)
	end
end

-- Builds everything into `parent` (the camp's folder).
function CampProps.build(parent: Instance)
	folder = parent
	buildPlaza()
	Props.campfire(folder, Config.Camp.Campfire, true)
	buildQuestBoard()
	buildWell()
	for _, bench in Config.Camp.Benches do
		buildBench(bench)
	end
	for index, bed in Config.Camp.FlowerBeds do
		buildFlowerBed(bed, index)
	end
	buildSignpost()
end

return CampProps
