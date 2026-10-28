--!strict
-- Builds the Tool Shed in the camp: a big log cabin you can walk into (see STYLE_GUIDE.md and
-- the map design). The door faces +Z, towards spawn. Inside:
--   * every tool hangs on the back wall with a price tag above it
--   * the shopkeeper stands behind the counter, and the "Open shop" prompt is on the counter
--   * an upgrade bench, the Log Vacuum machine, a stove under the chimney, an armchair,
--     a barrel, crates, a rug, and lamps hanging from the roof beams
-- Everything is only for looks, apart from the counter. ShopManager calls ToolShed.build.
-- It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Types = require(ReplicatedStorage.Shared.Types)
local Blocky = require(script.Parent.Blocky)

local WALL = 1 -- how thick the walls are
local FLOOR_TOP = 0.7 -- the plank floor sits on a low stone foundation
local BEAM_HEIGHT = 11.6 -- the beams across the room, just under the top of the walls

local STONE = Color3.fromRGB(143, 150, 163)
local DARK_METAL = Color3.fromRGB(70, 70, 78)
local LAMP_COLOR = Color3.fromRGB(255, 215, 120)
local FIRE_COLOR = Color3.fromRGB(255, 138, 60)
local RUG_COLOR = Color3.fromRGB(179, 64, 47)
local CHAIR_COLOR = Color3.fromRGB(90, 143, 176)
local SKIN = Color3.fromRGB(255, 210, 90)
local SHIRT = Color3.fromRGB(75, 150, 70)
local TROUSERS = Color3.fromRGB(50, 70, 120)
local FLOWERS = { Color3.fromRGB(216, 90, 70), Color3.fromRGB(232, 141, 184), Color3.fromRGB(255, 215, 70) }

local ToolShed = {}

-- Set at the start of build(): where the shed stands, and the model everything goes in.
local origin: CFrame
local model: Model

-- A part placed relative to the middle of the shed's floor plan, at ground level.
local function piece(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material): Part
	return Blocky.part(name, size, origin * CFrame.new(offset), color, material, model)
end

-- Like piece(), but for things you walk through or around without bumping into them.
local function decor(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material): Part
	local part = piece(name, size, offset, color, material)
	part.CanCollide = false
	return part
end

