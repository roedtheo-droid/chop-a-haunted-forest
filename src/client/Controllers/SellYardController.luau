--!strict
-- The sell yards' moving parts, drawn on your own computer (only for looks):
--   * when anyone sells, their logs drop onto the DROP LOGS pad one by one, slide across it,
--     ride the conveyor up into the chipper and disappear in a puff of wood chips
--     (the server already paid the coins; it just sends LogsSold so everyone sees it)
--   * the yellow arrow under each floating SELL LOGS billboard bobs up and down
-- Numbers are in Config.Sawmill.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Fx = require(ReplicatedStorage.Shared.Fx)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)

local LOG_COLOR = Color3.fromRGB(125, 80, 48)
local CHIP_LIFETIME = 0.8

type Rider = {
	Part: BasePart,
	Started: number, -- os.clock() when it appeared
	Points: { Vector3 }, -- where it goes, in order
	Ends: { number }, -- seconds after Started that it reaches each point after the first
	Mouth: Vector3, -- the chipper's mouth: wood chips fly out here when it's eaten
}

local SellYardController = {}

local folder: Folder
local riders: { Rider } = {}

local function vectorAttribute(instance: Instance, name: string): Vector3?
	local value = instance:GetAttribute(name)
	return if typeof(value) == "Vector3" then value else nil
end

-- A little puff of wood chips flying out of the chipper's mouth.
local function chips(position: Vector3)
	local anchor = Fx.anchorAt(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Config.Style.InnerWood)
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.Lifetime = NumberRange.new(CHIP_LIFETIME * 0.6, CHIP_LIFETIME)
	emitter.Speed = NumberRange.new(4, 8)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.Enabled = false
	emitter.Parent = anchor
	emitter:Emit(6)
	Debris:AddItem(anchor, CHIP_LIFETIME + 0.3)
end

-- One log that drops onto the pad near `from`, slides to the conveyor and rides it in.
local function addRider(pad: BasePart, from: Vector3, beltStart: Vector3, beltEnd: Vector3, mouth: Vector3)
	local cfg = Config.Sawmill
	local logs = Config.Logs
	local lift = Vector3.new(0, 0.15 + logs.Thickness / 2, 0) -- from the belt's middle to a log lying on it

	-- Land on the pad under where they stood, a little scattered, never off its edge.
	local offset = pad.CFrame:PointToObjectSpace(from)
	local random = Random.new()
	local halfX, halfZ = pad.Size.X / 2 - 1, pad.Size.Z / 2 - 1
	local landing = pad.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(offset.X + random:NextNumber(-1.2, 1.2), -halfX, halfX),
		pad.Size.Y / 2 + logs.Thickness / 2,
		math.clamp(offset.Z + random:NextNumber(-1.2, 1.2), -halfZ, halfZ)
	))
	local points = { landing + Vector3.new(0, 3, 0), landing, beltStart + lift, beltEnd + lift, mouth }
	local speeds = { 0, cfg.SlideSpeed, cfg.BeltSpeed, cfg.BeltSpeed }
	local ends = {}
	local time = 0
	for index = 1, #points - 1 do
		time += if index == 1 then cfg.DropTime else (points[index + 1] - points[index]).Magnitude / speeds[index]
		table.insert(ends, time)
	end

	local part = Instance.new("Part")
	part.Name = "SoldLog"
	part.Size = Vector3.new(logs.Thickness, logs.Thickness, logs.Length) -- lying along its Z
	part.Color = LOG_COLOR
	part.Material = Enum.Material.Wood
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false -- so it never touches the pad
	part.CastShadow = false
	part.CFrame = CFrame.lookAt(points[1], points[3])
	part.Parent = folder
	table.insert(riders, { Part = part, Started = os.clock(), Points = points, Ends = ends, Mouth = mouth })
end

local function onSold(pad: unknown, count: unknown, from: unknown)
	-- The pad can be missing on your computer when it's far away (StreamingEnabled).
	if typeof(pad) ~= "Instance" or not pad:IsA("BasePart") or typeof(count) ~= "number" or typeof(from) ~= "Vector3" then
		return
	end
	local beltStart, beltEnd, mouth = vectorAttribute(pad, "BeltStart"), vectorAttribute(pad, "BeltEnd"), vectorAttribute(pad, "Mouth")
	if not (beltStart and beltEnd and mouth) then
		return
	end
	local shown = math.min(math.floor(count), Config.Sawmill.MaxShownLogs)
	for index = 1, shown do
		task.delay((index - 1) * Config.Sawmill.LogGap, addRider, pad, from, beltStart, beltEnd, mouth)
	end
end

-- Move every riding log along its path; eaten ones disappear in a puff of chips.
local function moveRiders()
	local now = os.clock()
	for index = #riders, 1, -1 do
		local rider = riders[index]
		local elapsed = now - rider.Started
		local ends = rider.Ends
		if elapsed >= ends[#ends] then
			rider.Part:Destroy()
			chips(rider.Mouth)
			table.remove(riders, index)
			continue
		end
		local leg = 1
		while elapsed > ends[leg] do
			leg += 1
		end
		local legStart = if leg == 1 then 0 else ends[leg - 1]
		local alpha = (elapsed - legStart) / (ends[leg] - legStart)
		local from, to = rider.Points[leg], rider.Points[leg + 1]
		local position = from:Lerp(to, alpha)
		-- Falling straight down it keeps facing the way it will slide.
		local ahead = if leg == 1 then rider.Points[3] else to
		local flat = Vector3.new(ahead.X - position.X, if leg >= 3 then ahead.Y - position.Y else 0, ahead.Z - position.Z)
		rider.Part.CFrame = if flat.Magnitude > 0.01 then CFrame.lookAt(position, position + flat) else rider.Part.CFrame.Rotation + position
	end
end

-- Bob the arrow under every SELL LOGS billboard.
local function bobArrows()
	local cfg = Config.Sawmill
	local offset = math.sin(os.clock() * cfg.ArrowBobSpeed) * cfg.ArrowBob / cfg.BillboardSize.Y
	for _, anchor in CollectionService:GetTagged(Tags.SellBillboard) do
		local gui = anchor:FindFirstChild("SellBillboard")
		local arrow = if gui then gui:FindFirstChild("Arrow") else nil
		if arrow and arrow:IsA("GuiObject") then
			arrow.Position = UDim2.fromScale(0.5, 0.66 + offset)
		end
	end
end

function SellYardController.init()
	folder = Instance.new("Folder")
	folder.Name = "SoldLogs"
	folder.Parent = workspace
end

function SellYardController.start()
	Remotes.getEvent("LogsSold").OnClientEvent:Connect(onSold)
	RunService.Heartbeat:Connect(function()
		moveRiders()
		bobArrows()
	end)
end

return SellYardController
