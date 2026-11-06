--!strict
-- The sell yard in front of a sawmill:
--   * a big floor of wooden planks with a dark timber edge and "FEED ME" painted on it, with logs
--     lying along its sides
--   * a wooden chute from the pad's left end up to the lip of Gnawbert (see Build/Gnawbert), a
--     chained stump mimic that eats the logs
--   * a wooden SELL LOGS sign with the price, and a sign with Gnawbert's name and a warning
--   * a chopping block with an axe in it and a small pile of firewood
-- Below, +Z is the side facing spawn and the zone's gate (the sawmill's open front), and
-- (0, 0, 0) is the middle of the sawmill's floor plan at ground level.
-- The pad's attributes say where the chute and Gnawbert's mouth are, so every player's computer
-- can hop the sold logs along them (see Client/Controllers/SellYardController). SawmillManager
-- does the selling.
-- It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Blocky = require(script.Parent.Blocky)
local Gnawbert = require(script.Parent.Gnawbert)

local PAD_COLOR = Color3.fromRGB(196, 138, 85) -- light wooden planks
local PAD_THICKNESS = 0.4
local EDGE_WIDTH = 0.8 -- the dark beams around the pad
local EDGE_HEIGHT = 0.3
local LOG_COLOR = Color3.fromRGB(125, 80, 48)
local CHUTE_FLOOR = 0.25 -- how thick its floor boards are
local CHUTE_RAIL = Vector2.new(0.35, 0.8) -- how wide and tall its side rails are
local CHUTE_SLATS = 7 -- boards across its floor, for the logs to hop over

local SellYard = {}

-- Set at the start of build(): where the sawmill stands, the group the next parts go in, and
-- its wood colours (darker at the worn sawmills).
local origin: CFrame
local model: Model
local yard: Model
local wear = 0
local wood: Color3
local darkWood: Color3