local function addLight(part: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = part
end

-- A window in a wall facing +Z or -Z (side 1 or -1): glass on both faces of the wall,
-- a dark wood frame with a cross, and (outside only) a flower box under it.
local function addWindow(x: number, y: number, wallZ: number, side: number, flowerBox: boolean)
	local style = Config.Style
	local width, height = 5, 4
	for _, face in { 1, -1 } do
		local z = wallZ + face * (WALL / 2 + 0.05)
		decor("Window", Vector3.new(width, height, 0.1), Vector3.new(x, y, z), style.Window, Enum.Material.Glass)
		local frameZ = z + face * 0.1
		decor("WindowFrame", Vector3.new(width + 0.6, 0.4, 0.2), Vector3.new(x, y + height / 2, frameZ), style.DarkWood, Enum.Material.Wood)
		decor("WindowFrame", Vector3.new(width + 0.6, 0.4, 0.2), Vector3.new(x, y - height / 2, frameZ), style.DarkWood, Enum.Material.Wood)
		decor("WindowFrame", Vector3.new(0.4, height, 0.2), Vector3.new(x - width / 2, y, frameZ), style.DarkWood, Enum.Material.Wood)
		decor("WindowFrame", Vector3.new(0.4, height, 0.2), Vector3.new(x + width / 2, y, frameZ), style.DarkWood, Enum.Material.Wood)
		decor("WindowFrame", Vector3.new(0.3, height, 0.2), Vector3.new(x, y, frameZ), style.DarkWood, Enum.Material.Wood)
		decor("WindowFrame", Vector3.new(width, 0.3, 0.2), Vector3.new(x, y, frameZ), style.DarkWood, Enum.Material.Wood)
	end
	if flowerBox then
		local boxZ = wallZ + side * (WALL / 2 + 0.6)
		local boxY = y - height / 2 - 0.6
		decor("FlowerBox", Vector3.new(width + 0.6, 0.8, 1), Vector3.new(x, boxY, boxZ), style.Wood, Enum.Material.WoodPlanks)
		for index = 1, 5 do
			decor(
				"Flower",
				Vector3.new(0.6, 0.6, 0.6),
				Vector3.new(x - width / 2 + index * width / 6, boxY + 0.7, boxZ),
				FLOWERS[(index - 1) % #FLOWERS + 1],
				Enum.Material.SmoothPlastic
			)
		end
	end
end

-- The walls, floor, roof, door, windows, porch and chimney.
local function buildShell()
	local cfg = Config.Shop
	local style = Config.Style
	local size = cfg.BuildingSize
	local w, h, d = size.X, size.Y, size.Z
	local doorWidth, doorHeight = cfg.DoorWidth, cfg.DoorHeight
	local frontZ = d / 2 - WALL / 2

	piece("Foundation", Vector3.new(w + 0.6, FLOOR_TOP - 0.1, d + 0.6), Vector3.new(0, (FLOOR_TOP - 0.1) / 2, 0), STONE, Enum.Material.Slate)
	piece("Floor", Vector3.new(w - WALL * 2, 0.2, d - WALL * 2), Vector3.new(0, FLOOR_TOP - 0.1, 0), style.Wood, Enum.Material.WoodPlanks)

	-- Log walls with dark lines between the logs, inside and out. The front wall has a gap
	-- for the door, with a short piece above it.
	local logFaces = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
	local sidePiece = (w - doorWidth) / 2
	local walls = {
		piece("BackWall", Vector3.new(w, h, WALL), Vector3.new(0, h / 2, -frontZ), style.Wood, Enum.Material.WoodPlanks),
		piece("LeftWall", Vector3.new(WALL, h, d), Vector3.new(-w / 2 + WALL / 2, h / 2, 0), style.Wood, Enum.Material.WoodPlanks),
		piece("RightWall", Vector3.new(WALL, h, d), Vector3.new(w / 2 - WALL / 2, h / 2, 0), style.Wood, Enum.Material.WoodPlanks),
		piece(
			"FrontWall",
			Vector3.new(sidePiece, h, WALL),
			Vector3.new(-doorWidth / 2 - sidePiece / 2, h / 2, frontZ),
			style.Wood,
			Enum.Material.WoodPlanks
		),
		piece(
			"FrontWall",
			Vector3.new(sidePiece, h, WALL),
			Vector3.new(doorWidth / 2 + sidePiece / 2, h / 2, frontZ),
			style.Wood,
			Enum.Material.WoodPlanks
		),
	}
	for _, wall in walls do
		Blocky.logLines(wall, logFaces)
	end
	piece(
		"AboveDoor",
		Vector3.new(doorWidth, h - doorHeight, WALL),
		Vector3.new(0, doorHeight + (h - doorHeight) / 2, frontZ),
		style.Wood,
		Enum.Material.WoodPlanks
	)

	-- Light log ends at the corners, and a frame around the door.
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		decor(
			"Corner",
			Vector3.new(1.4, h, 1.4),
			Vector3.new(corner.X * w / 2, h / 2, corner.Z * d / 2),
			Blocky.shade(style.Wood, 0.25),
			Enum.Material.Wood
		)
	end
	for _, side in { -1, 1 } do
		decor("DoorFrame", Vector3.new(1, doorHeight, WALL + 0.4), Vector3.new(side * (doorWidth / 2 + 0.5), doorHeight / 2, frontZ), style.DarkWood, Enum.Material.Wood)
		-- The doors stand wide open, flat out to the sides of the porch.
		decor(
			"Door",
			Vector3.new(0.4, doorHeight - 0.4, doorWidth / 2),
			Vector3.new(side * (doorWidth / 2 + 0.3), doorHeight / 2, d / 2 + doorWidth / 4 + 0.2),
			Blocky.shade(style.Wood, -0.1),
			Enum.Material.WoodPlanks
		)
	end
	decor("DoorFrame", Vector3.new(doorWidth + 2, 1, WALL + 0.4), Vector3.new(0, doorHeight + 0.5, frontZ), style.DarkWood, Enum.Material.Wood)

	Blocky.roof(origin.Position + Vector3.new(0, h, 0), w, d, cfg.RoofHeight, style.Roof, model)

	-- Beams across the room, which the lamps hang from.
	for _, z in { -1, 6 } do
		decor("Beam", Vector3.new(w - WALL * 2, 0.8, 0.8), Vector3.new(0, BEAM_HEIGHT, z), style.DarkWood, Enum.Material.Wood)
	end

	-- Windows on both sides of the door.
	addWindow(-w / 4 - 2, 6, frontZ, 1, true)
	addWindow(w / 4 + 2, 6, frontZ, 1, true)

	-- A big sign on the roof above the door.
	Blocky.sign(
		"TOOL SHED",
		origin * CFrame.new(0, h + 2, d / 2 + 1.4),
		14,
		3.4,
		style.HazardYellow,
		model
	)

	-- A porch in front of the door, with a little roof on two posts and a lantern each side.
	piece("Porch", Vector3.new(doorWidth + 8, FLOOR_TOP, 4), Vector3.new(0, FLOOR_TOP / 2, d / 2 + 2), style.Wood, Enum.Material.WoodPlanks)
	local porchRoof = decor("PorchRoof", Vector3.new(doorWidth + 7, 0.5, 5), Vector3.new(0, h - 0.6, d / 2 + 2.2), style.Roof, Enum.Material.WoodPlanks)
	porchRoof.CFrame *= CFrame.Angles(math.rad(15), 0, 0) -- sloping down towards the front
	for _, side in { -1, 1 } do
		decor("PorchPost", Vector3.new(0.6, h - 1, 0.6), Vector3.new(side * (doorWidth / 2 + 3), (h - 1) / 2, d / 2 + 3.9), style.DarkWood, Enum.Material.Wood)
		local lantern = decor("Lantern", Vector3.new(0.9, 1.2, 0.9), Vector3.new(side * (doorWidth / 2 + 1.6), 7.5, d / 2 + 0.6), LAMP_COLOR, Enum.Material.Neon)
		addLight(lantern, LAMP_COLOR, 12, 1)
	end

	-- A stone chimney over the stove (see buildCozyCorner), with smoke coming out.
	local chimney = decor("Chimney", Vector3.new(3, 9, 3), Vector3.new(w / 2 - 3, h + 2.5, -d / 2 + 5), STONE, Enum.Material.Slate)
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

-- The tools hang on a board on the back wall, each with a price tag above it.
local function buildToolWall(makeDisplay: (toolId: string) -> Model)
	local style = Config.Style
	local backZ = -Config.Shop.BuildingSize.Z / 2 + WALL
	local tools: { Types.ShopItem } = {}
	for _, item in Shop.Items do
		if item.Kind == "Tool" then
			table.insert(tools, item)
		end
	end
	local spacing = 4
	local width = #tools * spacing
	decor("ToolBoard", Vector3.new(width, 5.4, 0.4), Vector3.new(0, 7.2, backZ + 0.2), Blocky.shade(style.Wood, -0.15), Enum.Material.WoodPlanks)
	for index, item in tools do
		local x = -width / 2 + (index - 0.5) * spacing
		local display = makeDisplay(item.Id)
		-- Tools point along -Z; turn them so the head points up.
		display:PivotTo(origin * CFrame.new(x, 7.4, backZ + 0.9) * CFrame.Angles(math.pi / 2, 0, 0))
		display.Parent = model
		-- The price tags go above the tools, so the counter doesn't hide them.
		local price = Shop.priceOf(item, 0) or 0
		Blocky.sign(`{item.Name}\n{price}`, origin * CFrame.new(x, 11, backZ + 0.5), 3.4, 1.4, style.Gold, model)
	end
end

-- The counter with the "Open shop" prompt, and the shopkeeper behind it. Returns the counter.
local function buildCounter(): Part
	local style = Config.Style
	local z = -4.5
	local counter = piece("Counter", Vector3.new(18, 3.4, 2.4), Vector3.new(0, FLOOR_TOP + 1.7, z), style.Wood, Enum.Material.WoodPlanks)
	Blocky.logLines(counter, { Enum.NormalId.Back })
	piece("CounterTop", Vector3.new(18.6, 0.4, 2.8), Vector3.new(0, FLOOR_TOP + 3.6, z), Blocky.shade(style.Wood, 0.2), Enum.Material.Wood)
	decor("Register", Vector3.new(1.8, 1.2, 1.4), Vector3.new(5, FLOOR_TOP + 4.4, z - 0.2), style.Metal, Enum.Material.Metal)
	decor("Papers", Vector3.new(1.4, 0.3, 1), Vector3.new(-5, FLOOR_TOP + 3.95, z), Color3.fromRGB(236, 233, 222), Enum.Material.SmoothPlastic)

	-- The shopkeeper: a blocky figure in an apron and a hat.
	local back = z - 2.7
	decor("Shopkeeper", Vector3.new(1.6, 2, 1), Vector3.new(0, FLOOR_TOP + 1, back), TROUSERS, Enum.Material.SmoothPlastic)
	decor("Shopkeeper", Vector3.new(2.4, 2.2, 1.2), Vector3.new(0, FLOOR_TOP + 3.1, back), SHIRT, Enum.Material.SmoothPlastic)
	decor("Shopkeeper", Vector3.new(2, 2, 0.15), Vector3.new(0, FLOOR_TOP + 2.8, back + 0.65), style.DarkWood, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		decor("Shopkeeper", Vector3.new(0.8, 2, 1), Vector3.new(side * 1.6, FLOOR_TOP + 3.1, back), SHIRT, Enum.Material.SmoothPlastic)
		decor("Shopkeeper", Vector3.new(0.25, 0.25, 0.05), Vector3.new(side * 0.35, FLOOR_TOP + 5.1, back + 0.73), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	end
	decor("Shopkeeper", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, FLOOR_TOP + 4.9, back), SKIN, Enum.Material.SmoothPlastic)
	decor("Shopkeeper", Vector3.new(2.2, 0.2, 2.2), Vector3.new(0, FLOOR_TOP + 5.7, back), Blocky.shade(style.DarkWood, -0.2), Enum.Material.Fabric)
	decor("Shopkeeper", Vector3.new(1.4, 0.8, 1.4), Vector3.new(0, FLOOR_TOP + 6.2, back), Blocky.shade(style.DarkWood, -0.2), Enum.Material.Fabric)

	return counter
end

-- Along the left wall: a bench with the upgrades on it, and the Log Vacuum machine.
local function buildUpgradeCorner()
	local style = Config.Style
	local x = -Config.Shop.BuildingSize.X / 2 + WALL + 1.8
	piece("Bench", Vector3.new(3.6, 0.4, 8), Vector3.new(x, FLOOR_TOP + 3, -1), Blocky.shade(style.Wood, 0.1), Enum.Material.Wood)
	for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		piece("BenchLeg", Vector3.new(0.4, 2.8, 0.4), Vector3.new(x + corner.X * 1.5, FLOOR_TOP + 1.4, -1 + corner.Z * 3.6), style.DarkWood, Enum.Material.Wood)
	end
	local top = FLOOR_TOP + 3.2
	decor("LogSack", Vector3.new(1.6, 1.8, 1.4), Vector3.new(x, top + 0.9, -3.6), Color3.fromRGB(150, 110, 70), Enum.Material.Fabric)
	for _, offset in { -0.5, 0.5 } do
		decor("Boot", Vector3.new(0.7, 0.8, 1.2), Vector3.new(x + offset, top + 0.4, -1), Color3.fromRGB(60, 40, 30), Enum.Material.Fabric)
	end
	local grindstone = decor("Grindstone", Vector3.new(0.6, 2, 2), Vector3.new(x, top + 1, 1.6), STONE, Enum.Material.Slate)
	grindstone.Shape = Enum.PartType.Cylinder -- a cylinder's flat sides face along X

	local machineZ = 6.5
	piece("LogVacuum", Vector3.new(3.6, 4, 3.6), Vector3.new(x + 1, FLOOR_TOP + 2, machineZ), style.Metal, Enum.Material.Metal)
	decor("LogVacuumLight", Vector3.new(0.1, 0.6, 2.4), Vector3.new(x + 2.85, FLOOR_TOP + 3, machineZ), Color3.fromRGB(110, 230, 110), Enum.Material.Neon)
	decor("LogVacuumPipe", Vector3.new(1.2, 2.4, 1.2), Vector3.new(x + 1, FLOOR_TOP + 5.2, machineZ), DARK_METAL, Enum.Material.Metal)
	decor("LogVacuumHose", Vector3.new(2.6, 0.8, 0.8), Vector3.new(x + 3.4, FLOOR_TOP + 0.6, machineZ + 1), DARK_METAL, Enum.Material.Fabric)
end

-- Along the right wall: the stove with a wood pile, an armchair, a barrel and crates.
local function buildCozyCorner()
	local style = Config.Style
	local wallX = Config.Shop.BuildingSize.X / 2 - WALL
	local stoveX, stoveZ = wallX - 2, -6
	piece("Stove", Vector3.new(3, 3.6, 3), Vector3.new(stoveX, FLOOR_TOP + 1.8, stoveZ), DARK_METAL, Enum.Material.Metal)
	local fire = decor("StoveFire", Vector3.new(0.1, 1.2, 1.6), Vector3.new(stoveX - 1.55, FLOOR_TOP + 1.6, stoveZ), FIRE_COLOR, Enum.Material.Neon)
	addLight(fire, FIRE_COLOR, 14, 1.5)
	local pipeBottom = FLOOR_TOP + 3.6
	local pipeTop = Config.Shop.BuildingSize.Y
	decor("StovePipe", Vector3.new(0.8, pipeTop - pipeBottom, 0.8), Vector3.new(stoveX, (pipeBottom + pipeTop) / 2, stoveZ), DARK_METAL, Enum.Material.Metal)

	-- Firewood next to the stove: square logs with ringed ends, like the ones you chop.
	for _, offset in { Vector3.new(0, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0.9, 0.5) } do
		local log = decor("Firewood", Vector3.new(2.4, 0.9, 0.9), Vector3.new(stoveX + offset.X, FLOOR_TOP + 0.45 + offset.Y, -2.8 + offset.Z), style.Wood, Enum.Material.Wood)
		Blocky.rings(log, Enum.NormalId.Left)
	end

	-- An armchair facing into the room.
	local chairX, chairZ = wallX - 1.8, 1.5
	piece("Chair", Vector3.new(3, 1.2, 3), Vector3.new(chairX, FLOOR_TOP + 1, chairZ), CHAIR_COLOR, Enum.Material.Fabric)
	decor("Chair", Vector3.new(0.8, 3, 3), Vector3.new(chairX + 1.1, FLOOR_TOP + 2, chairZ), CHAIR_COLOR, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		decor("Chair", Vector3.new(3, 1, 0.6), Vector3.new(chairX, FLOOR_TOP + 1.9, chairZ + side * 1.3), Blocky.shade(CHAIR_COLOR, -0.15), Enum.Material.Fabric)
	end

	-- A barrel full of axe handles, and two crates.
	local barrel = piece("Barrel", Vector3.new(3, 2.4, 2.4), Vector3.new(wallX - 7, FLOOR_TOP + 1.5, 6.5), Blocky.shade(style.Wood, -0.1), Enum.Material.Wood)
	barrel.Shape = Enum.PartType.Cylinder
	barrel.CFrame *= CFrame.Angles(0, 0, math.pi / 2) -- stand it up
	for index, offset in { Vector3.new(-0.4, 0, 0.3), Vector3.new(0.4, 0, -0.2), Vector3.new(0, 0, 0.5) } do
		local handle = decor("AxeHandle", Vector3.new(0.3, 3, 0.3), Vector3.new(wallX - 7 + offset.X, FLOOR_TOP + 3.2, 6.5 + offset.Z), style.InnerWood, Enum.Material.Wood)
		handle.CFrame *= CFrame.Angles(0, 0, math.rad((index - 2) * 10))
	end
	piece("Crate", Vector3.new(2.4, 2.4, 2.4), Vector3.new(wallX - 3, FLOOR_TOP + 1.2, 8.2), Color3.fromRGB(200, 145, 90), Enum.Material.WoodPlanks)
	local topCrate = piece("Crate", Vector3.new(2, 2, 2), Vector3.new(wallX - 3, FLOOR_TOP + 3.4, 8.2), Color3.fromRGB(200, 145, 90), Enum.Material.WoodPlanks)
	topCrate.CFrame *= CFrame.Angles(0, math.rad(20), 0)
end

-- A rug in the middle of the floor and three lamps hanging from the beams.
local function buildRugAndLamps()
	local style = Config.Style
	decor("RugEdge", Vector3.new(10.6, 0.06, 7.6), Vector3.new(0, FLOOR_TOP + 0.03, 3), style.Gold, Enum.Material.Fabric)
	decor("Rug", Vector3.new(10, 0.08, 7), Vector3.new(0, FLOOR_TOP + 0.05, 3), RUG_COLOR, Enum.Material.Fabric)
	for _, spot in { Vector2.new(-7, -1), Vector2.new(7, -1), Vector2.new(0, 6) } do
		decor("LampChain", Vector3.new(0.2, 1.6, 0.2), Vector3.new(spot.X, BEAM_HEIGHT - 1.2, spot.Y), DARK_METAL, Enum.Material.Metal)
		local lamp = decor("Lamp", Vector3.new(1, 1.2, 1), Vector3.new(spot.X, BEAM_HEIGHT - 2.6, spot.Y), LAMP_COLOR, Enum.Material.Neon)
		addLight(lamp, LAMP_COLOR, 18, 1.2)
	end
end

-- Outside: a barrel and a crate on one side of the porch, a chopping block with an axe
-- on the other, and a gravel path up to the door.
local function buildYard()
	local style = Config.Style
	local d = Config.Shop.BuildingSize.Z
	local barrel = piece("Barrel", Vector3.new(3, 2.4, 2.4), Vector3.new(-12, 1.5, d / 2 + 2.5), Blocky.shade(style.Wood, -0.1), Enum.Material.Wood)
	barrel.Shape = Enum.PartType.Cylinder
	barrel.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
	piece("Crate", Vector3.new(2.4, 2.4, 2.4), Vector3.new(-9.4, 1.2, d / 2 + 2.8), Color3.fromRGB(200, 145, 90), Enum.Material.WoodPlanks)

	local block = piece("ChoppingBlock", Vector3.new(2.2, 1.4, 2.2), Vector3.new(12, 0.7, d / 2 + 3), style.Wood, Enum.Material.Wood)
	Blocky.rings(block, Enum.NormalId.Top)
	local handle = decor("AxeHandle", Vector3.new(0.3, 2.6, 0.3), Vector3.new(12.2, 2.4, d / 2 + 3), style.InnerWood, Enum.Material.Wood)
	handle.CFrame *= CFrame.Angles(0, 0, math.rad(-20))
	decor("AxeHead", Vector3.new(0.3, 1, 1.2), Vector3.new(11.9, 1.6, d / 2 + 3), style.Metal, Enum.Material.Metal)

	local gravel = decor("Gravel", Vector3.new(5, 0.18, 10), Vector3.new(0, 0.14, d / 2 + 9), Color3.fromRGB(191, 154, 96), Enum.Material.Pebble)
	gravel.CanQuery = false
end

-- Builds the shed with the middle of its floor plan at `ground` and returns the counter
-- (the "Open shop" prompt goes on it). `makeDisplay` makes the look of a tool for the wall.
function ToolShed.build(ground: Vector3, makeDisplay: (toolId: string) -> Model): Part
	origin = CFrame.new(ground)
	model = Instance.new("Model")
	model.Name = "ToolShed"
	buildShell()
	buildToolWall(makeDisplay)
	local counter = buildCounter()
	buildUpgradeCorner()
	buildCozyCorner()
	buildRugAndLamps()
	buildYard()
	model.Parent = workspace
	return counter
end

return ToolShed
