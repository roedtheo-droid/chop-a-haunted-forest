--!strict
-- The sell yard in front of a sawmill, like the one in Chop a Forest:
--   * a big floor of wooden planks with a yellow and black hazard edge and "DROP LOGS"
--     painted on it, with logs lying along its sides
--   * a wooden "SELL LOGS" sign standing next to it, and a billboard floating high above it:
--     "[coin] N PER LOG" and "SELL LOGS", with a yellow arrow that bobs (on every player's
--     computer, see Client/Controllers/SellYardController)
--   * a conveyor with orange rails running from the pad's left end up into a big orange
--     drum chipper with a chute, a control panel, wheels and warning signs
--   * a chopping block with an axe in it and a small pile of firewood
-- Below, +Z is the side facing spawn and the zone's gate (the sawmill's open front), and
-- (0, 0, 0) is the middle of the sawmill's floor plan at ground level.
-- The pad's attributes say where the conveyor and the chipper's mouth are, so every player's
-- computer can slide the sold logs along them. SawmillManager does the selling.
-- It's not a system, so it has no init()/start().

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Blocky = require(script.Parent.Blocky)

local PAD_COLOR = Color3.fromRGB(196, 138, 85) -- light wooden planks
local PAD_THICKNESS = 0.4
local STRIPE_WIDTH = 0.8 -- the yellow and black edge around the pad
local BELT_WIDTH = 2.4
local BELT_COLOR = Color3.fromRGB(45, 45, 50)
local DARK_METAL = Color3.fromRGB(70, 70, 78)
local PANEL_RED = Color3.fromRGB(205, 45, 40)
local SIGN_WHITE = Color3.fromRGB(245, 242, 235)
local LOG_COLOR = Color3.fromRGB(125, 80, 48)
local BUTTON_COLORS = { Color3.fromRGB(80, 200, 80), Color3.fromRGB(230, 50, 40), Color3.fromRGB(250, 210, 30) }

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