local function group(name: string)
	model = Instance.new("Model")
	model.Name = name
	model.Parent = yard
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function piece(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return Blocky.part(name, size, origin * cframe, color, material, model)
end

-- Like piece(), but for things you walk through or around without bumping into them.
local function decor(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = piece(name, size, cframe, color, material)
	part.CanCollide = false
	return part
end

-- Outlined text on one face of a part. `box` is where it goes on that face (scale numbers).
local function paint(part: BasePart, face: Enum.NormalId, text: string, box: Rect, color: Color3?, font: Enum.Font?): TextLabel
	local gui = part:FindFirstChild(`{face.Name}Face`) or Blocky.face(part, face)
	local holder = Blocky.rect(gui, box.Min.X, box.Min.Y, box.Width, box.Height, Color3.new())
	holder.BackgroundTransparency = 1
	return Blocky.label(holder, text, font or Config.Style.TitleFont, color)
end

-- How far out in front of the sawmill (Z) the middle of the pad is.
local function padZ(): number
	local cfg = Config.Sawmill
	return cfg.BuildingSize.Z / 2 + EDGE_WIDTH + cfg.PadSize.Y / 2
end

-- Dark beams around the pad. They can't be touched, so they don't get in the way of its Touched event.
local function addEdge(z: number)
	local size = Config.Sawmill.PadSize
	local y = PAD_THICKNESS + EDGE_HEIGHT / 2 - 0.1
	local beams = {
		{ Size = Vector3.new(size.X + EDGE_WIDTH * 2, EDGE_HEIGHT, EDGE_WIDTH), Spot = at(0, y, z + size.Y / 2 + EDGE_WIDTH / 2) },
		{ Size = Vector3.new(size.X + EDGE_WIDTH * 2, EDGE_HEIGHT, EDGE_WIDTH), Spot = at(0, y, z - size.Y / 2 - EDGE_WIDTH / 2) },
		{ Size = Vector3.new(EDGE_WIDTH, EDGE_HEIGHT, size.Y), Spot = at(size.X / 2 + EDGE_WIDTH / 2, y, z) },
		{ Size = Vector3.new(EDGE_WIDTH, EDGE_HEIGHT, size.Y), Spot = at(-size.X / 2 - EDGE_WIDTH / 2, y, z) },
	}
	for _, beam in beams do
		local part = decor("Edge", beam.Size, beam.Spot, darkWood, Enum.Material.Wood)
		part.CanTouch = false
		part.CanQuery = false
	end
end

local function buildPad(): Part
	group("Pad")
	local size = Config.Sawmill.PadSize
	local z = padZ()
	local pad = piece("DropPad", Vector3.new(size.X, PAD_THICKNESS, size.Y), at(0, PAD_THICKNESS / 2, z), Blocky.shade(PAD_COLOR, -wear), Enum.Material.WoodPlanks)
	addEdge(z)

	-- "FEED ME" on a see-through square lying on the pad (a square, so the turned text fits).
	local side = math.min(size.X, size.Y) * 0.95
	local words = decor("FeedMeText", Vector3.new(side, 0.05, side), at(0, PAD_THICKNESS + 0.03, z), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	words.Transparency = 1
	words.CanQuery = false
	words.CanTouch = false
	local label = Blocky.label(Blocky.face(words, Enum.NormalId.Top), Config.Sawmill.Text.FeedMe, Config.Style.TitleFont)
	label.Rotation = 90 -- so it reads the right way up when you walk onto the pad from the front

	-- Logs lying along the pad's sides (the left side has the chute in the middle).
	local logX = size.X / 2 + EDGE_WIDTH + 1
	local logLength = 3.4
	for _, spot in { Vector2.new(logX, -1), Vector2.new(logX, 0), Vector2.new(logX, 1), Vector2.new(-logX, -1), Vector2.new(-logX, 1) } do
		local log = Blocky.block(
			Config.Models.Log,
			"SideLog",
			Vector3.new(logLength, 1.3, 1.3),
			origin * at(spot.X, 0.65, z + spot.Y * (size.Y / 2 - logLength / 2 - 0.2)) * CFrame.Angles(0, math.pi / 2, 0),
			wood,
			Enum.Material.Wood,
			model
		)
		Blocky.rings(log, Enum.NormalId.Left)
		Blocky.rings(log, Enum.NormalId.Right)
	end
	return pad
end

-- The wooden chute from the pad's left edge up to Gnawbert's lip. Returns its two ends.
local function buildChute(): (Vector3, Vector3)
	group("Chute")
	local cfg = Config.Sawmill
	local z = padZ()
	local startX = -cfg.PadSize.X / 2 - EDGE_WIDTH
	local bottom = Vector3.new(startX, PAD_THICKNESS + 0.15, z)
	local top = Vector3.new(startX - cfg.ChuteLength, cfg.ChuteHeight, z)
	local length = (top - bottom).Magnitude
	local slope = CFrame.lookAt((bottom + top) / 2, top) -- its Z runs along the chute
	decor("ChuteFloor", Vector3.new(cfg.ChuteWidth, CHUTE_FLOOR, length), slope, wood, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		decor(
			"ChuteRail",
			Vector3.new(CHUTE_RAIL.X, CHUTE_RAIL.Y, length),
			slope * CFrame.new(side * (cfg.ChuteWidth / 2 + CHUTE_RAIL.X / 2), CHUTE_RAIL.Y / 2 - CHUTE_FLOOR / 2, 0),
			darkWood,
			Enum.Material.Wood
		)
	end
	for index = 1, CHUTE_SLATS do
		local along = (index - 0.5) / CHUTE_SLATS * length - length / 2
		decor("ChuteSlat", Vector3.new(cfg.ChuteWidth, 0.1, 0.45), slope * CFrame.new(0, CHUTE_FLOOR / 2 + 0.05, along), Blocky.shade(wood, 0.12), Enum.Material.WoodPlanks)
	end
	for index = 1, 3 do
		local point = bottom:Lerp(top, index / 3.5)
		for _, side in { -1, 1 } do
			local height = point.Y - 0.1
			decor("ChuteLeg", Vector3.new(0.4, height, 0.4), at(point.X, height / 2, z + side * (cfg.ChuteWidth / 2 + 0.1)), darkWood, Enum.Material.Wood)
		end
	end
	return bottom, top
end

-- Gnawbert, facing along the chute with its lip at the chute's top. Returns its mouth.
local function buildGnawbert(lip: Vector3): Vector3
	local middle = lip - Vector3.new(Config.Sawmill.Gnawbert.Front, lip.Y, 0)
	return Gnawbert.build(origin * CFrame.new(middle) * CFrame.Angles(0, math.pi / 2, 0), wear, yard)
end

-- The wooden "SELL LOGS" sign and the price under it, on two posts at the pad's front right corner.
local function buildSign(perLog: number)
	group("SellSign")
	local cfg = Config.Sawmill
	local x = cfg.PadSize.X / 2 + 3
	local z = padZ() + cfg.PadSize.Y / 2 + 1.5
	local signY = 6.2
	for _, side in { -1, 1 } do
		decor("SignPost", Vector3.new(0.4, signY + 0.6, 0.4), at(x + side * 2.4, (signY + 0.6) / 2, z), darkWood, Enum.Material.Wood)
	end
	Blocky.sign(cfg.Text.SellLogs, origin * at(x, signY, z + 0.3), 6, 2.2, nil, model)
	Blocky.sign(string.format(cfg.Text.PerLog, tostring(perLog)), origin * at(x, signY - 1.9, z + 0.3), 5, 1.3, Config.Style.Gold, model)
end

-- A sign on a post by the chute: Gnawbert's name, and a warning.
local function buildWarning()
	group("WarningSign")
	local cfg = Config.Sawmill
	local text = cfg.Text
	local x = -cfg.PadSize.X / 2 - EDGE_WIDTH - cfg.ChuteLength / 2 - 1
	local z = padZ() + cfg.PadSize.Y / 2 - 0.5
	decor("WarningPost", Vector3.new(0.4, 4, 0.4), at(x, 2, z), darkWood, Enum.Material.Wood)
	local board = decor("WarningBoard", Vector3.new(4.4, 2.4, 0.3), at(x, 4.2, z + 0.25) * CFrame.Angles(0, math.rad(-12), 0), wood, Enum.Material.WoodPlanks)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		paint(board, face, text.GnawbertName, Rect.new(0.06, 0.08, 0.94, 0.54), Config.Style.Gold)
		paint(board, face, text.DoNotPet, Rect.new(0.1, 0.56, 0.9, 0.92))
	end
end

-- A chopping block with an axe stuck in it, and a small pile of firewood, at the pad's front left.
local function buildChoppingBlock()
	group("ChoppingBlock")
	local style = Config.Style
	local cfg = Config.Sawmill
	local x = -cfg.PadSize.X / 2 - 4.5
	local z = padZ() + cfg.PadSize.Y / 2 + 2.5
	local block = Blocky.block(Config.Models.Stump, "ChoppingBlock", Vector3.new(2.2, 1.4, 2.2), origin * at(x, 0.7, z), wood, Enum.Material.Wood, model)
	Blocky.rings(block, Enum.NormalId.Top)
	local handle = decor("AxeHandle", Vector3.new(0.3, 2.6, 0.3), at(x + 0.2, 2.4, z), style.InnerWood, Enum.Material.Wood)
	handle.CFrame *= CFrame.Angles(0, 0, math.rad(-20))
	decor("AxeHead", Vector3.new(0.3, 1, 1.2), at(x - 0.1, 1.6, z), Color3.fromRGB(200, 50, 45), Enum.Material.Metal)
	for index, offset in { Vector3.new(-2.6, 0.35, 0), Vector3.new(-2.6, 0.35, 0.75), Vector3.new(-2.6, 1.0, 0.38) } do
		local firewood = decor("Firewood", Vector3.new(1.8, 0.7, 0.7), at(x + offset.X, offset.Y, z + offset.Z) * CFrame.Angles(0, index * 0.05, 0), wood, Enum.Material.Wood)
		Blocky.rings(firewood, Enum.NormalId.Left)
	end
end

-- How far out (Z) the pad's middle is, and where its right edge is (X, with its dark edge),
-- from the middle of the sawmill's floor plan (Build/YardShop stands beside it).
function SellYard.padSpot(): (number, number)
	return padZ(), Config.Sawmill.PadSize.X / 2 + EDGE_WIDTH
end

-- Builds the yard in front of the sawmill whose floor plan's middle is at `ground`, into
-- `parent`. `worn` (0 to 1) makes it darker and more worn; `perLog` is what one log from this
-- zone's trees is worth (the sign shows it). Returns the pad.
function SellYard.build(ground: Vector3, worn: number, perLog: number, parent: Model): BasePart
	origin = CFrame.new(ground)
	yard = parent
	wear = worn
	wood = Blocky.shade(LOG_COLOR, -worn)
	darkWood = Blocky.shade(Config.Style.DarkWood, -worn)
	local pad = buildPad()
	local bottom, top = buildChute()
	local mouth = buildGnawbert(top)
	buildSign(perLog)
	buildWarning()
	buildChoppingBlock()
	-- Where the sold logs go (world positions, for Client/Controllers/SellYardController).
	pad:SetAttribute("ChuteStart", (origin * CFrame.new(bottom)).Position)
	pad:SetAttribute("ChuteEnd", (origin * CFrame.new(top)).Position)
	pad:SetAttribute("Mouth", mouth)
	return pad
end

return SellYard
