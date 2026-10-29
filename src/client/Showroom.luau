--!strict
-- The Garage's showroom (see Config.Garage), built on this player's computer only, far
-- outside the map, and seen through GarageController's fixed camera:
--   * a round turntable with glowing yellow and orange neon rings, over a glowing pit
--   * a floor with yellow-black hazard stripes and big yellow arrows, two glowing warning
--     beacons and steam puffing from vents
--   * a garage wall behind it: logs, big X-braced doors, a row of bright lights, a wall
--     clock, a tool board, a red tool chest and stacks of tyres
-- The truck turns slowly on the turntable. Changing truck sinks the turntable into the pit,
-- swaps the truck and raises it again with a puff of steam.
-- It's not a controller, so it has no init()/start(): GarageController calls build, show and update.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TruckBuilder = require(ReplicatedStorage.Shared.TruckBuilder)
local Types = require(ReplicatedStorage.Shared.Types)

local ROOM_HALF_WIDTH = 60
local BACK_Z = 26 -- the back wall's front face
local FRONT_Z = -46
local WALL_HEIGHT = 36
local LOG = 1.8
local PLATE_TOP = 0.3 -- the turntable's top, above the floor
local TYRE = Color3.fromRGB(32, 32, 34)
local WHITE = Color3.new(1, 1, 1)

type Moving = { Part: BasePart, Offset: CFrame }
type Phase = "Idle" | "Sinking" | "Rising"

local Showroom = {}

local model: Model? = nil
local origin = CFrame.identity
local turntable: { Moving } = {}
local truckParts: { Moving } = {}
local truckModel: Model? = nil
local nextLook: Types.TruckLook? = nil -- the truck to swap in at the bottom of the pit
local nextName = ""
local phase: Phase = "Idle"
local phaseStart = 0
local angle = 0
local vents: { ParticleEmitter } = {}
local beaconLights: { PointLight } = {}

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = origin * cframe
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = model
	return piece
end

local function neon(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local piece = part(name, size, cframe, color, Enum.Material.Neon)
	piece.CastShadow = false
	return piece
end

-- A flat disc lying on the floor (a cylinder's round sides face along its X, so turn it up).
local function disc(name: string, radius: number, thickness: number, y: number, color: Color3, material: Enum.Material?): Part
	local piece = part(name, Vector3.new(thickness, radius * 2, radius * 2), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), color, material)
	piece.Shape = Enum.PartType.Cylinder
	return piece
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number): PointLight
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = range
	glow.Brightness = brightness
	glow.Shadows = false
	glow.Parent = parent
	return glow
end

