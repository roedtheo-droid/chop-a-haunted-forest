--!strict
-- Builds the look of a sawmill (see the map design): an open-fronted log shed where you can
-- see the big round saw with a log on its table, a conveyor belt running in from the
-- "DROP LOGS" pad, a water wheel turning in a stream on the side, a log pile, a chimney
-- with smoke and a lamp post. The saw and the wheel are tagged Spinner, so every player's
-- computer turns them (see Client/SpinnerController).
-- Zones 2 and 3 get the same sawmill, only darker and more worn (Config.Sawmill.Wear).
-- Only for looks: SawmillManager builds the pad and does the selling.
-- When the Blender models are imported (Config.Models.Buildings), the shed, the saw's table,
-- the saw, the water wheel, the workshop and the log pile are those models, each over its
-- parts version: the parts turn invisible but still do the bumping, the light and the smoke
-- (see Blocky.dress). The lamp post by the pad is Props.lampPost.
-- It's not a system, so it has no init()/start().

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Types = require(ReplicatedStorage.Shared.Types)
local Assets = require(script.Parent.Assets)
local Blocky = require(script.Parent.Blocky)
local Props = require(script.Parent.Props)

local WALL = 1
local FLOOR_TOP = 0.4 -- the same height as the top of the pad
local TABLE_TOP = 3.4
local WATER_TOP = 0.3 -- the same height as the river (see CampManager)
local WHEEL_WIDTH = 2
local WHEEL_PIECES = 10

local STONE = Color3.fromRGB(143, 150, 163)
local DARK_METAL = Color3.fromRGB(70, 70, 78)
local LAMP_COLOR = Color3.fromRGB(255, 215, 120)
local MODELS = Config.Models.Buildings

local SawmillBuilding = {}

-- Set at the start of build(): where the sawmill stands, the whole sawmill, the group the
-- next parts go in (see group()), whether the shed model is used (then the other models
-- are too, because the sawmill is the size they're made for), and its colours (darker in
-- the worn sawmills).
local origin: CFrame
local sawmill: Model
local model: Model
local dressed = false
local wood: Color3
local darkWood: Color3
local roofColor: Color3

