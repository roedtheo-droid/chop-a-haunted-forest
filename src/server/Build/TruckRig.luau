--!strict
-- Turns a truck from Shared/TruckBuilder (the same one the Garage shows) into one you can
-- drive. TruckManager calls TruckRig.make while the truck is still anchored at the origin,
-- then moves it into place and lets go (TruckRig.release).
--   * the cab, bed and everything else is welded to the chassis
--   * an invisible box around the body is what bumps into things
--   * each wheel turns on a hinge with a motor; the front wheels (the first two axles on an
--     8x8) sit on a steering hinge that turns them left and right
--   * a VehicleSeat in the cab (you get in with its "Drive" prompt, see TruckManager)
--   * a spot behind the bed for the "Load logs" prompt
-- The decorative load of logs the Garage shows on some trucks is taken off: the real load is
-- drawn by TruckManager. It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local TruckRig = {}

export type Rig = {
	Model: Model,
	Chassis: BasePart,
	Body: BasePart, -- the invisible box that bumps into things
	Seat: VehicleSeat,
	BedFloor: BasePart, -- the load of logs is drawn on top of it
	LoadPoint: BasePart, -- behind the bed, for the "Load logs" prompt
	Motors: { HingeConstraint },
	Steering: { HingeConstraint },
	WheelRadius: number,
}

local SPIN = CFrame.identity -- an attachment whose X axis runs along the axle
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- an attachment whose X axis points up

