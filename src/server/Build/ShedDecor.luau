--!strict
-- Everything inside the Tool Shed apart from the tool boards (Build/ShedDisplays), laid out
-- like the shop in Chop a Forest. Below, +Z is the side with the door and the back wall is at
-- -Z (Build/ToolShed turns the whole shed). The middle of the floor plan is (0, 0, 0) at
-- ground level, and the floor is FLOOR_TOP above that.
--   * back-left corner: the "???" shelf (tools still to come) and the trial table under it
--   * right wall: a stone fireplace under the chimney with antlers above it, a nook full of
--     log ends, a two-man saw, coat hooks with two plaid jackets and a notice board
--   * the middle: a round rug with a checkers table and two stools, two lanterns above
--   * by the door: the counter with the shopkeeper (the old shop menu)
-- All for looks, apart from the counter and the trial table (ShopManager and the trial put
-- prompts on them). It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Assets = require(script.Parent.Assets)
local Blocky = require(script.Parent.Blocky)

local WALL = 1
local FLOOR_TOP = 0.7
local LAMP_HEIGHT = 9

local STONE = Color3.fromRGB(143, 150, 163)
local DARK_STONE = Color3.fromRGB(105, 110, 120)
local DARK_METAL = Color3.fromRGB(70, 70, 78)
local SOOT = Color3.fromRGB(30, 26, 24)
local LAMP_COLOR = Color3.fromRGB(255, 215, 120)
local FIRE_COLOR = Color3.fromRGB(255, 138, 60)
local ANTLER = Color3.fromRGB(226, 210, 178)
local RUG_COLOR = Color3.fromRGB(179, 64, 47)
local CORK = Color3.fromRGB(176, 128, 82)
local PAPER = Color3.fromRGB(240, 236, 224)
local CHECKER_RED = Color3.fromRGB(190, 45, 40)
local CHECKER_BLACK = Color3.fromRGB(35, 32, 30)
local TAG_RED = Color3.fromRGB(215, 45, 40)
local ROBUX_GREEN = Color3.fromRGB(80, 210, 90)
local SAND = Color3.fromRGB(235, 200, 120)
local SKIN = Color3.fromRGB(255, 210, 90)
local SHIRT = Color3.fromRGB(75, 150, 70)
local TROUSERS = Color3.fromRGB(50, 70, 120)
-- The two plaid jackets on the coat hooks: their colour and the darker lines across it.
local JACKETS = {
	{ Color = Color3.fromRGB(70, 140, 70), Lines = Color3.fromRGB(35, 75, 40) },
	{ Color = Color3.fromRGB(200, 55, 45), Lines = Color3.fromRGB(70, 25, 25) },
}

local ShedDecor = {}

-- Set at the start of build(): where the shed stands, the shed, the group the next parts go
-- in, and whether the shell model is used (then the lanterns are models too).
local origin: CFrame
local shed: Model
local model: Model
local dressed = false

local function group(name: string)
	model = Instance.new("Model")
	model.Name = name
	model.Parent = shed
end