local function piece(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return Blocky.part(name, size, origin * cframe, color, material, model)
end

-- Like piece(), but for things you walk through or around without bumping into them.
local function decor(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = piece(name, size, cframe, color, material)
	part.CanCollide = false
	return part
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Start a group for the parts of one thing (the shed, the saw's table...), so its Blender
-- model can go over it. piece() and decor() put their parts in the newest group.
local function group(name: string)
	model = Instance.new("Model")
	model.Name = name
	model.Parent = sawmill
end

-- Put Blender model `name` over `into` (the newest group if not given), with its origin at
-- `frame` from the middle of the sawmill's floor plan. Only once the shed is dressed.
-- Returns the model, or nil (then the parts stay as they are).
local function dress(name: string, frame: CFrame, looks: { [string]: Types.SkinLook }, into: Model?): Model?
	if not dressed then
		return nil
	end
	local parent = into or model
	local skin = Assets.placed(parent, name, origin * frame)
	if skin then
		Blocky.dress(parent, skin, looks)
	end
	return skin
end

-- Make a spinner's model `size` big, measured on its part `name` (its height, Y).
local function resize(skin: Model, name: string, size: number)
	local part = skin:FindFirstChild(name)
	if part and part:IsA("BasePart") and part.Size.Y > 0 then
		skin:ScaleTo(skin:GetScale() * size / part.Size.Y)
	end
end

-- A model that keeps turning around its main part's X axis (a cylinder's axis).
local function makeSpinner(spinner: Model, axis: BasePart, speed: number)
	spinner.PrimaryPart = axis
	spinner.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- see Client/SpinnerController
	spinner:SetAttribute("SpinSpeed", speed)
	CollectionService:AddTag(spinner, Tags.Spinner)
	spinner.Parent = sawmill
end

-- The floor, the three log walls, the open front, the roof, the sign and the chimney.
local function buildShed()
	group("Shed")
	local cfg = Config.Sawmill
	local size = cfg.BuildingSize
	local w, h, d = size.X, size.Y, size.Z
	local logFaces = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

	piece("Floor", Vector3.new(w, FLOOR_TOP, d), at(0, FLOOR_TOP / 2, 0), Blocky.shade(wood, 0.1), Enum.Material.WoodPlanks)
	local walls = {
		piece("BackWall", Vector3.new(w, h, WALL), at(0, h / 2, -d / 2 + WALL / 2), wood, Enum.Material.WoodPlanks),
		piece("LeftWall", Vector3.new(WALL, h, d), at(-w / 2 + WALL / 2, h / 2, 0), wood, Enum.Material.WoodPlanks),
		piece("RightWall", Vector3.new(WALL, h, d), at(w / 2 - WALL / 2, h / 2, 0), wood, Enum.Material.WoodPlanks),
	}
	for _, wall in walls do
		Blocky.logLines(wall, logFaces)
	end

	-- The front is open: two thick posts and a beam across the top.
	for _, side in { -1, 1 } do
		piece("FrontPost", Vector3.new(1.4, h, 1.4), at(side * (w / 2 - 0.7), h / 2, d / 2 - 0.7), darkWood, Enum.Material.Wood)
		decor("Corner", Vector3.new(1.4, h, 1.4), at(side * (w / 2 - 0.7), h / 2, -d / 2 + 0.7), Blocky.shade(wood, 0.25), Enum.Material.Wood)
	end
	piece("FrontBeam", Vector3.new(w, 1.4, 1.4), at(0, h - 0.7, d / 2 - 0.7), darkWood, Enum.Material.Wood)

	Blocky.roof(origin.Position + Vector3.new(0, h, 0), w, d, cfg.RoofHeight, roofColor, model)

	-- A lantern hanging from the front beam.
	decor("LampChain", Vector3.new(0.2, 1.2, 0.2), at(0, h - 2, d / 2 - 0.7), DARK_METAL, Enum.Material.Metal)
	local lamp = decor("Lamp", Vector3.new(0.9, 1.1, 0.9), at(0, h - 3.1, d / 2 - 0.7), LAMP_COLOR, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = LAMP_COLOR
	light.Range = 16
	light.Parent = lamp

	-- A stone chimney at the back, with smoke.
	local chimney = decor("Chimney", Vector3.new(2.4, 8, 2.4), at(-w / 2 + 3, h + 3, -d / 2 + 2.5), STONE, Enum.Material.Slate)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Size = NumberSequence.new(1.5, 4)
	smoke.Lifetime = NumberRange.new(3, 4)
	smoke.Rate = 4
	smoke.Speed = NumberRange.new(3, 4)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = chimney
end

-- Is the shed model made for this size of sawmill (Config.Sawmill)? Checked on its floor and
-- the height of its walls.
local function shedFits(shed: Model): boolean
	local size = Config.Sawmill.BuildingSize
	local floor = shed:FindFirstChild("Floor")
	if not (floor and floor:IsA("BasePart")) then
		return false
	end
	local wallTop = 0
	for _, part in shed:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Wall" then
			wallTop = math.max(wallTop, part.Position.Y + part.Size.Y / 2 - origin.Position.Y)
		end
	end
	return Assets.near(floor.Size.X, size.X) and Assets.near(floor.Size.Z, size.Z) and Assets.near(wallTop, size.Y)
end

-- The SawmillShed model over the shed's parts, if it's imported and fits. Its walls and
-- roof are solid, so the camera can't swing through them.
local function dressShed()
	local shed = Assets.placed(model, MODELS.SawmillShed, origin)
	if not shed then
		return
	end
	if not shedFits(shed) then
		warn("[SawmillBuilding] The sawmill models are made for a 20 x 11 x 14 sawmill (Config.Sawmill changed?): using parts")
		shed:Destroy()
		return
	end
	Blocky.dress(model, shed, {
		Floor = { Color = Blocky.shade(wood, 0.1), Material = Enum.Material.WoodPlanks },
		Wall = { Color = wood, Material = Enum.Material.Wood, Solid = true },
		Gable = { Color = wood, Material = Enum.Material.Wood, Solid = true },
		Roof = { Color = roofColor, Material = Enum.Material.WoodPlanks, Solid = true },
		Post = { Color = darkWood, Material = Enum.Material.Wood },
		Trim = { Color = darkWood, Material = Enum.Material.Wood },
		Corner = { Color = Blocky.shade(wood, 0.25), Material = Enum.Material.Wood },
		Chimney = { Color = STONE, Material = Enum.Material.Slate },
		Lamp = { Color = LAMP_COLOR, Material = Enum.Material.Neon },
		Iron = { Color = DARK_METAL, Material = Enum.Material.Metal },
	})
	dressed = true
end

-- The "SELL LOGS" sign above the open front.
local function buildSign()
	group("Sign")
	local size = Config.Sawmill.BuildingSize
	Blocky.sign("SELL LOGS", origin * at(0, size.Y + 1.9, size.Z / 2 + 1.4), 12, 3, nil, model)
end

-- The big round saw on its table, with a log waiting to be cut and the conveyor belt
-- that brings logs in from the pad.
local function buildSaw()
	local cfg = Config.Sawmill
	local d = cfg.BuildingSize.Z
	local radius = cfg.SawSize / 2
	local tableBack, tableFront = -d / 2 + 2, 2
	local tableLength = tableFront - tableBack
	local tableZ = (tableBack + tableFront) / 2
	group("SawTable")
	piece("SawTable", Vector3.new(3.4, TABLE_TOP - FLOOR_TOP, tableLength), at(0, (TABLE_TOP + FLOOR_TOP) / 2, tableZ), darkWood, Enum.Material.Wood)
	piece("SawTableTop", Vector3.new(3.8, 0.3, tableLength + 0.2), at(0, TABLE_TOP + 0.15, tableZ), Blocky.shade(wood, 0.15), Enum.Material.WoodPlanks)

	-- The saw sticks up through the middle of the table. It turns around X, like a cylinder.
	local sawZ = tableZ - 1
	local saw = Instance.new("Model")
	saw.Name = "Saw"
	local center = at(0, TABLE_TOP + 0.6, sawZ)
	local blade = Blocky.part("Blade", Vector3.new(0.25, cfg.SawSize, cfg.SawSize), origin * center, Config.Style.Metal, Enum.Material.Metal, saw)
	blade.Shape = Enum.PartType.Cylinder
	blade.CanCollide = false
	local hub = Blocky.part("Hub", Vector3.new(0.6, 1.2, 1.2), origin * center, DARK_METAL, Enum.Material.Metal, saw)
	hub.Shape = Enum.PartType.Cylinder
	hub.CanCollide = false
	for index = 1, 12 do
		local tooth = Blocky.part(
			"Tooth",
			Vector3.new(0.25, 0.6, 0.6),
			origin * center * CFrame.Angles(index * math.pi / 6, 0, 0) * CFrame.new(0, radius, 0) * CFrame.Angles(math.pi / 4, 0, 0),
			Blocky.shade(Config.Style.Metal, 0.2),
			Enum.Material.Metal,
			saw
		)
		tooth.CanCollide = false
	end
	local sawSkin = dress(MODELS.SawBlade, center, {
		Blade = { Color = Config.Style.Metal, Material = Enum.Material.Metal },
		Teeth = { Color = Blocky.shade(Config.Style.Metal, 0.2), Material = Enum.Material.Metal },
		Hub = { Color = DARK_METAL, Material = Enum.Material.Metal },
	}, saw)
	if sawSkin then
		resize(sawSkin, "Blade", cfg.SawSize)
	end
	makeSpinner(saw, blade, cfg.SawSpin)

	-- A log on the table, just reaching the saw.
	local log = decor("Log", Vector3.new(1.8, 1.8, 3.4), at(0, TABLE_TOP + 1.2, sawZ + radius + 1.2), wood, Enum.Material.Wood)
	Blocky.rings(log, Enum.NormalId.Back)

	-- The conveyor belt, from the table out to the pad in front, with a log riding on it.
	local beltBack, beltFront = tableFront, d / 2 + 0.6
	local beltLength = beltFront - beltBack
	local beltZ = (beltBack + beltFront) / 2
	local beltTop = TABLE_TOP - 0.2
	piece("Belt", Vector3.new(2.6, 0.3, beltLength), at(0, beltTop - 0.15, beltZ), Color3.fromRGB(45, 45, 50), Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		piece("BeltRail", Vector3.new(0.3, 0.7, beltLength), at(side * 1.45, beltTop - 0.1, beltZ), Config.Style.HazardYellow, Enum.Material.Metal)
		for _, z in { beltBack + 0.4, beltFront - 0.4 } do
			decor("BeltLeg", Vector3.new(0.4, beltTop - FLOOR_TOP, 0.4), at(side * 1.2, (beltTop + FLOOR_TOP) / 2, z), DARK_METAL, Enum.Material.Metal)
		end
	end
	for index = 0, 3 do
		local roller = decor(
			"Roller",
			Vector3.new(3.3, 0.5, 0.5),
			at(0, beltTop - 0.45, beltBack + 0.5 + index * (beltLength - 1) / 3),
			Config.Style.Metal,
			Enum.Material.Metal
		)
		roller.Shape = Enum.PartType.Cylinder
	end
	local ridingLog = decor("Log", Vector3.new(1.4, 1.4, 2.6), at(0, beltTop + 0.7, beltZ), wood, Enum.Material.Wood)
	Blocky.rings(ridingLog, Enum.NormalId.Back)
	dress(MODELS.SawTable, CFrame.identity, {
		Table = { Color = darkWood, Material = Enum.Material.Wood },
		Top = { Color = Blocky.shade(wood, 0.15), Material = Enum.Material.WoodPlanks },
		Belt = { Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Fabric },
		Rail = { Color = Config.Style.HazardYellow, Material = Enum.Material.Metal },
		Metal = { Color = Config.Style.Metal, Material = Enum.Material.Metal },
		Iron = { Color = DARK_METAL, Material = Enum.Material.Metal },
		Log = { Color = wood, Material = Enum.Material.Wood },
		Rings = { Color = Config.Style.InnerWood, Material = Enum.Material.Wood },
	})
end

-- Inside, by the walls: two sawhorses with a plank, a stack of cut boards and a hand saw on the wall.
local function buildWorkshop()
	group("Workshop")
	local size = Config.Sawmill.BuildingSize
	local w, d = size.X, size.Z
	local x = -w / 2 + 3.5
	for _, z in { -2.5, 1.5 } do
		for _, side in { -1, 1 } do
			local leg = decor("Sawhorse", Vector3.new(0.3, 2.6, 0.3), at(x + side * 0.6, FLOOR_TOP + 1.2, z), darkWood, Enum.Material.Wood)
			leg.CFrame *= CFrame.Angles(0, 0, side * math.rad(15))
		end
		decor("Sawhorse", Vector3.new(1.8, 0.3, 0.4), at(x, FLOOR_TOP + 2.45, z), darkWood, Enum.Material.Wood)
	end
	decor("Plank", Vector3.new(1.4, 0.3, 6), at(x, FLOOR_TOP + 2.75, -0.5), Config.Style.InnerWood, Enum.Material.WoodPlanks)

	local stackX = w / 2 - 3
	for index = 0, 4 do
		local board = decor("Board", Vector3.new(2.4, 0.35, 6), at(stackX, FLOOR_TOP + 0.2 + index * 0.37, -1), Config.Style.InnerWood, Enum.Material.WoodPlanks)
		board.CFrame *= CFrame.Angles(0, math.rad((index % 2) * 4 - 2), 0)
	end

	-- A hand saw hanging on the back wall.
	local backZ = -d / 2 + WALL + 0.1
	decor("HandSaw", Vector3.new(3, 1, 0.1), at(5, 6, backZ), Config.Style.Metal, Enum.Material.Metal)
	decor("HandSawGrip", Vector3.new(1, 1.2, 0.2), at(6.9, 6.1, backZ), darkWood, Enum.Material.Wood)
	dress(MODELS.Workshop, CFrame.identity, {
		Wood = { Color = darkWood, Material = Enum.Material.Wood },
		Board = { Color = Config.Style.InnerWood, Material = Enum.Material.WoodPlanks },
		Metal = { Color = Config.Style.Metal, Material = Enum.Material.Metal },
	})
end

-- A pile of logs against the left wall, outside.
local function buildLogPile()
	group("LogPile")
	local w = Config.Sawmill.BuildingSize.X
	local x = -w / 2 - 3
	for row, count in { 3, 2, 1 } do
		for index = 1, count do
			local offset = (index - (count + 1) / 2) * 1.8
			local log = decor("PileLog", Vector3.new(1.7, 1.7, 6), at(x + offset, 0.85 + (row - 1) * 1.5, 1), wood, Enum.Material.Wood)
			Blocky.rings(log, Enum.NormalId.Back)
		end
	end
	for _, side in { -1, 1 } do
		decor("Stake", Vector3.new(0.4, 3.6, 0.4), at(x + side * 3, 1.8, 1), darkWood, Enum.Material.Wood)
	end
	dress(MODELS.LogPile, at(x, 0, 1), {
		Log = { Color = wood, Material = Enum.Material.Wood },
		Rings = { Color = Config.Style.InnerWood, Material = Enum.Material.Wood },
		Wood = { Color = darkWood, Material = Enum.Material.Wood },
	})
end

-- A lamp post next to the pad, its lantern hanging over towards the pad (the LampPost
-- model from the path when it's imported).
local function buildLampPost()
	group("LampPost")
	local cfg = Config.Sawmill
	local x = -cfg.PadSize / 2 - 2.5
	local z = cfg.BuildingSize.Z / 2 + cfg.PadSize / 2 + 1
	Props.lampPost(model, (origin * at(x, 0, z)).Position, Vector3.xAxis, LAMP_COLOR, false, Random.new(0))
end

-- How far to the right of the sawmill's middle (X) its water wheel and stream are.
local function wheelOffset(): number
	return Config.Sawmill.BuildingSize.X / 2 + WHEEL_WIDTH / 2 + 1.2
end

-- The water wheel on the right side, turning in a stream. In the camp the stream runs back
-- into the river (riverZ is the river's middle); elsewhere it's a little pond.
local function buildWaterWheel(riverZ: number?, wear: number)
	local cfg = Config.Sawmill
	local radius = cfg.WheelRadius
	local wheelX = wheelOffset()
	local wheelY = radius + 0.1 -- the bottom paddles dip into the water

	-- The stream (or pond) under the wheel, with wooden edges.
	group("Stream")
	local nearZ = radius + 1.5
	local farZ = -radius - 1.5
	local edgeFarZ = farZ
	local localRiverZ = if riverZ then riverZ - origin.Position.Z else nil
	if localRiverZ and localRiverZ < farZ then
		farZ = localRiverZ
		edgeFarZ = localRiverZ + Config.Camp.RiverWidth / 2
	end
	local water = decor(
		"Stream",
		Vector3.new(WHEEL_WIDTH + 1.6, WATER_TOP, nearZ - farZ),
		at(wheelX, WATER_TOP / 2, (nearZ + farZ) / 2),
		Blocky.shade(Config.Camp.RiverColor, -wear * 1.5),
		Enum.Material.SmoothPlastic
	)
	water.Transparency = 0.15
	water.Reflectance = 0.1
	water.CanQuery = false -- so raycasts looking for the ground go through it
	for _, side in { -1, 1 } do
		decor(
			"StreamEdge",
			Vector3.new(0.4, 0.8, nearZ - edgeFarZ),
			at(wheelX + side * (WHEEL_WIDTH / 2 + 1), 0.4, (nearZ + edgeFarZ) / 2),
			darkWood,
			Enum.Material.Wood
		)
	end

	-- The wheel: a rim on each side, paddles between them, spokes and a hub on an axle
	-- that goes into the wall. It turns around X, like a cylinder.
	local wheel = Instance.new("Model")
	wheel.Name = "WaterWheel"
	local center = origin * at(wheelX, wheelY, 0)
	local hub = Blocky.part("Hub", Vector3.new(WHEEL_WIDTH + 0.4, 1.2, 1.2), center, darkWood, Enum.Material.Wood, wheel)
	hub.Shape = Enum.PartType.Cylinder
	local axle = Blocky.part("Axle", Vector3.new(2.6, 0.6, 0.6), center * CFrame.new(-WHEEL_WIDTH / 2 - 1.1, 0, 0), DARK_METAL, Enum.Material.Metal, wheel)
	axle.Shape = Enum.PartType.Cylinder
	local step = 2 * math.pi / WHEEL_PIECES
	local rimLength = 2 * radius * math.tan(step / 2) + 0.2
	for index = 1, WHEEL_PIECES do
		local turn = center * CFrame.Angles(index * step, 0, 0)
		for _, side in { -1, 1 } do
			Blocky.part("Rim", Vector3.new(0.3, 0.5, rimLength), turn * CFrame.new(side * WHEEL_WIDTH / 2, radius, 0), wood, Enum.Material.Wood, wheel)
		end
		Blocky.part(
			"Paddle",
			Vector3.new(WHEEL_WIDTH, 1.4, 0.25),
			turn * CFrame.Angles(step / 2, 0, 0) * CFrame.new(0, radius - 0.5, 0),
			Blocky.shade(wood, 0.15),
			Enum.Material.WoodPlanks,
			wheel
		)
	end
	for index = 0, 2 do
		for _, side in { -1, 1 } do
			Blocky.part(
				"Spoke",
				Vector3.new(0.3, radius * 2 - 0.4, 0.4),
				center * CFrame.Angles(index * math.pi / 3, 0, 0) * CFrame.new(side * WHEEL_WIDTH / 2, 0, 0),
				darkWood,
				Enum.Material.Wood,
				wheel
			)
		end
	end
	for _, part in wheel:GetChildren() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	local wheelSkin = dress(MODELS.WaterWheel, at(wheelX, wheelY, 0), {
		Rim = { Color = wood, Material = Enum.Material.Wood },
		Paddle = { Color = Blocky.shade(wood, 0.15), Material = Enum.Material.WoodPlanks },
		Spoke = { Color = darkWood, Material = Enum.Material.Wood },
		Hub = { Color = darkWood, Material = Enum.Material.Wood },
		Shaft = { Color = DARK_METAL, Material = Enum.Material.Metal },
	}, wheel)
	if wheelSkin then
		resize(wheelSkin, "Spoke", radius * 2 - 0.4) -- its upright spoke
	end
	makeSpinner(wheel, hub, cfg.WheelSpin)

	-- A post holding the outer end of the axle.
	decor("WheelPost", Vector3.new(0.8, wheelY + 0.6, 0.8), at(wheelX + WHEEL_WIDTH / 2 + 0.8, (wheelY + 0.6) / 2, 0), darkWood, Enum.Material.Wood)
end

-- The worn sawmills (zones 2 and 3) have a hole in the side wall with a board nailed over
-- it, and loose planks leaning on the back.
local function addWear()
	group("Wear")
	local size = Config.Sawmill.BuildingSize
	local w, d = size.X, size.Z
	decor("Hole", Vector3.new(0.1, 1.8, 2.4), at(-w / 2 - 0.05, 4, -4.5), Color3.fromRGB(25, 20, 18), Enum.Material.SmoothPlastic)
	local board = decor("NailedBoard", Vector3.new(0.2, 0.5, 3.4), at(-w / 2 - 0.15, 4, -4.5), Blocky.shade(wood, 0.1), Enum.Material.WoodPlanks)
	board.CFrame *= CFrame.Angles(math.rad(20), 0, 0)
	for index, x in { -3, -1.6 } do
		local plank = decor("LoosePlank", Vector3.new(1, 6, 0.3), at(x, 2.9, -d / 2 - 0.9), Blocky.shade(wood, 0.05), Enum.Material.WoodPlanks)
		plank.CFrame *= CFrame.Angles(math.rad(12), 0, math.rad((index - 1.5) * 10)) -- leaning on the wall
	end
end

-- Where (X) the stream under the water wheel is, for a sawmill whose middle is at `centerX`.
-- The camp's river banks leave a gap there (see CampManager).
function SawmillBuilding.streamX(centerX: number): number
	return centerX + wheelOffset()
end

-- Builds the sawmill facing +Z with the middle of its floor at `ground`, into `parent`.
-- `wear` (0 to 1) makes it darker and more worn. Pass `riverZ` when it stands by the river.
function SawmillBuilding.build(ground: Vector3, wear: number, riverZ: number?, parent: Model)
	local style = Config.Style
	origin = CFrame.new(ground)
	sawmill = parent
	model = parent
	dressed = false
	wood = Blocky.shade(style.Wood, -wear)
	darkWood = Blocky.shade(style.DarkWood, -wear)
	roofColor = Blocky.shade(style.Roof, -wear)
	buildShed()
	dressShed()
	buildSign()
	buildSaw()
	buildWorkshop()
	buildLogPile()
	buildLampPost()
	buildWaterWheel(riverZ, wear)
	if wear > 0 then
		addWear()
	end
end

return SawmillBuilding
