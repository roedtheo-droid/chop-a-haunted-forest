--!strict
-- Builds the Garage (see Config.Garage): a log-cabin barn with big wooden double doors
-- standing open, an orange "GARAGE" sign over them, lanterns, a tool shelf inside, a gravel
-- driveway in front and the glowing yellow pad on the gravel that opens the Garage screen.
-- GarageManager calls GarageBuilding.build. It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Blocky = require(script.Parent.Blocky)

local LOG = 1.3 -- how tall each log in the walls is
local WALL = 1.2 -- how thick the walls are
local LANTERN_LIGHT = Color3.fromRGB(255, 200, 120)

local GarageBuilding = {}

local folder: Instance

local function piece(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return Blocky.part(name, size, cframe, color, material, folder)
end

-- Like piece(), but players walk through it and raycasts ignore it.
local function detail(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = piece(name, size, cframe, color, material)
	part.CanCollide = false
	part.CanQuery = false
	return part
end

-- A wall of logs lying on top of each other, `length` long (along the CFrame's X), from the
-- ground up to `height`. Every other log is a shade darker, so you can see them.
local function logWall(frame: CFrame, length: number, height: number, from: number?)
	local style = Config.Style
	local y = from or 0
	local index = 0
	while y < height - 0.01 do
		local tall = math.min(LOG, height - y)
		local color = if index % 2 == 0 then style.Wood else Blocky.shade(style.Wood, -0.08)
		piece("Log", Vector3.new(length, tall, WALL), frame * CFrame.new(0, y + tall / 2, 0), color, Enum.Material.Wood)
		y += tall
		index += 1
	end
end

-- One open door: a wooden leaf with an X brace, turned `angle` around its hinge.
local function door(hinge: CFrame, width: number, height: number, side: number, angle: number)
	local style = Config.Style
	local turned = hinge * CFrame.Angles(0, -side * angle, 0) -- swung outwards (towards -Z)
	local middle = turned * CFrame.new(-side * width / 2, height / 2, 0)
	piece("Door", Vector3.new(width, height, 0.5), middle, style.Wood, Enum.Material.WoodPlanks)
	-- The frame and the X brace on the outside (-Z) face.
	local dark = style.DarkWood
	for _, y in { -height / 2 + 0.3, height / 2 - 0.3 } do
		detail("DoorFrame", Vector3.new(width, 0.6, 0.2), middle * CFrame.new(0, y, -0.3), dark, Enum.Material.Wood)
	end
	for _, x in { -width / 2 + 0.3, width / 2 - 0.3 } do
		detail("DoorFrame", Vector3.new(0.6, height, 0.2), middle * CFrame.new(x, 0, -0.3), dark, Enum.Material.Wood)
	end
	local diagonal = math.sqrt(width * width + height * height) - 1
	local tilt = math.atan2(height, width)
	for _, sign in { -1, 1 } do
		detail("DoorBrace", Vector3.new(diagonal, 0.5, 0.2), middle * CFrame.new(0, 0, -0.32) * CFrame.Angles(0, 0, sign * tilt), dark, Enum.Material.Wood)
	end
end

-- A lantern: a dark iron box with a warm glowing middle and a light.
local function lantern(cframe: CFrame)
	local style = Config.Style
	detail("LanternTop", Vector3.new(1, 0.3, 1), cframe * CFrame.new(0, 0.75, 0), style.HazardBlack, Enum.Material.Metal)
	detail("LanternBottom", Vector3.new(1, 0.3, 1), cframe * CFrame.new(0, -0.75, 0), style.HazardBlack, Enum.Material.Metal)
	local glow = detail("LanternGlow", Vector3.new(0.8, 1.2, 0.8), cframe, Color3.fromRGB(255, 205, 110), Enum.Material.Neon)
	glow.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = LANTERN_LIGHT
	light.Range = 14
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = glow
end

-- A shelf on the back wall with tools, tins and a tyre on it.
local function toolShelf(frame: CFrame)
	local style = Config.Style
	local metal = style.Metal
	for _, side in { -1, 1 } do
		piece("ShelfPost", Vector3.new(0.4, 6, 1.6), frame * CFrame.new(side * 4, 3, 0), style.DarkWood, Enum.Material.Wood)
	end
	for _, y in { 1, 3, 5 } do
		piece("Shelf", Vector3.new(8.4, 0.3, 1.6), frame * CFrame.new(0, y, 0), style.Wood, Enum.Material.WoodPlanks)
	end
	-- Things on the shelves.
	detail("Tin", Vector3.new(0.7, 0.9, 0.7), frame * CFrame.new(-3, 1.6, 0), Color3.fromRGB(200, 60, 50), Enum.Material.Metal)
	detail("Tin", Vector3.new(0.7, 0.9, 0.7), frame * CFrame.new(-2.1, 1.6, 0), Color3.fromRGB(60, 120, 200), Enum.Material.Metal)
	detail("Toolbox", Vector3.new(2, 1, 1), frame * CFrame.new(1.8, 1.65, 0), Color3.fromRGB(200, 50, 45), Enum.Material.Metal)
	detail("Wrench", Vector3.new(2, 0.25, 0.4), frame * CFrame.new(-2, 3.3, 0), metal, Enum.Material.Metal)
	detail("Hammer", Vector3.new(0.3, 0.3, 1.4), frame * CFrame.new(0.5, 3.3, 0), style.Wood, Enum.Material.Wood)
	detail("HammerHead", Vector3.new(0.9, 0.4, 0.4), frame * CFrame.new(0.5, 3.35, -0.6), metal, Enum.Material.Metal)
	local tyre = detail("Tyre", Vector3.new(0.9, 2.2, 2.2), frame * CFrame.new(2.5, 6.25, 0) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(32, 32, 34), Enum.Material.Fabric)
	tyre.Shape = Enum.PartType.Cylinder
end

-- The glowing yellow pad: a see-through yellow floor with neon edges. Players walk through
-- it; GarageController opens the screen when you stand inside it. Returns the floor part.
local function buildPad(cframe: CFrame): Part
	local cfg = Config.Garage
	local size = cfg.PadSize
	local pad = detail("GaragePad", Vector3.new(size.X, 0.1, size.Y), cframe * CFrame.new(0, 0.12, 0), cfg.PadColor, Enum.Material.Neon)
	pad.Transparency = 0.7
	pad.CastShadow = false
	local edge = 0.45
	local edges = {
		{ Size = Vector3.new(size.X, 0.16, edge), At = Vector3.new(0, 0.14, size.Y / 2 - edge / 2) },
		{ Size = Vector3.new(size.X, 0.16, edge), At = Vector3.new(0, 0.14, -size.Y / 2 + edge / 2) },
		{ Size = Vector3.new(edge, 0.16, size.Y), At = Vector3.new(size.X / 2 - edge / 2, 0.14, 0) },
		{ Size = Vector3.new(edge, 0.16, size.Y), At = Vector3.new(-size.X / 2 + edge / 2, 0.14, 0) },
	}
	for _, info in edges do
		local strip = detail("PadEdge", info.Size, cframe * CFrame.new(info.At), cfg.PadColor, Enum.Material.Neon)
		strip.CastShadow = false
	end
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Top
	light.Color = cfg.PadColor
	light.Range = 6
	light.Brightness = 1
	light.Parent = pad
	return pad
end

-- Builds the Garage into `parent`. `base` is the middle of its floor on the ground, its doors
-- facing the CFrame's front (-Z). Returns the pad's floor part.
function GarageBuilding.build(parent: Instance, base: CFrame): Part
	folder = parent
	local cfg = Config.Garage
	local style = Config.Style
	local size = cfg.BuildingSize
	local width, height, depth = size.X, size.Y, size.Z
	local front = -depth / 2

	piece("GarageFloor", Vector3.new(width, 0.3, depth), base * CFrame.new(0, 0.15, 0), Color3.fromRGB(120, 115, 108), Enum.Material.Concrete)

	-- The log walls: the back, both sides, and the front around the big door opening.
	logWall(base * CFrame.new(0, 0, depth / 2 - WALL / 2), width, height)
	for _, side in { -1, 1 } do
		logWall(base * CFrame.new(side * (width / 2 - WALL / 2), 0, 0) * CFrame.Angles(0, math.pi / 2, 0), depth - WALL * 2, height)
	end
	local pillar = (width - cfg.DoorWidth) / 2
	for _, side in { -1, 1 } do
		logWall(base * CFrame.new(side * (width / 2 - pillar / 2), 0, front + WALL / 2), pillar, height)
	end
	logWall(base * CFrame.new(0, 0, front + WALL / 2), cfg.DoorWidth, height, cfg.DoorHeight)

	-- Light log ends at the four corners.
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		detail("Corner", Vector3.new(1.4, height, 1.4), base * CFrame.new(corner.X * width / 2, height / 2, corner.Z * depth / 2), Blocky.shade(style.Wood, 0.25), Enum.Material.Wood)
	end

	-- A gable roof with its ridge running from the doors to the back, like a barn.
	Blocky.roof((base * CFrame.new(0, height, 0)).Position, depth, width, cfg.RoofHeight, style.Roof, folder, base.Rotation * CFrame.Angles(0, math.pi / 2, 0))

	-- The double doors, standing wide open.
	local doorWidth = cfg.DoorWidth / 2
	for _, side in { -1, 1 } do
		local hinge = base * CFrame.new(side * cfg.DoorWidth / 2, 0, front - 0.3)
		door(hinge, doorWidth, cfg.DoorHeight - 0.2, side, math.rad(105))
	end

	-- The orange GARAGE sign over the doors.
	local signFrame = base * CFrame.new(0, cfg.DoorHeight + (height - cfg.DoorHeight) / 2, front - 0.4)
	detail("SignBack", Vector3.new(cfg.DoorWidth - 0.4, 2.6, 0.3), signFrame * CFrame.new(0, 0, 0.2), style.DarkWood, Enum.Material.Wood)
	local sign = detail("GarageSign", Vector3.new(cfg.DoorWidth - 1, 2, 0.4), signFrame, cfg.SignColor, Enum.Material.SmoothPlastic)
	Blocky.boardText(sign, signFrame.LookVector, cfg.Text.Title)

	-- Lanterns on both sides of the doors, and two hanging inside.
	for _, side in { -1, 1 } do
		local spot = base * CFrame.new(side * (cfg.DoorWidth / 2 + 1.6), cfg.DoorHeight - 1.5, front - 1)
		detail("LanternArm", Vector3.new(0.3, 0.3, 1.2), spot * CFrame.new(0, 1, 0.5), style.HazardBlack, Enum.Material.Metal)
		lantern(spot)
		lantern(base * CFrame.new(side * width / 5, height - 2.5, 0))
		detail("LanternChain", Vector3.new(0.15, 1.6, 0.15), base * CFrame.new(side * width / 5, height - 1, 0), style.HazardBlack, Enum.Material.Metal)
	end

	-- The tool shelf on the back wall, and an old tyre leaning beside it.
	toolShelf(base * CFrame.new(width / 4, 0.3, depth / 2 - WALL - 0.9) * CFrame.Angles(0, math.pi, 0))
	local tyre = detail("Tyre", Vector3.new(0.9, 2.6, 2.6), base * CFrame.new(-width / 4, 1.6, depth / 2 - WALL - 0.6) * CFrame.Angles(0, math.pi / 2, math.rad(10)), Color3.fromRGB(32, 32, 34), Enum.Material.Fabric)
	tyre.Shape = Enum.PartType.Cylinder

	-- The gravel driveway in front of the doors, and the glowing pad on it.
	local gravelWidth = cfg.DoorWidth + 4
	local drive = detail("Driveway", Vector3.new(gravelWidth, 0.2, cfg.DrivewayLength), base * CFrame.new(0, 0.1, front - cfg.DrivewayLength / 2), cfg.GravelColor, Enum.Material.Pebble)
	drive.CanCollide = true
	local padFrame = base * CFrame.new(0, 0, front - cfg.PadGap - cfg.PadSize.Y / 2)
	return buildPad(padFrame)
end

return GarageBuilding