-- The floor around a square pit, the pit's glowing walls, and hazard stripes around its edge.
local function buildFloor(pitHalf: number)
	local cfg = Config.Garage
	local floor = cfg.FloorColor
	local thick = 1
	-- Four slabs around the hole.
	part("Floor", Vector3.new(ROOM_HALF_WIDTH * 2, thick, BACK_Z - pitHalf), CFrame.new(0, -thick / 2, (BACK_Z + pitHalf) / 2), floor, Enum.Material.Concrete)
	part("Floor", Vector3.new(ROOM_HALF_WIDTH * 2, thick, -FRONT_Z - pitHalf), CFrame.new(0, -thick / 2, (FRONT_Z - pitHalf) / 2), floor, Enum.Material.Concrete)
	for _, side in { -1, 1 } do
		local width = ROOM_HALF_WIDTH - pitHalf
		part("Floor", Vector3.new(width, thick, pitHalf * 2), CFrame.new(side * (pitHalf + width / 2), -thick / 2, 0), floor, Enum.Material.Concrete)
	end

	-- The pit: dark walls going down, an orange glow at the bottom and a glowing strip
	-- just under the floor's edge.
	local pitDepth = cfg.SinkDepth + 3
	local wallColor = Color3.fromRGB(40, 40, 44)
	for _, side in { -1, 1 } do
		part("PitWall", Vector3.new(pitHalf * 2, pitDepth, 0.5), CFrame.new(0, -pitDepth / 2, side * (pitHalf + 0.25)), wallColor, Enum.Material.Metal)
		part("PitWall", Vector3.new(0.5, pitDepth, pitHalf * 2), CFrame.new(side * (pitHalf + 0.25), -pitDepth / 2, 0), wallColor, Enum.Material.Metal)
		neon("PitGlow", Vector3.new(pitHalf * 2, 0.4, 0.2), CFrame.new(0, -1.3, side * (pitHalf - 0.05)), cfg.NeonOrange)
		neon("PitGlow", Vector3.new(0.2, 0.4, pitHalf * 2), CFrame.new(side * (pitHalf - 0.05), -1.3, 0), cfg.NeonOrange)
	end
	local bottom = neon("PitBottom", Vector3.new(pitHalf * 2, 0.4, pitHalf * 2), CFrame.new(0, -pitDepth, 0), cfg.NeonOrange)
	light(bottom, cfg.NeonOrange, 22, 3)

	-- Yellow and black stripes around the pit.
	local stripe = 1.6
	local band = 1.4
	local outer = pitHalf + band
	for _, sideInfo in { { Along = "X", Sign = -1 }, { Along = "X", Sign = 1 }, { Along = "Z", Sign = -1 }, { Along = "Z", Sign = 1 } } do
		local length = outer * 2
		local count = math.floor(length / stripe)
		for index = 1, count do
			local offset = -length / 2 + (index - 0.5) * length / count
			local color = if index % 2 == 0 then Config.Style.HazardBlack else Config.Style.HazardYellow
			local middle = pitHalf + band / 2
			if sideInfo.Along == "X" then
				part("Stripe", Vector3.new(length / count, 0.06, band), CFrame.new(offset, 0.03, sideInfo.Sign * middle), color)
			elseif math.abs(offset) < pitHalf then
				part("Stripe", Vector3.new(band, 0.06, length / count), CFrame.new(sideInfo.Sign * middle, 0.03, offset), color)
			end
		end
	end

	-- Big yellow arrows on the floor pointing at the turntable from both sides, and from the front.
	local function arrow(at: Vector3, toward: Vector3)
		local frame = CFrame.lookAt(at, Vector3.new(toward.X, at.Y, toward.Z))
		part("Arrow", Vector3.new(2, 0.06, 6), frame * CFrame.new(0, 0, 1), cfg.NeonYellow)
		for _, sign in { -1, 1 } do
			part("ArrowHead", Vector3.new(1.8, 0.07, 5), frame * CFrame.new(sign * 1.5, 0, -2.6) * CFrame.Angles(0, sign * math.rad(40), 0), cfg.NeonYellow)
		end
	end
	for _, side in { -1, 1 } do
		arrow(Vector3.new(side * (outer + 9), 0.04, 0), Vector3.zero)
		arrow(Vector3.new(side * (outer + 9), 0.04, -12), Vector3.new(0, 0, -12))
	end
end

-- The turntable: a dark plate with a glowing yellow rim, an orange ring on top, and a few
-- marks so you can see it turn. Its parts are remembered so update() can turn and sink it.
local function buildTurntable(radius: number)
	local cfg = Config.Garage
	local center = CFrame.new(0, 0, 0)
	local pieces: { Part } = {
		disc("Rim", radius + 0.5, 0.7, PLATE_TOP - 0.55, cfg.NeonYellow, Enum.Material.Neon),
		disc("Plate", radius, 0.8, PLATE_TOP - 0.4, Color3.fromRGB(55, 56, 62), Enum.Material.DiamondPlate),
		disc("Ring", radius * 0.62, 0.06, PLATE_TOP + 0.01, cfg.NeonOrange, Enum.Material.Neon),
		disc("RingInside", radius * 0.62 - 0.6, 0.06, PLATE_TOP + 0.02, Color3.fromRGB(55, 56, 62), Enum.Material.DiamondPlate),
		disc("Column", radius * 0.4, cfg.SinkDepth + 2, PLATE_TOP - 0.8 - (cfg.SinkDepth + 2) / 2, Color3.fromRGB(45, 45, 50), Enum.Material.Metal),
	}
	for index = 0, 3 do
		table.insert(pieces, part("Mark", Vector3.new(0.5, 0.06, radius * 0.3), CFrame.Angles(0, index * math.pi / 2, 0) * CFrame.new(0, PLATE_TOP + 0.02, -radius * 0.8), cfg.NeonYellow, Enum.Material.Neon))
	end
	for _, piece in pieces do
		if piece.Material == Enum.Material.Neon then
			piece.CastShadow = false
		end
		table.insert(turntable, { Part = piece, Offset = (origin * center):ToObjectSpace(piece.CFrame) })
	end
	light(pieces[1], cfg.NeonYellow, 16, 1.5)
