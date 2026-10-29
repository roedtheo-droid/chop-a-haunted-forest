--!strict
-- Builds the Tool Shed in the camp: a big log cabin you can walk into (see STYLE_GUIDE.md and
-- the map design). Below, +Z is the side with the door; Config.Shop.Turn turns the whole shed
-- (90: the door faces +X, the middle of the camp). Its size comes from Config.Shop and
-- everything is placed relative to its walls, so it can be made bigger or smaller; the
-- furniture stays player-sized. Inside, laid out like the shop in Chop a Forest:
--   * every tool on its own framed board on the walls (Build/ShedDisplays)
--   * the "???" shelf, the trial table, a fireplace, the counter with the shopkeeper and
--     the rest of the room (Build/ShedDecor)
-- ShopManager calls ToolShed.build and puts the prompts on the counter and the boards.
-- When the Blender models are imported (Config.Models.Buildings), the shell, the lanterns and
-- the barrel and crate outside are those models, each over its parts version: the parts turn
-- invisible but still do the bumping, the lights and the smoke (see Blocky.dress).
-- It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Assets = require(script.Parent.Assets)
local Blocky = require(script.Parent.Blocky)
local ShedDecor = require(script.Parent.ShedDecor)
local ShedDisplays = require(script.Parent.ShedDisplays)

local WALL = 1 -- how thick the walls are
local FLOOR_TOP = 0.7 -- the plank floor sits on a low stone foundation

local STONE = Color3.fromRGB(143, 150, 163)
local DARK_METAL = Color3.fromRGB(70, 70, 78)
local LAMP_COLOR = Color3.fromRGB(255, 215, 120)
local FLOWERS = { Color3.fromRGB(216, 90, 70), Color3.fromRGB(232, 141, 184), Color3.fromRGB(255, 215, 70) }
local LEAF_GREEN = Color3.fromRGB(95, 160, 60)
local CRATE_COLOR = Color3.fromRGB(200, 145, 90)
local MODELS = Config.Models.Buildings

local BARREL_LOOKS: { [string]: Types.SkinLook } = {
	Barrel = { Color = Blocky.shade(Config.Style.Wood, -0.1), Material = Enum.Material.Wood },
	Hoop = { Color = DARK_METAL, Material = Enum.Material.Metal },
}
local CRATE_LOOKS: { [string]: Types.SkinLook } = {
	Crate = { Color = CRATE_COLOR, Material = Enum.Material.WoodPlanks },
	Trim = { Color = Blocky.shade(CRATE_COLOR, -0.25), Material = Enum.Material.Wood },
}

local ToolShed = {}