-- A cylinder whose round ends face along `axis` ("X", "Y" or "Z").
local function cylinder(name: string, length: number, diameter: number, position: CFrame, axis: string, color: Color3, material: Enum.Material): Part
	local turn = if axis == "Y" then CFrame.Angles(0, 0, math.pi / 2) elseif axis == "Z" then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity
	local part = decor(name, Vector3.new(length, diameter, diameter), position * turn, color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Outlined text on one face of a part. `box` is where it goes on that face (scale numbers).
local function paint(part: BasePart, face: Enum.NormalId, text: string, box: Rect, color: Color3?, font: Enum.Font?): TextLabel
	local gui = part:FindFirstChild(`{face.Name}Face`) or Blocky.face(part, face)
	local holder = Blocky.rect(gui, box.Min.X, box.Min.Y, box.Width, box.Height, Color3.new())
	holder.BackgroundTransparency = 1
	return Blocky.label(holder, text, font or Config.Style.TitleFont, color)
end

-- Yellow and black stripes across one face of a part (the frame around the chipper's mouth).
local function hazardStripes(part: BasePart, face: Enum.NormalId, count: number)
	local gui = Blocky.face(part, face, Config.Style.HazardYellow)
	for index = 0, count - 1, 2 do
		Blocky.rect(gui, index / count, 0, 1 / count, 1, Config.Style.HazardBlack)
	end
end

-- How far out in front of the sawmill (Z) the middle of the pad is.
local function padZ(): number
	local cfg = Config.Sawmill
	return cfg.BuildingSize.Z / 2 + STRIPE_WIDTH + cfg.PadSize.Y / 2
end

local function buildPad(): Part
	group("Pad")
	local size = Config.Sawmill.PadSize
	local z = padZ()
	local pad = piece("DropPad", Vector3.new(size.X, PAD_THICKNESS, size.Y), at(0, PAD_THICKNESS / 2, z), Blocky.shade(PAD_COLOR, -wear), Enum.Material.WoodPlanks)
	Blocky.hazardEdge(pad, STRIPE_WIDTH, model)

	-- "DROP LOGS" on a see-through square lying on the pad (a square, so the turned text fits).
	local side = math.min(size.X, size.Y) * 0.95
	local words = decor("DropLogsText", Vector3.new(side, 0.05, side), at(0, PAD_THICKNESS + 0.03, z), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	words.Transparency = 1
	words.CanQuery = false
	words.CanTouch = false
	local label = Blocky.label(Blocky.face(words, Enum.NormalId.Top), Config.Sawmill.Text.DropLogs, Config.Style.TitleFont)
	label.Rotation = 90 -- so it reads the right way up when you walk onto the pad from the front

	-- Logs lying along the pad's sides (the left side has the conveyor in the middle).
	local logX = size.X / 2 + STRIPE_WIDTH + 1
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

-- The conveyor from the pad's left edge up to the chipper's mouth. Returns its two ends.
local function buildConveyor(): (Vector3, Vector3)
	group("Conveyor")
	local cfg = Config.Sawmill
	local z = padZ()
	local startX = -cfg.PadSize.X / 2 - STRIPE_WIDTH
	local bottom = Vector3.new(startX, PAD_THICKNESS + 0.15, z)
	local top = Vector3.new(startX - cfg.ConveyorLength, cfg.ChipperHeight, z)
	local length = (top - bottom).Magnitude
	local belt = CFrame.lookAt((bottom + top) / 2, top) -- its Z runs along the belt
	decor("Belt", Vector3.new(BELT_WIDTH, 0.3, length), belt, BELT_COLOR, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		decor("BeltRail", Vector3.new(0.3, 0.7, length), belt * CFrame.new(side * (BELT_WIDTH / 2 + 0.15), 0.2, 0), cfg.ChipperColor, Enum.Material.Metal)
	end
	for index = 1, 3 do
		local point = bottom:Lerp(top, index / 3.5)
		for _, side in { -1, 1 } do
			local height = point.Y - 0.2
			decor("BeltLeg", Vector3.new(0.3, height, 0.3), at(point.X, height / 2, z + side * (BELT_WIDTH / 2 - 0.2)), DARK_METAL, Enum.Material.Metal)
		end
	end
	for index = 0, 4 do
		local roller = belt * CFrame.new(0, -0.3, -length / 2 + 0.4 + index * (length - 0.8) / 4)
		cylinder("Roller", BELT_WIDTH + 0.4, 0.4, roller, "X", Config.Style.Metal, Enum.Material.Metal)
	end
	return bottom, top
end

-- The big orange drum chipper at the top of the conveyor. `mouth` is where the belt ends.
local function buildChipper(mouth: Vector3): Vector3
	group("Chipper")
	local cfg = Config.Sawmill
	local text = cfg.Text
	local color = cfg.ChipperColor
	local style = Config.Style
	local z = mouth.Z
	local size = Vector3.new(6, 4.6, 5)
	local right = mouth.X - 0.3 -- its side with the mouth faces the conveyor (+X)
	local x = right - size.X / 2
	local bottomY = 1.2
	local middleY = bottomY + size.Y / 2
	piece("Chipper", size, at(x, middleY, z), color, Enum.Material.Metal)
	piece("Chassis", Vector3.new(size.X + 0.4, 0.6, size.Z - 0.8), at(x, bottomY - 0.3, z), DARK_METAL, Enum.Material.Metal)
	for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
		cylinder("Wheel", 0.6, 1.8, at(x + corner.X * 2, 0.9, z + corner.Y * (size.Z / 2 - 0.1)), "Z", Color3.fromRGB(35, 35, 38), Enum.Material.Rubber)
	end

	-- The mouth: a dark opening with a hazard-striped frame, right where the belt ends.
	local mouthY = cfg.ChipperHeight + 0.4
	decor("Mouth", Vector3.new(0.2, 1.8, 2.8), at(right + 0.05, mouthY, z), Color3.fromRGB(20, 18, 18), Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		local bar = decor("MouthFrame", Vector3.new(0.3, 0.5, 3.8), at(right + 0.15, mouthY + side * 1.15, z), style.HazardYellow, Enum.Material.SmoothPlastic)
		hazardStripes(bar, Enum.NormalId.Right, 8)
		local post = decor("MouthFrame", Vector3.new(0.3, 1.8, 0.5), at(right + 0.15, mouthY, z + side * 1.65), style.HazardYellow, Enum.Material.SmoothPlastic)
		hazardStripes(post, Enum.NormalId.Right, 2)
	end

	-- The chute on top: a pipe going up, then bending out over the back.
	local topY = bottomY + size.Y
	cylinder("Chute", 3, 1.3, at(x - 1.2, topY + 1.5, z), "Y", color, Enum.Material.Metal)
	cylinder("Chute", 3, 1.1, at(x - 2.4, topY + 3.3, z) * CFrame.Angles(0, 0, math.rad(35)), "X", color, Enum.Material.Metal)
	decor("ChuteRim", Vector3.new(0.4, 1.5, 1.5), at(x - 1.2, topY + 0.2, z), DARK_METAL, Enum.Material.Metal)

	-- The red and white control panel on the front (+Z), near the mouth.
	local frontZ = z + size.Z / 2
	decor("ControlPanel", Vector3.new(1.8, 2.2, 0.4), at(right - 1.2, middleY + 0.3, frontZ + 0.2), PANEL_RED, Enum.Material.SmoothPlastic)
	decor("ControlPlate", Vector3.new(1.4, 1.2, 0.1), at(right - 1.2, middleY + 0.5, frontZ + 0.42), SIGN_WHITE, Enum.Material.SmoothPlastic)
	for index, buttonColor in BUTTON_COLORS do
		cylinder("Button", 0.15, 0.3, at(right - 1.7 + index * 0.25, middleY - 0.45, frontZ + 0.45), "Z", buttonColor, Enum.Material.Neon)
	end

	-- Its name plate on the front, and a DANGER sign on a post by the mouth.
	local plate = decor("NamePlate", Vector3.new(3.4, 1.6, 0.1), at(x - 1.1, middleY + 0.4, frontZ + 0.05), SIGN_WHITE, Enum.Material.SmoothPlastic)
	paint(plate, Enum.NormalId.Back, text.ChipperName, Rect.new(0.05, 0.05, 0.95, 0.6), color)
	paint(plate, Enum.NormalId.Back, text.ChipperInfo, Rect.new(0.08, 0.62, 0.92, 0.92), nil, style.BodyFont)
	local signX, signZ = right + 2, z + Config.Sawmill.PadSize.Y / 2 - 1
	decor("DangerPost", Vector3.new(0.3, 3.4, 0.3), at(signX, 1.7, signZ), darkWood, Enum.Material.Wood)
	local danger = decor("DangerSign", Vector3.new(2.6, 1.8, 0.1), at(signX, 3.4, signZ + 0.2), SIGN_WHITE, Enum.Material.SmoothPlastic)
	local band = Blocky.face(danger, Enum.NormalId.Back)
	Blocky.rect(band, 0, 0, 1, 0.45, PANEL_RED)
	paint(danger, Enum.NormalId.Back, text.Danger, Rect.new(0.05, 0.04, 0.95, 0.42))
	paint(danger, Enum.NormalId.Back, text.DangerInfo, Rect.new(0.06, 0.52, 0.94, 0.92), Color3.fromRGB(30, 30, 30), style.BodyFont)
	return Vector3.new(right - 0.6, mouthY, z)
end

-- The wooden "SELL LOGS" sign on two posts at the pad's front right corner.
local function buildSign()
	group("SellSign")
	local cfg = Config.Sawmill
	local x = cfg.PadSize.X / 2 + 3
	local z = padZ() + cfg.PadSize.Y / 2 + 1.5
	local signY = 3.8
	for _, side in { -1, 1 } do
		decor("SignPost", Vector3.new(0.4, signY + 0.6, 0.4), at(x + side * 2.4, (signY + 0.6) / 2, z), darkWood, Enum.Material.Wood)
	end
	Blocky.sign(cfg.Text.SellLogs, origin * at(x, signY, z + 0.3), 6, 2.2, nil, model)
end

-- The billboard floating high over the pad: "[coin] N PER LOG", "SELL LOGS" and an arrow.
-- It always turns to face you (a BillboardGui), and each player's computer bobs the arrow.
local function buildBillboard(perLog: number)
	group("Billboard")
	local cfg = Config.Sawmill
	local style = Config.Style
	local anchor = decor("BillboardAnchor", Vector3.new(1, 1, 1), at(0, cfg.BillboardHeight, padZ()), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CanQuery = false
	anchor.CanTouch = false

	local gui = Instance.new("BillboardGui")
	gui.Name = "SellBillboard"
	gui.Size = UDim2.fromScale(cfg.BillboardSize.X, cfg.BillboardSize.Y)
	gui.LightInfluence = 0
	gui.MaxDistance = 300
	gui.Parent = anchor

	-- Top row: a coin and the price per log, in yellow.
	local row = Instance.new("Frame")
	row.Name = "PerLog"
	row.Size = UDim2.fromScale(1, 0.24)
	row.BackgroundTransparency = 1
	row.Parent = gui
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.fromScale(0.12, 0.5)
	coin.Size = UDim2.fromScale(0.85, 0.85)
	coin.SizeConstraint = Enum.SizeConstraint.RelativeYY
	coin.BackgroundColor3 = style.Gold
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = coin
	local ring = Instance.new("UIStroke")
	ring.Thickness = 3
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = coin
	coin.Parent = row
	local price = Blocky.label(row, string.format(cfg.Text.PerLog, tostring(perLog)), style.TitleFont, style.Gold)
	price.Position = UDim2.fromScale(0.25, 0)
	price.Size = UDim2.fromScale(0.65, 1)

	local title = Blocky.label(gui, cfg.Text.SellLogs, style.TitleFont)
	title.Name = "Title"
	title.Position = UDim2.fromScale(0, 0.24)
	title.Size = UDim2.fromScale(1, 0.4)

	-- The arrow pointing down at the pad: a shaft and two slanted bars making the point.
	local arrow = Instance.new("Frame")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0)
	arrow.Position = UDim2.fromScale(0.5, 0.66)
	arrow.Size = UDim2.fromScale(0.3, 0.3)
	arrow.SizeConstraint = Enum.SizeConstraint.RelativeYY
	arrow.BackgroundTransparency = 1
	arrow.Parent = gui
	local function bar(position: UDim2, size: UDim2, rotation: number)
		local part = Instance.new("Frame")
		part.AnchorPoint = Vector2.new(0.5, 0.5)
		part.Position = position
		part.Size = size
		part.Rotation = rotation
		part.BackgroundColor3 = style.HazardYellow
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = part
		part.Parent = arrow
	end
	bar(UDim2.fromScale(0.5, 0.35), UDim2.fromScale(0.26, 0.6), 0)
	bar(UDim2.fromScale(0.32, 0.68), UDim2.fromScale(0.24, 0.62), -45)
	bar(UDim2.fromScale(0.68, 0.68), UDim2.fromScale(0.24, 0.62), 45)
	CollectionService:AddTag(anchor, Tags.SellBillboard)
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

-- Builds the yard in front of the sawmill whose floor plan's middle is at `ground`, into
-- `parent`. `wear` (0 to 1) makes it darker and more worn; `perLog` is what one log from this
-- zone's trees is worth (the billboard shows it). Returns the DROP LOGS pad.
function SellYard.build(ground: Vector3, worn: number, perLog: number, parent: Model): BasePart
	origin = CFrame.new(ground)
	yard = parent
	wear = worn
	wood = Blocky.shade(LOG_COLOR, -worn)
	darkWood = Blocky.shade(Config.Style.DarkWood, -worn)
	local pad = buildPad()
	local bottom, top = buildConveyor()
	local mouth = buildChipper(top)
	buildSign()
	buildBillboard(perLog)
	buildChoppingBlock()
	-- Where the sold logs slide (world positions, for Client/Controllers/SellYardController).
	pad:SetAttribute("BeltStart", (origin * CFrame.new(bottom)).Position)
	pad:SetAttribute("BeltEnd", (origin * CFrame.new(top)).Position)
	pad:SetAttribute("Mouth", (origin * CFrame.new(mouth)).Position)
	return pad
end

return SellYard