end

-- A warning beacon on a post, glowing yellow (its light pulses in update()).
local function beacon(x: number, z: number)
	local cfg = Config.Garage
	part("BeaconPost", Vector3.new(0.8, 4, 0.8), CFrame.new(x, 2, z), Color3.fromRGB(60, 60, 64), Enum.Material.Metal)
	part("BeaconBase", Vector3.new(1.6, 0.5, 1.6), CFrame.new(x, 4.2, z), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	local glow = neon("Beacon", Vector3.new(1.3, 1.3, 1.3), CFrame.new(x, 5.1, z), cfg.NeonYellow)
	table.insert(beaconLights, light(glow, cfg.NeonYellow, 18, 2))
end

-- A vent in the floor that puffs steam now and then (and a lot when a truck rises).
local function vent(x: number, z: number)
	part("Vent", Vector3.new(2.4, 0.08, 2.4), CFrame.new(x, 0.04, z), Color3.fromRGB(35, 35, 38), Enum.Material.DiamondPlate)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
	emitter.LightEmission = 0.2
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Rate = 2
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.EmissionDirection = Enum.NormalId.Top
	local holder = part("SteamHolder", Vector3.new(1, 0.1, 1), CFrame.new(x, 0.1, z), WHITE)
	holder.Transparency = 1
	emitter.Parent = holder
	table.insert(vents, emitter)
end

-- A big wooden door on the back wall with a frame and an X brace.
local function bigDoor(x: number, width: number, height: number)
	local style = Config.Style
	local z = BACK_Z - 0.3
	part("Door", Vector3.new(width, height, 0.5), CFrame.new(x, height / 2, z), style.Wood:Lerp(Color3.new(0, 0, 0), 0.1), Enum.Material.WoodPlanks)
	local dark = style.DarkWood
	for _, y in { 0.4, height - 0.4 } do
		part("DoorFrame", Vector3.new(width + 0.6, 0.8, 0.4), CFrame.new(x, y, z - 0.35), dark, Enum.Material.Wood)
	end
	for _, side in { -1, 1 } do
		part("DoorFrame", Vector3.new(0.8, height, 0.4), CFrame.new(x + side * width / 2, height / 2, z - 0.35), dark, Enum.Material.Wood)
	end
	local diagonal = math.sqrt(width * width + height * height) - 1.5
	local tilt = math.atan2(height, width)
	for _, sign in { -1, 1 } do
		part("DoorBrace", Vector3.new(diagonal, 0.7, 0.3), CFrame.new(x, height / 2, z - 0.4) * CFrame.Angles(0, 0, sign * tilt), dark, Enum.Material.Wood)
	end
end

-- A wall clock: a white face with a dark rim and two hands.
local function clock(at: Vector3)
	local frame = CFrame.new(at) * CFrame.Angles(0, math.pi / 2, 0) -- the round sides face along Z
	local rim = part("ClockRim", Vector3.new(0.4, 4.6, 4.6), frame, Config.Style.DarkWood, Enum.Material.Wood)
	rim.Shape = Enum.PartType.Cylinder
	local face = part("ClockFace", Vector3.new(0.45, 4, 4), frame * CFrame.new(0.02, 0, 0), Color3.fromRGB(245, 240, 225))
	face.Shape = Enum.PartType.Cylinder
	local dark = Color3.fromRGB(30, 30, 30)
	part("HourHand", Vector3.new(0.25, 1.2, 0.1), CFrame.new(at + Vector3.new(0.3, 0.3, -0.3)) * CFrame.Angles(0, 0, math.rad(-60)), dark)
	part("MinuteHand", Vector3.new(0.18, 1.7, 0.1), CFrame.new(at + Vector3.new(0, 0.8, -0.32)), dark)
end

-- A brown pegboard with tool shapes hanging on it.
local function toolBoard(at: Vector3)
	local style = Config.Style
	part("ToolBoard", Vector3.new(10, 6, 0.3), CFrame.new(at), Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
	local metal = style.Metal
	local tools = {
		{ Size = Vector3.new(0.4, 3, 0.2), At = Vector3.new(-3.6, 0.3, -0.25), Color = metal }, -- a wrench
		{ Size = Vector3.new(1.2, 0.6, 0.2), At = Vector3.new(-3.6, 1.8, -0.25), Color = metal },
		{ Size = Vector3.new(0.4, 2.6, 0.2), At = Vector3.new(-1.6, 0, -0.25), Color = style.Wood }, -- a hammer
		{ Size = Vector3.new(1.6, 0.7, 0.25), At = Vector3.new(-1.6, 1.4, -0.27), Color = metal },
		{ Size = Vector3.new(0.3, 3.2, 0.2), At = Vector3.new(0.4, 0.2, -0.25), Color = Color3.fromRGB(200, 60, 50) }, -- a screwdriver
		{ Size = Vector3.new(2.6, 1.6, 0.2), At = Vector3.new(3, 0.6, -0.25), Color = metal }, -- a saw
		{ Size = Vector3.new(0.6, 1.6, 0.25), At = Vector3.new(4.5, 0.6, -0.27), Color = style.Wood },
	}
	for _, tool in tools do
		part("Tool", tool.Size, CFrame.new(at + tool.At), tool.Color, Enum.Material.Metal)
	end
end

-- A red tool chest with drawers.
local function toolChest(at: Vector3)
	local red = Color3.fromRGB(205, 45, 40)
	part("ToolChest", Vector3.new(6, 5, 3), CFrame.new(at + Vector3.new(0, 2.5, 0)), red, Enum.Material.Metal)
	for index = 1, 4 do
		part("Drawer", Vector3.new(5.4, 0.12, 0.1), CFrame.new(at + Vector3.new(0, index * 1.05, -1.55)), Color3.fromRGB(120, 25, 25), Enum.Material.Metal)
		part("Handle", Vector3.new(1.6, 0.2, 0.2), CFrame.new(at + Vector3.new(0, index * 1.05 - 0.4, -1.6)), Config.Style.Metal, Enum.Material.Metal)
	end
end

-- A stack of tyres lying flat.
local function tyres(at: Vector3, count: number)
	for index = 1, count do
		local y = (index - 0.5) * 1.3
		local tyre = part("Tyre", Vector3.new(1.3, 4, 4), CFrame.new(at + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2), TYRE, Enum.Material.Fabric)
		tyre.Shape = Enum.PartType.Cylinder
	end
end

-- The back wall: logs, doors, lights, clock, tool board, tool chest and tyres. And plain log
-- side walls, so the camera never sees past the room.
local function buildWalls()
	local style = Config.Style
	local index = 0
	local y = 0
	while y < WALL_HEIGHT do
		local color = if index % 2 == 0 then style.Wood else style.Wood:Lerp(Color3.new(0, 0, 0), 0.1)
		part("Log", Vector3.new(ROOM_HALF_WIDTH * 2, LOG, 1.6), CFrame.new(0, y + LOG / 2, BACK_Z + 0.8), color, Enum.Material.Wood)
		for _, side in { -1, 1 } do
			part("Log", Vector3.new(1.6, LOG, BACK_Z - FRONT_Z), CFrame.new(side * (ROOM_HALF_WIDTH + 0.8), y + LOG / 2, (BACK_Z + FRONT_Z) / 2), color, Enum.Material.Wood)
		end
		y += LOG
		index += 1
	end

	bigDoor(-15, 13, 16)
	bigDoor(15, 13, 16)

	-- A row of bright lights across the top of the wall.
	local cfg = Config.Garage
	for column = -3, 3 do
		local lamp = neon("Lamp", Vector3.new(4, 0.6, 0.8), CFrame.new(column * 12, 26, BACK_Z - 0.5), cfg.LightColor)
		light(lamp, cfg.LightColor, 30, 1.2)
		part("LampHood", Vector3.new(4.6, 0.5, 1.4), CFrame.new(column * 12, 26.5, BACK_Z - 0.6), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
	end

	clock(Vector3.new(0, 20, BACK_Z - 0.3))
	toolBoard(Vector3.new(-33, 9, BACK_Z - 0.2))
	toolChest(Vector3.new(32, 0, BACK_Z - 2))
	tyres(Vector3.new(-44, 0, BACK_Z - 3), 4)
	tyres(Vector3.new(44, 0, BACK_Z - 3), 3)
	tyres(Vector3.new(40, 0, BACK_Z - 7), 2)
end

-- Builds the showroom the first time it's needed.
function Showroom.build()
	if model then
		return
	end
	local cfg = Config.Garage
	origin = CFrame.new(cfg.ShowroomPosition)
	local newModel = Instance.new("Model")
	newModel.Name = "GarageShowroom"
	model = newModel
	local radius = cfg.TurntableRadius
	buildFloor(radius + 1.5)
	buildTurntable(radius)
	for _, side in { -1, 1 } do
		beacon(side * (radius + 6), -radius - 2)
		vent(side * (radius + 4), radius + 3)
		vent(side * (radius + 14), -4)
	end
	buildWalls()
	newModel.Parent = workspace
end

-- Where GarageController's camera stands, and the spot it looks at.
function Showroom.cameraCFrame(): CFrame
	local cfg = Config.Garage
	local eye = origin * cfg.CameraOffset
	return CFrame.lookAt(eye, origin * cfg.CameraLookAt)
end

local function placeTruck(look: Types.TruckLook, name: string)
	if truckModel then
		truckModel:Destroy()
	end
	table.clear(truckParts)
	local truck = TruckBuilder.build(look, name)
	local pivot = truck:GetPivot() -- on the ground in its middle
	for _, piece in truck:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CanQuery = false
			piece.CanTouch = false
			table.insert(truckParts, { Part = piece, Offset = pivot:ToObjectSpace(piece.CFrame) })
		end
	end
	truck.Parent = model
	truckModel = truck
end

local function puff(amount: number)
	for _, emitter in vents do
		emitter:Emit(amount)
	end
end

-- Show this truck on the turntable. With `animate`, the turntable sinks into the pit first,
-- the truck is swapped at the bottom, and it rises again with a puff of steam.
function Showroom.show(look: Types.TruckLook, name: string, animate: boolean)
	if not animate or not truckModel then
		placeTruck(look, name)
		phase = "Idle"
		return
	end
	nextLook = look
	nextName = name
	if phase == "Idle" then
		phase = "Sinking"
		phaseStart = os.clock()
	elseif phase == "Rising" then
		-- Sink again from where it is now, so it doesn't jump.
		local cfg = Config.Garage
		local risen = math.clamp((os.clock() - phaseStart) / cfg.RiseTime, 0, 1)
		phase = "Sinking"
		phaseStart = os.clock() - (1 - risen) * cfg.SinkTime
	end
end

-- Move everything for this frame: the turning, the sinking and rising, and the beacons.
function Showroom.update(dt: number)
	if not model then
		return
	end
	local cfg = Config.Garage
	local now = os.clock()
	angle = (angle + cfg.TurnSpeed * dt) % (math.pi * 2)

	local depth = 0
	if phase == "Sinking" then
		local t = math.clamp((now - phaseStart) / cfg.SinkTime, 0, 1)
		depth = cfg.SinkDepth * t * t -- speeds up as it drops
		if t >= 1 then
			local look = nextLook
			if look then
				placeTruck(look, nextName)
				nextLook = nil
			end
			phase = "Rising"
			phaseStart = now
		end
	elseif phase == "Rising" then
		local t = math.clamp((now - phaseStart) / cfg.RiseTime, 0, 1)
		depth = cfg.SinkDepth * (1 - t) * (1 - t) -- slows down as it arrives
		if t >= 1 then
			phase = "Idle"
			depth = 0
			puff(12)
		end
	end

	local center = origin * CFrame.new(0, -depth, 0)
	local spin = center * CFrame.Angles(0, angle, 0)
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for _, info in turntable do
		table.insert(parts, info.Part)
		table.insert(cframes, spin * info.Offset)
	end
	local onPlate = spin * CFrame.new(0, PLATE_TOP, 0)
	for _, info in truckParts do
		table.insert(parts, info.Part)
		table.insert(cframes, onPlate * info.Offset)
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

	-- The beacons pulse.
	local pulse = 1.5 + math.sin(now * 6) * 1.2
	for _, glow in beaconLights do
		glow.Brightness = pulse
	end
end

return Showroom