local function attach(part: BasePart, at: Vector3, turn: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.CFrame = part.CFrame:ToObjectSpace(CFrame.new(at) * turn)
	attachment.Parent = part
	return attachment
end

local function weld(root: BasePart, part: BasePart)
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = root
	joint.Part1 = part
	joint.Parent = part
end

local function hinge(name: string, from: Attachment, to: Attachment, parent: Instance): HingeConstraint
	local joint = Instance.new("HingeConstraint")
	joint.Name = name
	joint.Attachment0 = from
	joint.Attachment1 = to
	joint.Parent = parent
	return joint
end

-- Build the rig on `model` (a fresh TruckBuilder truck, still at the origin and anchored).
function TruckRig.make(model: Model, look: Types.TruckLook, speed: number): Rig
	local cfg = Config.Truck
	local chassis = model.PrimaryPart :: BasePart
	local scale = look.Scale

	-- Take the decorative load off (the real one is drawn by TruckManager).
	for _, child in model:GetChildren() do
		if child.Name == "Log" or child.Name == "LogEnd" then
			child:Destroy()
		end
	end

	local wheels: { BasePart } = {}
	local hubs: { BasePart } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			if child.Name == "Wheel" then
				table.insert(wheels, child)
			elseif child.Name == "Hub" then
				table.insert(hubs, child)
			end
		end
	end

	-- The invisible box around the body, from just under the chassis to the top of the cab.
	local _, size = model:GetBoundingBox()
	local bottom = chassis.Position.Y - chassis.Size.Y / 2
	local top = size.Y
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(size.X - 2.4 * scale, top - bottom, size.Z)
	body.CFrame = CFrame.new(0, (top + bottom) / 2, 0)
	body.Transparency = 1
	body.CanCollide = true
	body.Anchored = true
	body.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.3, 0)
	body.Parent = model

	-- Weld everything that isn't a wheel to the chassis. Only the body box and the chassis
	-- have weight, so the truck doesn't wobble from its details.
	local bedFloor: BasePart? = nil
	local cab: BasePart? = nil
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= chassis and child.Name ~= "Wheel" and child.Name ~= "Hub" then
			weld(chassis, child)
			if child ~= body then
				child.Massless = true
				child.CanCollide = false
			end
			if child.Name == "BedFloor" then
				bedFloor = child
			elseif child.Name == "Cab" then
				cab = child
			end
		end
	end
	assert(bedFloor and cab, "A truck needs a BedFloor and a Cab")

	-- Wheels: grippy, and each one turns on a motor hinge. The front axle (the first two on
	-- an 8x8) also steers: its wheels sit on a knuckle that turns on an upright hinge.
	local axles: { number } = {}
	for _, wheel in wheels do
		local z = math.round(wheel.Position.Z * 100) / 100
		if not table.find(axles, z) then
			table.insert(axles, z)
		end
	end
	table.sort(axles) -- front (most -Z) first
	local steeringAxles = if look.Axles >= 4 then 2 else 1

	local motors: { HingeConstraint } = {}
	local steering: { HingeConstraint } = {}
	local radius = 1
	for _, wheel in wheels do
		radius = wheel.Size.Y / 2
		wheel.CanCollide = true
		wheel.CustomPhysicalProperties = PhysicalProperties.new(0.9, cfg.WheelFriction, 0, 100, 1)
		for _, hub in hubs do
			if (hub.Position - wheel.Position).Magnitude < 0.01 then
				weld(wheel, hub)
				hub.Massless = true
				hub.CanCollide = false
			end
		end
		local noBump = Instance.new("NoCollisionConstraint")
		noBump.Part0 = body
		noBump.Part1 = wheel
		noBump.Parent = wheel

		local at = wheel.Position
		local axle = table.find(axles, math.round(at.Z * 100) / 100) or 99
		local holder: BasePart = chassis
		if axle <= steeringAxles then
			local knuckle = Instance.new("Part")
			knuckle.Name = "Knuckle"
			knuckle.Size = Vector3.new(0.4, 0.4, 0.4) * scale
			knuckle.CFrame = CFrame.new(at)
			knuckle.Transparency = 1
			knuckle.CanCollide = false
			knuckle.Anchored = true
			knuckle.Parent = model
			local steer = hinge("Steer", attach(chassis, at, UPRIGHT), attach(knuckle, at, UPRIGHT), knuckle)
			steer.ActuatorType = Enum.ActuatorType.Servo
			steer.ServoMaxTorque = math.huge
			steer.AngularSpeed = cfg.SteerSpeed
			steer.LimitsEnabled = true
			steer.LowerAngle = -cfg.SteerAngle
			steer.UpperAngle = cfg.SteerAngle
			table.insert(steering, steer)
			holder = knuckle
			local noKnuckleBump = Instance.new("NoCollisionConstraint")
			noKnuckleBump.Part0 = knuckle
			noKnuckleBump.Part1 = wheel
			noKnuckleBump.Parent = knuckle
		end
		local motor = hinge("Motor", attach(holder, at, SPIN), attach(wheel, at, SPIN), wheel)
		motor.ActuatorType = Enum.ActuatorType.Motor
		motor.MotorMaxTorque = cfg.MotorTorque * scale
		motor.AngularVelocity = 0
		table.insert(motors, motor)
	end

	-- The seat, in the middle of the cab.
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 0.6, 2) * scale
	seat.CFrame = CFrame.new(0, cab.Position.Y - cab.Size.Y / 2 + 0.6 * scale, cab.Position.Z)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = false -- you get in with the Drive prompt, not by bumping into it
	seat.Massless = true
	seat.MaxSpeed = speed
	seat.HeadsUpDisplay = false
	seat.Anchored = true
	seat.Parent = model
	weld(chassis, seat)

	-- The spot behind the bed where the "Load logs" prompt is.
	local loadPoint = Instance.new("Part")
	loadPoint.Name = "LoadPoint"
	loadPoint.Size = Vector3.one
	loadPoint.CFrame = CFrame.new(0, bedFloor.Position.Y + 1, bedFloor.Position.Z + bedFloor.Size.Z / 2 + 0.6)
	loadPoint.Transparency = 1
	loadPoint.CanCollide = false
	loadPoint.CanQuery = false
	loadPoint.Massless = true
	loadPoint.Anchored = true
	loadPoint.Parent = model
	weld(chassis, loadPoint)

	return {
		Model = model,
		Chassis = chassis,
		Body = body,
		Seat = seat,
		BedFloor = bedFloor,
		LoadPoint = loadPoint,
		Motors = motors,
		Steering = steering,
		WheelRadius = radius,
	}
end

-- Unanchor everything, once the truck stands where it should.
function TruckRig.release(rig: Rig)
	for _, part in rig.Model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
end

return TruckRig