-- A solid part at `cframe` (in the shed's own space).
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

-- A spot on the inside of the right wall, `along` studs from its middle (+ towards the door).
-- In it, +Z points out of the wall into the room and +X points towards the door.
local function rightWall(along: number): CFrame
	return CFrame.new(Config.Shop.BuildingSize.X / 2 - WALL, 0, along) * CFrame.Angles(0, -math.pi / 2, 0)
end

local function addLight(part: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = part
end

-- Big outlined text on one face of a part, filling it.
local function paint(part: BasePart, face: Enum.NormalId, text: string, color: Color3?)
	local gui = Blocky.face(part, face)
	local box = Blocky.rect(gui, 0.06, 0.1, 0.88, 0.8, Color3.new())
	box.BackgroundTransparency = 1
	Blocky.label(box, text, Config.Style.TitleFont, color)
end

-- A round, flat thing lying on the floor (a cylinder stood up): the rug.
local function disc(name: string, diameter: number, thickness: number, position: Vector3, color: Color3, material: Enum.Material): Part
	local part = decor(name, Vector3.new(thickness, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material)
	part.Shape = Enum.PartType.Cylinder
	part.CanQuery = false
	return part
end

-- The "???" shelf high in the back-left corner: tools that aren't in the shop yet.
local function buildMysteryShelf()
	group("MysteryShelf")
	local size = Config.Shop.BuildingSize
	local style = Config.Style
	local x = -size.X / 2 + WALL + 4.2
	local wallZ = -size.Z / 2 + WALL
	local y = FLOOR_TOP + 12.4
	decor("Shelf", Vector3.new(7, 0.4, 1.6), at(x, y, wallZ + 0.8), style.DarkWood, Enum.Material.Wood)
	for _, side in { -1, 1 } do
		decor("Bracket", Vector3.new(0.3, 1.2, 1.2), at(x + side * 2.8, y - 0.8, wallZ + 0.6), style.DarkWood, Enum.Material.Wood)
	end
	local count = Config.Shop.MysteryItems
	for index = 1, count do
		local signX = x + (index - (count + 1) / 2) * 3
		Blocky.sign(Config.Shop.Text.Mystery, origin * at(signX, y + 1.4, wallZ + 0.9), 2.4, 2.4, nil, model)
	end
end

-- The trial table under the "???" shelf: a TRIAL SAW sign with a red tag, a Chainsaw lying
-- on the table, an hourglass, and the price painted on the table's front. Returns the top.
local function buildTrialTable(makeDisplay: (toolId: string) -> Model): Part
	group("TrialTable")
	local cfg = Config.Trial
	local style = Config.Style
	local size = Config.Shop.BuildingSize
	local x = -size.X / 2 + WALL + 4.5
	local z = -size.Z / 2 + WALL + 3
	local topY = FLOOR_TOP + 3
	local top = piece("TableTop", Vector3.new(6, 0.4, 3), at(x, topY, z), Blocky.shade(style.Wood, 0.1), Enum.Material.WoodPlanks)
	for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
		piece("TableLeg", Vector3.new(0.4, topY - FLOOR_TOP, 0.4), at(x + corner.X * 2.6, (topY + FLOOR_TOP) / 2, z + corner.Y * 1.2), style.DarkWood, Enum.Material.Wood)
	end
	-- The price, on a board along the table's front.
	local apron = decor("Apron", Vector3.new(5.6, 1.1, 0.2), at(x, topY - 0.75, z + 1.45), style.Wood, Enum.Material.WoodPlanks)
	paint(apron, Enum.NormalId.Back, string.format(cfg.Text.Price, tostring(cfg.RobuxPrice)), ROBUX_GREEN)

	-- The sign on two posts behind the table, and a red tag hanging off its corner.
	local signY = topY + 3.4
	for _, side in { -1, 1 } do
		decor("SignPost", Vector3.new(0.3, signY - topY + 0.6, 0.3), at(x + side * 2.2, (topY + signY) / 2, z - 1.2), style.DarkWood, Enum.Material.Wood)
	end
	Blocky.sign(cfg.Text.Sign, origin * at(x, signY, z - 1.1), 5.2, 1.6, nil, model)
	local tag = decor("TimeTag", Vector3.new(2, 0.9, 0.15), at(x + 2, signY - 1.25, z - 0.85) * CFrame.Angles(0, 0, math.rad(-8)), TAG_RED, Enum.Material.SmoothPlastic)
	paint(tag, Enum.NormalId.Back, string.format(cfg.Text.Tag, math.floor(cfg.Seconds / 60)))

	-- The Chainsaw lying on its side on the table, its bar pointing along the table.
	local saw = makeDisplay(cfg.ToolId)
	saw:PivotTo(origin * at(x, topY + 1, z) * CFrame.Angles(0, math.rad(80), 0) * CFrame.Angles(0, 0, math.pi / 2))
	saw:ScaleTo(1.1)
	local lowest = math.huge
	for _, part in saw:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, corner in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1) } do
				lowest = math.min(lowest, part.CFrame:PointToWorldSpace(half * corner).Y, part.CFrame:PointToWorldSpace(-half * corner).Y)
			end
		end
	end
	local middle = saw:GetBoundingBox().Position
	local rest = (origin * at(x - 0.8, topY + 0.2, z + 0.2)).Position -- where the middle of its bottom goes
	saw:PivotTo(saw:GetPivot() + (rest - Vector3.new(middle.X, lowest, middle.Z)))
	saw.Parent = model

	-- An hourglass: two gold caps, posts, and the sand running into the bottom.
	local hx, hz = x + 2, z + 0.3
	for _, y in { 0.1, 1.9 } do
		decor("HourglassCap", Vector3.new(1, 0.2, 1), at(hx, topY + 0.2 + y, hz), style.Gold, Enum.Material.Metal)
	end
	for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
		decor("HourglassPost", Vector3.new(0.12, 1.8, 0.12), at(hx + corner.X * 0.4, topY + 1.2, hz + corner.Y * 0.4), style.DarkWood, Enum.Material.Wood)
	end
	local glass = decor("HourglassGlass", Vector3.new(0.6, 1.6, 0.6), at(hx, topY + 1.2, hz), Config.Style.Window, Enum.Material.Glass)
	glass.Transparency = 0.5
	decor("HourglassSand", Vector3.new(0.4, 0.5, 0.4), at(hx, topY + 0.6, hz), SAND, Enum.Material.Sand)
	decor("HourglassSand", Vector3.new(0.3, 0.3, 0.3), at(hx, topY + 1.65, hz), SAND, Enum.Material.Sand)
	return top
end

-- A stone fireplace against the right wall, under the shed's chimney, with a fire, a mantel,
-- and deer antlers on the chimney breast above it.
local function buildFireplace()
	group("Fireplace")
	local style = Config.Style
	local spot = rightWall(-Config.Shop.BuildingSize.Z / 2 + 5)
	local wallTop = Config.Shop.BuildingSize.Y
	piece("Fireplace", Vector3.new(6, 4.6, 3), spot * at(0, FLOOR_TOP + 2.3, 1.5), STONE, Enum.Material.Slate)
	decor("Hearth", Vector3.new(7, 0.3, 1.6), spot * at(0, FLOOR_TOP + 0.15, 3.6), DARK_STONE, Enum.Material.Slate)
	decor("Firebox", Vector3.new(3.4, 2.6, 0.2), spot * at(0, FLOOR_TOP + 1.6, 3.02), SOOT, Enum.Material.SmoothPlastic)
	for _, offset in { -0.5, 0.5 } do
		local log = decor("FireLog", Vector3.new(2.4, 0.5, 0.5), spot * at(0, FLOOR_TOP + 0.6, 3.1 + offset * 0.3) * CFrame.Angles(0, offset * 0.4, 0), style.Wood, Enum.Material.Wood)
		log.CastShadow = false
	end
	local flame = decor("Fire", Vector3.new(1.6, 0.9, 0.2), spot * at(0, FLOOR_TOP + 1.2, 3.15), FIRE_COLOR, Enum.Material.Neon)
	flame.CastShadow = false
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 4
	fire.Parent = flame
	addLight(flame, FIRE_COLOR, 16, 1.5)

	decor("Mantel", Vector3.new(6.8, 0.4, 3.6), spot * at(0, FLOOR_TOP + 4.8, 1.8), style.DarkWood, Enum.Material.Wood)
	local breastBottom = FLOOR_TOP + 5
	decor("ChimneyBreast", Vector3.new(4.4, wallTop - breastBottom, 2), spot * at(0, (breastBottom + wallTop) / 2, 1), STONE, Enum.Material.Slate)

	-- The antlers: a wooden plaque with a beam and two points curving out on each side.
	local antlerY = FLOOR_TOP + 9.5
	decor("Plaque", Vector3.new(1.4, 1.4, 0.2), spot * at(0, antlerY, 2.1), style.DarkWood, Enum.Material.Wood)
	for _, side in { -1, 1 } do
		decor("Antler", Vector3.new(0.25, 2.6, 0.25), spot * at(side * 1, antlerY + 1, 2.3) * CFrame.Angles(0, 0, -side * 0.6), ANTLER, Enum.Material.SmoothPlastic)
		decor("Antler", Vector3.new(0.2, 1.1, 0.2), spot * at(side * 0.9, antlerY + 1.9, 2.3) * CFrame.Angles(0, 0, side * 0.2), ANTLER, Enum.Material.SmoothPlastic)
		decor("Antler", Vector3.new(0.2, 1.1, 0.2), spot * at(side * 1.9, antlerY + 2.1, 2.3) * CFrame.Angles(0, 0, -side * 0.3), ANTLER, Enum.Material.SmoothPlastic)
	end
end

-- A nook in the right wall stacked full of round log ends.
local function buildLogNook()
	group("LogNook")
	local style = Config.Style
	local spot = rightWall(-Config.Shop.BuildingSize.Z / 2 + 10.5)
	local columns, rows, size = 3, 5, 0.95
	local width, height = columns * size + 0.2, rows * size + 0.2
	for _, side in { -1, 1 } do
		decor("NookSide", Vector3.new(0.4, height + 0.4, 1.8), spot * at(side * (width / 2 + 0.2), FLOOR_TOP + height / 2 + 0.2, 0.9), style.DarkWood, Enum.Material.Wood)
	end
	decor("NookTop", Vector3.new(width + 1.2, 0.4, 2), spot * at(0, FLOOR_TOP + height + 0.4, 1), style.DarkWood, Enum.Material.Wood)
	for column = 1, columns do
		for row = 1, rows do
			local x = (column - (columns + 1) / 2) * size
			local y = FLOOR_TOP + 0.1 + (row - 0.5) * size
			local turn = spot * at(x, y, 0.85) * CFrame.Angles(0, -math.pi / 2, 0) -- a cylinder's axis is its X: point it out of the wall
			local log = decor("LogEnd", Vector3.new(1.6, size - 0.05, size - 0.05), turn, style.Wood, Enum.Material.Wood)
			log.Shape = Enum.PartType.Cylinder
			local face = decor("LogFace", Vector3.new(0.06, size - 0.25, size - 0.25), turn * CFrame.new(0.8, 0, 0), style.InnerWood, Enum.Material.Wood)
			face.Shape = Enum.PartType.Cylinder
		end
	end
end

-- A two-man saw hanging high on the right wall: a long blade with teeth and a handle at each end.
local function buildTwoManSaw()
	group("TwoManSaw")
	local style = Config.Style
	local spot = rightWall(-2.5)
	local y = FLOOR_TOP + 11.5
	decor("Blade", Vector3.new(7, 1.1, 0.1), spot * at(0, y, 0.15), style.Metal, Enum.Material.Metal)
	decor("Teeth", Vector3.new(7, 0.3, 0.12), spot * at(0, y - 0.65, 0.15), Blocky.shade(style.Metal, -0.25), Enum.Material.Metal)
	for _, side in { -1, 1 } do
		decor("Handle", Vector3.new(0.4, 1.8, 0.4), spot * at(side * 3.7, y + 0.1, 0.25), style.DarkWood, Enum.Material.Wood)
	end
end

-- Plaid: a few dark lines across and down a face.
local function plaid(part: BasePart, color: Color3, lines: Color3)
	local gui = Blocky.face(part, Enum.NormalId.Back, color)
	for index = 1, 3 do
		local line = Blocky.rect(gui, 0, index / 4 - 0.04, 1, 0.08, lines)
		line.BackgroundTransparency = 0.25
		local down = Blocky.rect(gui, index / 4 - 0.05, 0, 0.1, 1, lines)
		down.BackgroundTransparency = 0.35
	end
end

-- Coat hooks on the right wall with a green and a red plaid jacket.
local function buildCoatHooks()
	group("CoatHooks")
	local style = Config.Style
	local spot = rightWall(4)
	local railY = FLOOR_TOP + 8
	decor("HookRail", Vector3.new(5.6, 0.5, 0.3), spot * at(0, railY, 0.15), style.DarkWood, Enum.Material.Wood)
	for index, jacket in JACKETS do
		local x = (index - 1.5) * 2.6
		decor("Hook", Vector3.new(0.2, 0.2, 0.7), spot * at(x, railY, 0.5), DARK_METAL, Enum.Material.Metal)
		local body = decor("Jacket", Vector3.new(2, 3, 0.7), spot * at(x, railY - 1.8, 0.55), jacket.Color, Enum.Material.Fabric)
		plaid(body, jacket.Color, jacket.Lines)
		for _, side in { -1, 1 } do
			decor("Sleeve", Vector3.new(0.5, 2.6, 0.6), spot * at(x + side * 1.2, railY - 2, 0.55), jacket.Color, Enum.Material.Fabric)
		end
	end
end

-- A notice board on the right wall with papers pinned to it.
local function buildNoticeBoard()
	group("NoticeBoard")
	local style = Config.Style
	local spot = rightWall(10.5)
	local y = FLOOR_TOP + 7
	decor("Board", Vector3.new(4.6, 3.4, 0.2), spot * at(0, y, 0.1), CORK, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		decor("BoardFrame", Vector3.new(5, 0.3, 0.3), spot * at(0, y + side * 1.8, 0.15), style.DarkWood, Enum.Material.Wood)
		decor("BoardFrame", Vector3.new(0.3, 3.6, 0.3), spot * at(side * 2.4, y, 0.15), style.DarkWood, Enum.Material.Wood)
	end
	local papers = { Vector3.new(-1.3, 0.6, 5), Vector3.new(0, 0.7, -4), Vector3.new(1.3, 0.4, 7), Vector3.new(-0.7, -0.8, -6), Vector3.new(0.9, -0.7, 3) }
	for _, paper in papers do
		decor("Paper", Vector3.new(1, 1.2, 0.05), spot * at(paper.X, y + paper.Y, 0.23) * CFrame.Angles(0, 0, math.rad(paper.Z)), PAPER, Enum.Material.SmoothPlastic)
		decor("Pin", Vector3.new(0.15, 0.15, 0.1), spot * at(paper.X, y + paper.Y + 0.45, 0.28), TAG_RED, Enum.Material.SmoothPlastic)
	end
end

-- A round rug in the middle of the room, with a checkers table and two stools on it.
local function buildRugAndCheckers()
	group("Rug")
	local style = Config.Style
	local w, d = Config.Shop.BuildingSize.X, Config.Shop.BuildingSize.Z
	local rugZ = d * 0.14
	local diameter = math.min(w, d) * 0.38
	disc("RugEdge", diameter + 0.8, 0.06, Vector3.new(0, FLOOR_TOP + 0.03, rugZ), style.Gold, Enum.Material.Fabric)
	disc("Rug", diameter, 0.08, Vector3.new(0, FLOOR_TOP + 0.05, rugZ), RUG_COLOR, Enum.Material.Fabric)
	disc("RugMiddle", diameter * 0.55, 0.1, Vector3.new(0, FLOOR_TOP + 0.06, rugZ), Blocky.shade(RUG_COLOR, -0.2), Enum.Material.Fabric)

	group("CheckersTable")
	local topY = FLOOR_TOP + 2.6
	piece("TableFoot", Vector3.new(1.6, 0.3, 1.6), at(0, FLOOR_TOP + 0.15, rugZ), style.DarkWood, Enum.Material.Wood)
	piece("TableLeg", Vector3.new(0.6, topY - FLOOR_TOP, 0.6), at(0, (topY + FLOOR_TOP) / 2, rugZ), style.DarkWood, Enum.Material.Wood)
	local top = piece("TableTop", Vector3.new(3.4, 0.3, 3.4), at(0, topY + 0.15, rugZ), style.Wood, Enum.Material.Wood)
	-- The board: 8 x 8 squares, with a few pieces on it.
	local gui = Blocky.face(top, Enum.NormalId.Top, CHECKER_BLACK)
	for row = 0, 7 do
		for column = 0, 7 do
			if (row + column) % 2 == 0 then
				Blocky.rect(gui, 0.05 + column * 0.1125, 0.05 + row * 0.1125, 0.1125, 0.1125, CHECKER_RED)
			end
		end
	end
	for index, spot in { Vector2.new(-1, -1.1), Vector2.new(0.2, -0.9), Vector2.new(-0.6, 1), Vector2.new(0.8, 1.1) } do
		local checker = decor("Checker", Vector3.new(0.18, 0.32, 0.32), at(spot.X, topY + 0.39, rugZ + spot.Y) * CFrame.Angles(0, 0, math.pi / 2), if index <= 2 then CHECKER_RED else Color3.fromRGB(240, 235, 225), Enum.Material.SmoothPlastic)
		checker.Shape = Enum.PartType.Cylinder
	end
	for _, side in { -1, 1 } do
		group("Stool")
		local x = side * 3
		piece("StoolSeat", Vector3.new(1.6, 0.4, 1.6), at(x, FLOOR_TOP + 1.7, rugZ), Blocky.shade(style.Wood, 0.1), Enum.Material.Wood)
		piece("StoolLeg", Vector3.new(0.5, 1.5, 0.5), at(x, FLOOR_TOP + 0.75, rugZ), style.DarkWood, Enum.Material.Wood)
	end
end

-- Two lanterns hanging on chains from the beam across the room (Build/ToolShed builds the beams).
local function buildLanterns()
	local w, d = Config.Shop.BuildingSize.X, Config.Shop.BuildingSize.Z
	local beam = Config.Shop.BuildingSize.Y - 0.4
	local lampY = math.min(LAMP_HEIGHT, beam - 2.6)
	local chain = beam - 0.4 - (lampY + 0.6)
	for _, side in { -1, 1 } do
		group("HangingLamp")
		local spot = Vector2.new(side * w * 0.22, -d * 0.05)
		decor("LampChain", Vector3.new(0.2, chain, 0.2), at(spot.X, lampY + 0.6 + chain / 2, spot.Y), DARK_METAL, Enum.Material.Metal)
		local lamp = decor("Lamp", Vector3.new(1, 1.2, 1), at(spot.X, lampY, spot.Y), LAMP_COLOR, Enum.Material.Neon)
		addLight(lamp, LAMP_COLOR, math.min(18 * w / 32, 40), 1.2)
		if dressed then
			local skin = Assets.placed(model, Config.Models.Buildings.HangingLamp, origin * at(spot.X, lampY, spot.Y))
			if skin then
				local looks: { [string]: Types.SkinLook } = {
					Lamp = { Color = LAMP_COLOR, Material = Enum.Material.Neon },
					Iron = { Color = DARK_METAL, Material = Enum.Material.Metal },
				}
				Blocky.dress(model, skin, looks)
			end
		end
	end
end

-- The counter by the door (the old shop menu's "Open shop" prompt goes on it), with the
-- shopkeeper standing between it and the front wall. Returns the counter.
local function buildCounter(): Part
	group("Counter")
	local style = Config.Style
	local size = Config.Shop.BuildingSize
	local x = Config.Shop.DoorWidth / 2 + 10 -- right of the door, under the window
	local z = size.Z / 2 - WALL - 4
	local counter = piece("Counter", Vector3.new(10, 3.4, 2.4), at(x, FLOOR_TOP + 1.7, z), style.Wood, Enum.Material.WoodPlanks)
	Blocky.logLines(counter, { Enum.NormalId.Front })
	piece("CounterTop", Vector3.new(10.6, 0.4, 2.8), at(x, FLOOR_TOP + 3.6, z), Blocky.shade(style.Wood, 0.2), Enum.Material.Wood)
	decor("Register", Vector3.new(1.8, 1.2, 1.4), at(x + 3, FLOOR_TOP + 4.4, z + 0.2), style.Metal, Enum.Material.Metal)
	decor("Papers", Vector3.new(1.4, 0.3, 1), at(x - 3, FLOOR_TOP + 3.95, z), PAPER, Enum.Material.SmoothPlastic)

	-- The shopkeeper: a blocky figure in an apron and a hat, facing into the room (-Z).
	local keeper = CFrame.new(x, 0, z + 2.6) * CFrame.Angles(0, math.pi, 0)
	local function part(size: Vector3, offset: Vector3, color: Color3, material: Enum.Material)
		decor("Shopkeeper", size, keeper * CFrame.new(offset), color, material)
	end
	part(Vector3.new(1.6, 2, 1), Vector3.new(0, FLOOR_TOP + 1, 0), TROUSERS, Enum.Material.SmoothPlastic)
	part(Vector3.new(2.4, 2.2, 1.2), Vector3.new(0, FLOOR_TOP + 3.1, 0), SHIRT, Enum.Material.SmoothPlastic)
	part(Vector3.new(2, 2, 0.15), Vector3.new(0, FLOOR_TOP + 2.8, 0.65), style.DarkWood, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		part(Vector3.new(0.8, 2, 1), Vector3.new(side * 1.6, FLOOR_TOP + 3.1, 0), SHIRT, Enum.Material.SmoothPlastic)
		part(Vector3.new(0.25, 0.25, 0.05), Vector3.new(side * 0.35, FLOOR_TOP + 5.1, 0.73), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	end
	part(Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, FLOOR_TOP + 4.9, 0), SKIN, Enum.Material.SmoothPlastic)
	part(Vector3.new(2.2, 0.2, 2.2), Vector3.new(0, FLOOR_TOP + 5.7, 0), Blocky.shade(style.DarkWood, -0.2), Enum.Material.Fabric)
	part(Vector3.new(1.4, 0.8, 1.4), Vector3.new(0, FLOOR_TOP + 6.2, 0), Blocky.shade(style.DarkWood, -0.2), Enum.Material.Fabric)
	return counter
end

-- Builds the room's decor into `parent` (the shed). `shedOrigin` is the middle of the floor
-- plan at ground level, turned like the shed; `isDressed` says whether the shell model is used.
-- Returns the counter and the trial table's top.
function ShedDecor.build(shedOrigin: CFrame, isDressed: boolean, makeDisplay: (toolId: string) -> Model, parent: Model): (Part, Part)
	origin = shedOrigin
	shed = parent
	dressed = isDressed
	buildMysteryShelf()
	local trialTable = buildTrialTable(makeDisplay)
	buildFireplace()
	buildLogNook()
	buildTwoManSaw()
	buildCoatHooks()
	buildNoticeBoard()
	buildRugAndCheckers()
	buildLanterns()
	local counter = buildCounter()
	return counter, trialTable
end

return ShedDecor
