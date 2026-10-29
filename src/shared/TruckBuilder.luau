--!strict
-- Builds a blocky placeholder log truck from its look in Config.Trucks (see Types.TruckLook):
-- a cab with a hood, windows and lights, wheels on 2 to 4 axles, and a bed behind the cab
-- (wooden sides, stakes, a flatbed, a dump box, an army canvas or a load of logs).
-- Shared, so the Garage showroom (client) and driving (server, later) build the same trucks.
-- It's not a system, so it has no init()/start().

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local WIDTH = 6.4
local WHEEL_RADIUS = 1.35
local WHEEL_WIDTH = 1
local FRAME_TOP = 1.8 -- the top of the chassis, where the cab and bed sit
local TYRE = Color3.fromRGB(32, 32, 34)
local LIGHT = Color3.fromRGB(255, 240, 170)
local BARK = Color3.fromRGB(120, 75, 45)

local TruckBuilder = {}

local function part(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = model
	return piece
end

-- A wedge: its slope faces its front (-Z), tall at the back.
local function wedge(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3)
	local piece = Instance.new("WedgePart")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	piece.Parent = model
end

-- Where the axles are along the truck (Z), front first.
local function axlePositions(look: Types.TruckLook): { number }
	local front = -look.Length / 2 + 2
	local back = look.Length / 2 - 2.2
	local gap = WHEEL_RADIUS * 2 + 0.5
	if look.Axles <= 2 then
		return { front, back }
	elseif look.Axles == 3 then
		return { front, back - gap, back }
	end
	return { front, front + gap, back - gap, back }
end

local function buildWheels(model: Model, look: Types.TruckLook)
	for _, z in axlePositions(look) do
		for _, side in { -1, 1 } do
			local x = side * (WIDTH / 2 - WHEEL_WIDTH / 2)
			-- A cylinder's round sides face along its X axis, which is the axle's direction already.
			local tyre = part(model, "Wheel", Vector3.new(WHEEL_WIDTH, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2), CFrame.new(x, WHEEL_RADIUS, z), TYRE, Enum.Material.Fabric)
			tyre.Shape = Enum.PartType.Cylinder
			local hub = part(model, "Hub", Vector3.new(WHEEL_WIDTH + 0.1, WHEEL_RADIUS, WHEEL_RADIUS), CFrame.new(x, WHEEL_RADIUS, z), look.Trim, Enum.Material.Metal)
			hub.Shape = Enum.PartType.Cylinder
		end
	end
end

-- The hood and cab at the front (-Z). Returns where the cab ends (Z), so the bed starts there.
local function buildCab(model: Model, look: Types.TruckLook): number
	local front = -look.Length / 2
	local window = Config.Style.Window

	part(model, "Bumper", Vector3.new(WIDTH, 0.7, 0.5), CFrame.new(0, 1.3, front + 0.25), look.Trim, Enum.Material.Metal)
	local hoodLength = 2.6
	local hoodHeight = if look.Rounded then 1.1 else 1.6
	local hoodZ = front + 0.5 + hoodLength / 2
	part(model, "Hood", Vector3.new(WIDTH - 0.6, hoodHeight, hoodLength), CFrame.new(0, FRAME_TOP + hoodHeight / 2, hoodZ), look.Cab)
	if look.Rounded then
		-- An old truck: the hood slopes down to the front, and the front fenders are rounded.
		wedge(model, "HoodSlope", Vector3.new(WIDTH - 0.6, 0.6, hoodLength), CFrame.new(0, FRAME_TOP + hoodHeight + 0.3, hoodZ), look.Cab)
	end
	part(model, "Grille", Vector3.new(WIDTH - 2.4, hoodHeight * 0.7, 0.1), CFrame.new(0, FRAME_TOP + hoodHeight / 2, front + 0.45), look.Trim, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		local light = part(model, "Headlight", Vector3.new(0.7, 0.5, 0.1), CFrame.new(side * (WIDTH / 2 - 0.9), FRAME_TOP + hoodHeight * 0.6, front + 0.44), LIGHT, Enum.Material.Neon)
		light.CastShadow = false
	end

	local cabLength = if look.Sleeper then 4 else 2.8
	local cabHeight = if look.Sleeper then 4.6 else 3.4
	local cabFront = front + 0.5 + hoodLength
	local cabZ = cabFront + cabLength / 2
	part(model, "Cab", Vector3.new(WIDTH - 0.4, cabHeight, cabLength), CFrame.new(0, FRAME_TOP + cabHeight / 2, cabZ), look.Cab)
	local glassY = FRAME_TOP + cabHeight - 1.1
	part(model, "Windshield", Vector3.new(WIDTH - 1.4, 1.3, 0.1), CFrame.new(0, glassY, cabFront - 0.05), window, Enum.Material.Glass)
	for _, side in { -1, 1 } do
		local x = side * ((WIDTH - 0.4) / 2 + 0.05)
		part(model, "SideWindow", Vector3.new(0.1, 1.2, math.min(1.6, cabLength - 0.8)), CFrame.new(x, glassY, cabFront + 0.9), window, Enum.Material.Glass)
		part(model, "Mirror", Vector3.new(0.3, 0.8, 0.5), CFrame.new(side * (WIDTH / 2 + 0.25), glassY, cabFront + 0.2), look.Trim, Enum.Material.Metal)
		-- Fenders over the front wheels.
		part(model, "Fender", Vector3.new(WHEEL_WIDTH + 0.2, 0.3, WHEEL_RADIUS * 2 + 0.6), CFrame.new(side * (WIDTH / 2 - WHEEL_WIDTH / 2), WHEEL_RADIUS * 2 + 0.15, front + 2), look.Cab)
	end
	if look.Rounded then
		wedge(model, "RoofCurve", Vector3.new(WIDTH - 0.4, 0.5, 0.6), CFrame.new(0, FRAME_TOP + cabHeight + 0.25, cabFront + 0.3), look.Cab)
	end
	if look.Sleeper then
		-- A big rig: a visor over the windshield and two tall exhaust stacks behind the cab.
		part(model, "Visor", Vector3.new(WIDTH - 0.4, 0.3, 0.8), CFrame.new(0, FRAME_TOP + cabHeight + 0.1, cabFront + 0.1), look.Trim, Enum.Material.Metal)
		for _, side in { -1, 1 } do
			local stack = part(model, "Stack", Vector3.new(5.5, 0.5, 0.5), CFrame.new(side * (WIDTH / 2 - 0.3), FRAME_TOP + 2.75, cabFront + cabLength + 0.3) * CFrame.Angles(0, 0, math.pi / 2), look.Trim, Enum.Material.Metal)
			stack.Shape = Enum.PartType.Cylinder
		end
	end
	return cabFront + cabLength + 0.4
end

-- A log with light ends (blocky, like every log in the game).
local function log(model: Model, size: Vector3, cframe: CFrame)
	part(model, "Log", size, cframe, BARK, Enum.Material.Wood)
	for _, side in { -1, 1 } do
		part(model, "LogEnd", Vector3.new(size.X - 0.3, size.Y - 0.3, 0.05), cframe * CFrame.new(0, 0, side * size.Z / 2), Config.Style.InnerWood)
	end
end

-- Posts along both sides of the bed, `height` tall, with `slats` rails between them.
local function stakes(model: Model, startZ: number, endZ: number, height: number, slats: number, postColor: Color3, slatColor: Color3)
	local length = endZ - startZ
	local middle = (startZ + endZ) / 2
	local posts = math.max(math.floor(length / 1.8), 2)
	local baseY = FRAME_TOP + 0.4
	for _, side in { -1, 1 } do
		local x = side * (WIDTH / 2 - 0.4)
		for index = 0, posts do
			local z = startZ + 0.2 + index * (length - 0.4) / posts
			part(model, "Stake", Vector3.new(0.35, height, 0.35), CFrame.new(x, baseY + height / 2, z), postColor, Enum.Material.Wood)
		end
		for slat = 1, slats do
			local y = baseY + height * slat / (slats + 0.5)
			part(model, "Slat", Vector3.new(0.25, 0.35, length - 0.2), CFrame.new(x, y, middle), slatColor, Enum.Material.WoodPlanks)
		end
	end
	-- A headboard behind the cab.
	part(model, "Headboard", Vector3.new(WIDTH - 0.8, height, 0.3), CFrame.new(0, baseY + height / 2, startZ + 0.15), slatColor, Enum.Material.WoodPlanks)
end

-- Rows of logs lying along the bed: `rows` is how many logs in each row, bottom row first.
local function logPile(model: Model, startZ: number, endZ: number, rows: { number })
	local size = 1.6
	local length = endZ - startZ - 0.6
	local middle = (startZ + endZ) / 2
	for row, count in rows do
		for index = 1, count do
			local x = (index - (count + 1) / 2) * (size + 0.1)
			local y = FRAME_TOP + 0.4 + size / 2 + (row - 1) * size
			log(model, Vector3.new(size, size, length), CFrame.new(x, y, middle))
		end
	end
end

local function buildBed(model: Model, look: Types.TruckLook, startZ: number)
	local endZ = look.Length / 2 - 0.2
	local length = endZ - startZ
	local middle = (startZ + endZ) / 2
	local floorY = FRAME_TOP + 0.2
	local wood = Config.Style.Wood
	local bed = look.Bed

	local deckColor = if bed == "LogTrailer" then look.Body else wood
	part(model, "BedFloor", Vector3.new(WIDTH - 0.4, 0.4, length), CFrame.new(0, floorY, middle), deckColor, if bed == "LogTrailer" then Enum.Material.Metal else Enum.Material.WoodPlanks)

	if bed == "Wood" then
		for _, side in { -1, 1 } do
			part(model, "BedSide", Vector3.new(0.3, 1.1, length), CFrame.new(side * (WIDTH / 2 - 0.35), floorY + 0.75, middle), look.Body, Enum.Material.WoodPlanks)
		end
		part(model, "Tailgate", Vector3.new(WIDTH - 0.4, 1.1, 0.3), CFrame.new(0, floorY + 0.75, endZ - 0.15), look.Body, Enum.Material.WoodPlanks)
	elseif bed == "Stakes" then
		stakes(model, startZ, endZ, 2.4, 2, Config.Style.DarkWood, look.Body)
	elseif bed == "Flatbed" then
		stakes(model, startZ, endZ, 1.2, 0, Config.Style.DarkWood, look.Body)
	elseif bed == "TallStakes" then
		stakes(model, startZ, endZ, 3.8, 3, Config.Style.DarkWood, look.Body)
	elseif bed == "Dump" then
		local height = 2.8
		part(model, "DumpBox", Vector3.new(WIDTH - 0.4, height, length), CFrame.new(0, floorY + height / 2, middle), look.Body, Enum.Material.Metal)
		part(model, "DumpInside", Vector3.new(WIDTH - 1, 0.05, length - 0.6), CFrame.new(0, floorY + height + 0.01, middle), Color3.fromRGB(70, 70, 74), Enum.Material.Metal)
		for index = 0, 3 do
			local z = startZ + 0.4 + index * (length - 0.8) / 3
			for _, side in { -1, 1 } do
				part(model, "Rib", Vector3.new(0.2, height, 0.35), CFrame.new(side * (WIDTH / 2 - 0.15), floorY + height / 2, z), look.Trim, Enum.Material.Metal)
			end
		end
	elseif bed == "Canvas" then
		local height = 3.4
		part(model, "Canvas", Vector3.new(WIDTH - 0.4, height, length), CFrame.new(0, floorY + height / 2, middle), look.Body, Enum.Material.Fabric)
		for index = 0, 3 do
			local z = startZ + 0.4 + index * (length - 0.8) / 3
			part(model, "Hoop", Vector3.new(WIDTH - 0.2, 0.25, 0.3), CFrame.new(0, floorY + height + 0.05, z), look.Trim, Enum.Material.Fabric)
		end
	elseif bed == "LogTrailer" then
		-- Bolsters (posts on both sides) holding a load of logs.
		for index = 0, 2 do
			local z = startZ + 0.6 + index * (length - 1.2) / 2
			for _, side in { -1, 1 } do
				part(model, "Bolster", Vector3.new(0.4, 3.6, 0.4), CFrame.new(side * (WIDTH / 2 - 0.3), floorY + 1.8, z), look.Trim, Enum.Material.Metal)
			end
		end
		logPile(model, startZ, endZ, { 3, 2 })
	elseif bed == "LogBed" then
		stakes(model, startZ, endZ, 5, 2, look.Trim, look.Body)
		logPile(model, startZ, endZ, { 3, 3, 2 })
	end
end

-- Build the truck for `look`: its front points along -Z, its wheels stand on Y = 0 and its
-- middle is at X = 0, Z = 0 (all scaled by look.Scale). Every part is anchored and can't be
-- bumped into; move it with Model:PivotTo.
function TruckBuilder.build(look: Types.TruckLook, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local chassis = part(model, "Chassis", Vector3.new(WIDTH - 1.6, 0.7, look.Length - 1), CFrame.new(0, FRAME_TOP - 0.35, 0), Color3.fromRGB(45, 45, 48), Enum.Material.Metal)
	model.PrimaryPart = chassis
	buildWheels(model, look)
	local bedStart = buildCab(model, look)
	buildBed(model, look, bedStart)
	model.WorldPivot = CFrame.identity
	if look.Scale ~= 1 then
		model:ScaleTo(look.Scale)
	end
	return model
end

return TruckBuilder