-- Set at the start of build(): where the shed stands, the whole shed, the group the next
-- parts go in (see group()), and whether the shell model is used (then the furniture
-- models are too, because the shed is the size they're made for).
local origin: CFrame
local shed: Model
local model: Model
local dressed = false

-- Start a group for the parts of one thing (the shell, the barrel...), so its Blender model
-- can go over it. piece() and decor() put their parts in the newest group.
local function group(name: string)
	model = Instance.new("Model")
	model.Name = name
	model.Parent = shed
end

-- Put Blender model `name` over the newest group, with its origin `offset` from the middle of
-- the shed's floor plan (at ground level), `scale` times its usual size. Only once the shell
-- is dressed. Returns the model, or nil (then the parts stay as they are).
local function dress(name: string, offset: CFrame, looks: { [string]: Types.SkinLook }, scale: number?): Model?
	if not dressed then
		return nil
	end
	local skin = Assets.placed(model, name, origin * offset, scale)
	if skin then
		Blocky.dress(model, skin, looks)
	end
	return skin
end

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

-- How high the beams across the room are: just under the top of the walls.
local function beamHeight(): number
	return Config.Shop.BuildingSize.Y - 0.4
end

-- A window `width` by `height` in a wall facing +Z or -Z (side 1 or -1): glass on both faces
-- of the wall, a dark wood frame with a cross, and (outside only) a flower box under it.
local function addWindow(x: number, y: number, width: number, height: number, wallZ: number, side: number, flowerBox: boolean)
	local style = Config.Style
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
	group("Shell")
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

	Blocky.roof(origin.Position + Vector3.new(0, h, 0), w, d, cfg.RoofHeight, style.Roof, model, origin.Rotation)

	-- Beams across the room, which the lamps hang from.
	for _, z in { -d * 0.05, d * 0.27 } do
		decor("Beam", Vector3.new(w - WALL * 2, 0.8, 0.8), Vector3.new(0, beamHeight(), z), style.DarkWood, Enum.Material.Wood)
	end

	-- A window in the middle of the wall on each side of the door, sized to fit the wall.
	local windowWidth, windowHeight = w * 0.16, h * 0.33
	local windowY = math.max(6, h * 0.42)
	addWindow(-doorWidth / 2 - sidePiece / 2, windowY, windowWidth, windowHeight, frontZ, 1, true)
	addWindow(doorWidth / 2 + sidePiece / 2, windowY, windowWidth, windowHeight, frontZ, 1, true)

	-- A porch in front of the door, with a little roof on two posts just above the door, and
	-- a lantern each side.
	local porchTop = math.min(h - 0.6, doorHeight + 1.4)
	piece("Porch", Vector3.new(doorWidth + 8, FLOOR_TOP, 4), Vector3.new(0, FLOOR_TOP / 2, d / 2 + 2), style.Wood, Enum.Material.WoodPlanks)
	local porchRoof = decor("PorchRoof", Vector3.new(doorWidth + 7, 0.5, 5), Vector3.new(0, porchTop, d / 2 + 2.2), style.Roof, Enum.Material.WoodPlanks)
	porchRoof.CFrame *= CFrame.Angles(math.rad(15), 0, 0) -- sloping down towards the front
	for _, side in { -1, 1 } do
		local postHeight = porchTop - 0.4
		decor("PorchPost", Vector3.new(0.6, postHeight, 0.6), Vector3.new(side * (doorWidth / 2 + 3), postHeight / 2, d / 2 + 3.9), style.DarkWood, Enum.Material.Wood)
		local lantern = decor("Lantern", Vector3.new(0.9, 1.2, 0.9), Vector3.new(side * (doorWidth / 2 + 1.6), doorHeight * 0.75, d / 2 + 0.6), LAMP_COLOR, Enum.Material.Neon)
		addLight(lantern, LAMP_COLOR, 12, 1)
	end

	-- A stone chimney over the fireplace (see Build/ShedDecor), with smoke coming out. It's tall
	-- enough to stick out of the roof.
	local chimneySize = math.max(3, w * 0.07)
	local chimneyHeight = cfg.RoofHeight + 1
	local chimney = decor(
		"Chimney",
		Vector3.new(chimneySize, chimneyHeight, chimneySize),
		Vector3.new(w / 2 - 3, h + chimneyHeight / 2 - 2, -d / 2 + 5),
		STONE,
		Enum.Material.Slate
	)
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

-- Is the shell model made for this size of shed (Config.Shop)? Checked on its foundation,
-- the height of its walls and its door frame.
local function shellFits(shell: Model): boolean
	local cfg = Config.Shop
	local size = cfg.BuildingSize
	local foundation = shell:FindFirstChild("Foundation")
	local doorway = shell:FindFirstChild("Doorway")
	if not (foundation and foundation:IsA("BasePart") and doorway and doorway:IsA("BasePart")) then
		return false
	end
	local wallTop = 0
	for _, part in shell:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Wall" then
			wallTop = math.max(wallTop, part.Position.Y + part.Size.Y / 2 - origin.Position.Y)
		end
	end
	return Assets.near(foundation.Size.X, size.X + 0.6)
		and Assets.near(foundation.Size.Z, size.Z + 0.6)
		and Assets.near(wallTop, size.Y)
		and Assets.near(doorway.Size.X, cfg.DoorWidth + 2)
		and Assets.near(doorway.Size.Y, cfg.DoorHeight + 1)
end

-- The ToolShedShell model over the shell's parts, if it's imported and fits. Its walls and
-- roof are solid, so the camera stays inside when you're in the shed.
local function dressShell()
	local shell = Assets.placed(model, MODELS.ToolShedShell, origin)
	if not shell then
		return
	end
	if not shellFits(shell) then
		warn("[ToolShed] The Tool Shed models are made for a 56 x 18 x 38 shed with a 12 x 13 door (Config.Shop changed?): using parts")
		shell:Destroy()
		return
	end
	local style = Config.Style
	Blocky.dress(model, shell, {
		Foundation = { Color = STONE, Material = Enum.Material.Slate },
		Floor = { Color = style.Wood, Material = Enum.Material.WoodPlanks },
		Wall = { Color = style.Wood, Material = Enum.Material.Wood, Solid = true },
		Gable = { Color = style.Wood, Material = Enum.Material.Wood, Solid = true },
		Roof = { Color = style.Roof, Material = Enum.Material.WoodPlanks, Solid = true },
		Corner = { Color = Blocky.shade(style.Wood, 0.25), Material = Enum.Material.Wood },
		Doorway = { Color = style.DarkWood, Material = Enum.Material.Wood },
		Door = { Color = Blocky.shade(style.Wood, -0.1), Material = Enum.Material.WoodPlanks },
		Trim = { Color = style.DarkWood, Material = Enum.Material.Wood },
		Glass = { Color = style.Window, Material = Enum.Material.Glass },
		FlowerBox = { Color = style.Wood, Material = Enum.Material.WoodPlanks },
		Leaf = { Color = LEAF_GREEN, Material = Enum.Material.Grass },
		Porch = { Color = style.Wood, Material = Enum.Material.WoodPlanks },
		Awning = { Color = style.Roof, Material = Enum.Material.WoodPlanks },
		Chimney = { Color = STONE, Material = Enum.Material.Slate },
		Lamp = { Color = LAMP_COLOR, Material = Enum.Material.Neon },
		Iron = { Color = DARK_METAL, Material = Enum.Material.Metal },
	})
	-- The window boxes' flowers come in three parts, one for each colour.
	local index = 0
	for _, part in shell:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Flower" then
			index += 1
			part.Color = FLOWERS[(index - 1) % #FLOWERS + 1]
			part.Material = Enum.Material.SmoothPlastic
		end
	end
	dressed = true
end

-- A big sign on the roof above the door.
local function buildSign()
	group("Sign")
	local size = Config.Shop.BuildingSize
	local signWidth = size.X * 0.44
	Blocky.sign(
		"TOOL SHED",
		origin * CFrame.new(0, size.Y + Config.Shop.RoofHeight * 0.25, size.Z / 2 + 1.4),
		signWidth,
		signWidth * 0.24,
		Config.Style.HazardYellow,
		model
	)
end

-- Outside: a barrel and a crate on one side of the porch, a chopping block with an axe
-- on the other, and a gravel path up to the door.
local function buildYard()
	local style = Config.Style
	local d = Config.Shop.BuildingSize.Z
	-- Just past the ends of the porch.
	local side = Config.Shop.DoorWidth / 2 + 8
	group("Barrel")
	local barrel = piece("Barrel", Vector3.new(3, 2.4, 2.4), Vector3.new(-side, 1.5, d / 2 + 2.5), Blocky.shade(style.Wood, -0.1), Enum.Material.Wood)
	barrel.Shape = Enum.PartType.Cylinder
	barrel.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
	dress(MODELS.Barrel, CFrame.new(-side, 0, d / 2 + 2.5), BARREL_LOOKS)
	group("Crate")
	piece("Crate", Vector3.new(2.4, 2.4, 2.4), Vector3.new(-side + 2.6, 1.2, d / 2 + 2.8), CRATE_COLOR, Enum.Material.WoodPlanks)
	dress(MODELS.Crate, CFrame.new(-side + 2.6, 0, d / 2 + 2.8), CRATE_LOOKS)

	-- The chopping block is the Stump model from the forest when it's imported.
	group("ChoppingBlock")
	local block = Blocky.block(
		Config.Models.Stump,
		"ChoppingBlock",
		Vector3.new(2.2, 1.4, 2.2),
		origin * CFrame.new(side, 0.7, d / 2 + 3),
		style.Wood,
		Enum.Material.Wood,
		model
	)
	Blocky.rings(block, Enum.NormalId.Top)
	local handle = decor("AxeHandle", Vector3.new(0.3, 2.6, 0.3), Vector3.new(side + 0.2, 2.4, d / 2 + 3), style.InnerWood, Enum.Material.Wood)
	handle.CFrame *= CFrame.Angles(0, 0, math.rad(-20))
	decor("AxeHead", Vector3.new(0.3, 1, 1.2), Vector3.new(side - 0.1, 1.6, d / 2 + 3), style.Metal, Enum.Material.Metal)

	local gravel = decor("Gravel", Vector3.new(5, 0.18, 10), Vector3.new(0, 0.14, d / 2 + 9), Color3.fromRGB(191, 154, 96), Enum.Material.Pebble)
	gravel.CanQuery = false
end

export type Built = {
	Origin: CFrame, -- the middle of the floor plan at ground level, turned like the shed
	Counter: BasePart, -- the "Open shop" prompt goes on it
	Plates: { [string]: BasePart }, -- the price plate on each tool's board, by item Id ("Buy" prompts)
	TrialTable: BasePart, -- the trial table's top
}

-- Builds the shed with the middle of its floor plan at `ground`. `makeDisplay` makes the
-- look of a tool for its board on the wall.
function ToolShed.build(ground: Vector3, makeDisplay: (toolId: string) -> Model): Built
	origin = CFrame.new(ground) * CFrame.Angles(0, math.rad(Config.Shop.Turn), 0)
	dressed = false
	shed = Instance.new("Model")
	shed.Name = "ToolShed"
	buildShell()
	dressShell()
	buildSign()
	group("Displays")
	local plates = ShedDisplays.build(origin, FLOOR_TOP, makeDisplay, model)
	local counter, trialTable = ShedDecor.build(origin, dressed, makeDisplay, shed)
	buildYard()
	shed.Parent = workspace
	return { Origin = origin, Counter = counter, Plates = plates, TrialTable = trialTable }
end

return ToolShed
