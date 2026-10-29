--!strict
-- Builds Mr. Graves' giant steel vault (see Config.Landowner): a dark blue-grey block with a
-- big round door, a 6-spoke wheel handle, rivets, two hinges and three gold letters on top,
-- with stacks of cash bales and gold bars tied with olive straps around it.
-- Everything is only for looks. LandownerManager calls Vault.build.
-- It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Blocky = require(script.Parent.Blocky)

local DOOR_THICKNESS = 0.8
local RIVET = 0.35
local BALE = Vector3.new(3, 1.3, 2) -- one bale of cash
local BAR = Vector3.new(1.8, 0.6, 0.8) -- one gold bar

local Vault = {}

local folder: Instance

local function piece(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return Blocky.part(name, size, cframe, color, material, folder)
end

-- Like piece(), but players walk through it and raycasts ignore it (small details).
local function detail(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = piece(name, size, cframe, color, material)
	part.CanCollide = false
	part.CanQuery = false
	return part
end

-- A round disc whose flat sides face along the CFrame's Z axis (a cylinder's axis is its X).
local function disc(name: string, radius: number, thickness: number, cframe: CFrame, color: Color3): Part
	local part = detail(name, Vector3.new(thickness, radius * 2, radius * 2), cframe * CFrame.Angles(0, math.pi / 2, 0), color, Enum.Material.Metal)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- The steel block itself, with a darker frame around its front, rivets along the frame and
-- a plinth under it.
local function buildBody(base: CFrame)
	local cfg = Config.Landowner
	local size = cfg.VaultSize
	local trim = cfg.VaultTrimColor
	piece("VaultPlinth", Vector3.new(size.X + 1, 0.6, size.Z + 1), base * CFrame.new(0, 0.3, 0), trim, Enum.Material.Metal)
	piece("VaultBody", size, base * CFrame.new(0, 0.6 + size.Y / 2, 0), cfg.VaultColor, Enum.Material.DiamondPlate)

	-- The frame: four bars around the front face.
	local front = -size.Z / 2 - 0.15
	local middleY = 0.6 + size.Y / 2
	local bar = 0.9
	detail("VaultFrame", Vector3.new(size.X, bar, 0.3), base * CFrame.new(0, 0.6 + size.Y - bar / 2, front), trim, Enum.Material.Metal)
	detail("VaultFrame", Vector3.new(size.X, bar, 0.3), base * CFrame.new(0, 0.6 + bar / 2, front), trim, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		detail("VaultFrame", Vector3.new(bar, size.Y, 0.3), base * CFrame.new(side * (size.X - bar) / 2, middleY, front), trim, Enum.Material.Metal)
	end

	-- Rivets along the frame.
	local rivetZ = front - 0.2
	for index = 0, 6 do
		local x = -size.X / 2 + bar / 2 + index * (size.X - bar) / 6
		for _, y in { 0.6 + bar / 2, 0.6 + size.Y - bar / 2 } do
			detail("Rivet", Vector3.one * RIVET, base * CFrame.new(x, y, rivetZ), cfg.DoorColor, Enum.Material.Metal)
		end
	end
	for index = 1, 5 do
		local y = 0.6 + bar / 2 + index * (size.Y - bar) / 6
		for _, side in { -1, 1 } do
			detail("Rivet", Vector3.one * RIVET, base * CFrame.new(side * (size.X - bar) / 2, y, rivetZ), cfg.DoorColor, Enum.Material.Metal)
		end
	end
end

-- The big round door with a ring around it, two hinges on its right (as you look at it)
-- and a wheel handle with 6 spokes in the middle.
local function buildDoor(base: CFrame)
	local cfg = Config.Landowner
	local size = cfg.VaultSize
	local radius = math.min(size.X, size.Y) * 0.36
	local center = base * CFrame.new(0, 0.6 + size.Y / 2, -size.Z / 2)

	disc("DoorRing", radius + 0.6, 0.5, center * CFrame.new(0, 0, -0.2), cfg.VaultTrimColor)
	disc("Door", radius, DOOR_THICKNESS, center * CFrame.new(0, 0, -0.4 - DOOR_THICKNESS / 2), cfg.DoorColor)
	disc("DoorPlate", radius * 0.55, 0.2, center * CFrame.new(0, 0, -0.4 - DOOR_THICKNESS - 0.1), cfg.VaultColor)
	local face = -0.4 - DOOR_THICKNESS

	-- Bolts around the door's edge.
	for index = 1, 12 do
		local angle = index * math.pi * 2 / 12
		local spot = Vector3.new(math.cos(angle), math.sin(angle), 0) * (radius - 0.5)
		detail("Bolt", Vector3.one * RIVET, center * CFrame.new(spot.X, spot.Y, face - 0.1), cfg.VaultTrimColor, Enum.Material.Metal)
	end

	-- Two big hinges. Looking at the door, your right is the vault's -X side.
	for _, y in { radius * 0.55, -radius * 0.55 } do
		detail("Hinge", Vector3.new(2.2, 1.4, 1), center * CFrame.new(-radius - 0.3, y, face + 0.1), cfg.VaultTrimColor, Enum.Material.Metal)
		detail("HingePin", Vector3.new(0.6, 1.8, 0.6), center * CFrame.new(-radius - 1.2, y, face - 0.2), cfg.DoorColor, Enum.Material.Metal)
	end

	-- The wheel handle: a hub, 6 spokes, and a knob on the end of each.
	local wheelZ = face - 0.5
	disc("WheelHub", 0.6, 0.6, center * CFrame.new(0, 0, wheelZ), cfg.VaultTrimColor)
	local spoke = radius * 0.5
	for index = 0, 5 do
		local angle = index * math.pi / 3
		local turn = center * CFrame.new(0, 0, wheelZ - 0.1) * CFrame.Angles(0, 0, angle)
		detail("Spoke", Vector3.new(spoke, 0.3, 0.3), turn * CFrame.new(spoke / 2, 0, 0), cfg.VaultTrimColor, Enum.Material.Metal)
		detail("SpokeKnob", Vector3.new(0.6, 0.6, 0.6), turn * CFrame.new(spoke, 0, 0), cfg.DoorColor, Enum.Material.Metal)
	end
end

-- Three gold letters standing on top of the vault, facing the front.
local function buildLetters(base: CFrame)
	local cfg = Config.Landowner
	local size = cfg.VaultSize
	local letters = cfg.VaultLetters
	local height = 3
	local width = 2.6
	for index = 1, #letters do
		local x = (index - (#letters + 1) / 2) * (width + 0.5)
		local plate = detail(
			"Letter",
			Vector3.new(width, height, 0.6),
			base * CFrame.new(x, 0.6 + size.Y + height / 2, -size.Z / 2 + 1.5),
			cfg.LetterColor,
			Enum.Material.SmoothPlastic
		)
		plate.Transparency = 1 -- only the letter on it shows
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Blocky.face(plate, face)
			gui.LightInfluence = 0
			Blocky.label(gui, letters:sub(index, index), Config.Style.TitleFont, cfg.LetterColor)
		end
	end
end

-- A stack of cash bales, `layers` high, each layer a little smaller, with straps around them.
local function cashStack(spot: CFrame, layers: number)
	local cfg = Config.Landowner
	for layer = 0, layers - 1 do
		local across = math.max(3 - layer, 1)
		for column = 1, across do
			local offset = (column - (across + 1) / 2) * (BALE.X + 0.05)
			local frame = spot * CFrame.new(offset, BALE.Y * (layer + 0.5), 0)
			piece("Cash", BALE, frame, cfg.CashColor, Enum.Material.Fabric)
			detail("CashTop", Vector3.new(BALE.X - 0.3, 0.05, BALE.Z - 0.3), frame * CFrame.new(0, BALE.Y / 2, 0), Blocky.shade(cfg.CashColor, 0.25), Enum.Material.SmoothPlastic)
			detail("Strap", Vector3.new(0.4, BALE.Y + 0.08, BALE.Z + 0.08), frame, cfg.StrapColor, Enum.Material.Fabric)
		end
	end
end

-- A pyramid of gold bars with an olive strap over each layer.
local function goldStack(spot: CFrame, layers: number)
	local cfg = Config.Landowner
	for layer = 0, layers - 1 do
		local across = layers - layer
		for column = 1, across do
			local offset = (column - (across + 1) / 2) * (BAR.X + 0.1)
			for row = -1, 1, 2 do
				local frame = spot * CFrame.new(offset, BAR.Y * (layer + 0.5), row * (BAR.Z / 2 + 0.05))
				local bar = piece("Gold", BAR, frame, cfg.GoldColor, Enum.Material.Metal)
				bar.Reflectance = 0.2
			end
		end
		local width = across * (BAR.X + 0.1)
		detail("Strap", Vector3.new(width + 0.1, 0.12, 0.35), spot * CFrame.new(0, BAR.Y * (layer + 1) + 0.02, 0), cfg.StrapColor, Enum.Material.Fabric)
	end
end

-- Builds the vault and its money into `parent`. `base` is the vault's foot: a CFrame on the
-- ground in the middle of the vault, its front (-Z) pointing where the door faces.
function Vault.build(parent: Instance, base: CFrame)
	folder = parent
	local size = Config.Landowner.VaultSize
	buildBody(base)
	buildDoor(base)
	buildLetters(base)

	-- Money on both sides of the vault and in front of its corners. Each one is turned a
	-- little, so it looks piled up by hand.
	local random = Random.new(11)
	local function turned(x: number, z: number): CFrame
		return base * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(random:NextNumber(-12, 12)), 0)
	end
	local sideX = size.X / 2 + 3
	cashStack(turned(sideX, -size.Z / 4), 3)
	cashStack(turned(-sideX, size.Z / 4), 3)
	goldStack(turned(-sideX, -size.Z / 4), 4)
	goldStack(turned(sideX, size.Z / 4), 3)
	cashStack(turned(size.X / 2 - 1, -size.Z / 2 - 3), 2)
	goldStack(turned(-size.X / 2 + 1, -size.Z / 2 - 2.5), 2)
end

return Vault
