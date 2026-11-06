--!strict
-- The sell yards' moving parts, drawn on your own computer (only for looks):
--   * when anyone sells, their logs drop onto the pad one by one, slide across it, hop up the
--     chute and land in Gnawbert's mouth (the server already paid the coins; it just sends
--     LogsSold so everyone sees it)
--   * Gnawbert lifts its lid when a log is coming, snaps it shut on the log (wood chips and a
--     chomp), and when the last one is gone it burps up a cloud of coins
--   * the rest of the time it breathes and watches you, and it opens up if you come close with logs
-- Moving it here is smooth and sends nothing over the network, like the spinning saws.
-- Numbers are in Config.Sawmill and Config.Sawmill.Gnawbert.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Fx = require(ReplicatedStorage.Shared.Fx)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)

local cfg = Config.Sawmill
local look = cfg.Gnawbert
local LOG_COLOR = Color3.fromRGB(125, 80, 48)
local CHIP_LIFETIME = 0.8
-- The four legs of a log's trip: falling, sliding across the pad, hopping up the chute, into the mouth.
local HOP_LEG = 3
local LAST_LEG = 4

type Gnawbert = {
	Lid: Model,
	Pupils: Model?,
	Rest: CFrame, -- where its hinge is with the lid shut
	PupilsFromLid: CFrame?, -- where the pupils are from the hinge
	Mouth: Vector3,
	Angle: number, -- degrees the lid is open now
	Look: Vector3, -- how far the pupils are shifted now
	Coming: number, -- logs on their way to it
	NextBite: number?, -- when the next log arrives
	ChompedAt: number,
	Eaten: number, -- logs eaten since the last burp
	BurpAt: number?,
	BurpedAt: number,
}

type Rider = {
	Part: BasePart,
	Started: number, -- os.clock() when it appeared
	Points: { Vector3 }, -- where it goes, in order
	Ends: { number }, -- seconds after Started that it reaches each point after the first
	Mouth: Vector3, -- wood chips fly out here when it's eaten
	Eater: Gnawbert?, -- nil when it's too far away to be on this computer (StreamingEnabled)
}

local SellYardController = {}

local player = Players.LocalPlayer
local folder: Folder
local riders: { Rider } = {}
local gnawberts: { [Instance]: Gnawbert } = {}
local random = Random.new()

local function vectorAttribute(instance: Instance, name: string): Vector3?
	local value = instance:GetAttribute(name)
	return if typeof(value) == "Vector3" then value else nil
end

-- A little puff of wood chips flying out of Gnawbert's mouth.
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

-- A cloud of coins flying up and out of its mouth.
local function burpCoins(gnawbert: Gnawbert, count: number)
	local direction = gnawbert.Rest:VectorToWorldSpace(look.BurpDirection)
	local anchor = Fx.anchorAt(gnawbert.Mouth)
	anchor.WorldCFrame = CFrame.lookAt(gnawbert.Mouth, gnawbert.Mouth + direction)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Config.Style.Gold)
	emitter.Size = NumberSequence.new(look.CoinSize)
	emitter.LightEmission = 0.2
	emitter.Lifetime = NumberRange.new(look.CoinLife * 0.7, look.CoinLife)
	emitter.Speed = NumberRange.new(look.CoinSpeed * 0.7, look.CoinSpeed)
	emitter.SpreadAngle = Vector2.new(look.CoinSpread, look.CoinSpread)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Acceleration = Vector3.new(0, -look.CoinGravity, 0)
	emitter.Enabled = false
	emitter.Parent = anchor
	emitter:Emit(count)
	Debris:AddItem(anchor, look.CoinLife + 0.3)
end

-- The Gnawbert whose mouth is at `mouth`, if it's on this computer.
local function gnawbertAt(mouth: Vector3): Gnawbert?
	for _, gnawbert in gnawberts do
		if (gnawbert.Mouth - mouth).Magnitude < 1 then
			return gnawbert
		end
	end
	return nil
end

-- One log that drops onto the pad near `from`, slides to the chute and hops up it.
local function addRider(pad: BasePart, from: Vector3, chuteStart: Vector3, chuteEnd: Vector3, mouth: Vector3, eater: Gnawbert?)
	local logs = Config.Logs
	local lift = Vector3.new(0, 0.15 + logs.Thickness / 2, 0) -- from the chute's middle to a log lying on it

	-- Land on the pad under where they stood, a little scattered, never off its edge.
	local offset = pad.CFrame:PointToObjectSpace(from)
	local halfX, halfZ = pad.Size.X / 2 - 1, pad.Size.Z / 2 - 1
	local landing = pad.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(offset.X + random:NextNumber(-1.2, 1.2), -halfX, halfX),
		pad.Size.Y / 2 + logs.Thickness / 2,
		math.clamp(offset.Z + random:NextNumber(-1.2, 1.2), -halfZ, halfZ)
	))
	local points = { landing + Vector3.new(0, 3, 0), landing, chuteStart + lift, chuteEnd + lift, mouth }
	local speeds = { 0, cfg.SlideSpeed, cfg.HopSpeed, cfg.HopSpeed }
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
	table.insert(riders, { Part = part, Started = os.clock(), Points = points, Ends = ends, Mouth = mouth, Eater = eater })
end

local function onSold(pad: unknown, count: unknown, from: unknown)
	-- The pad can be missing on your computer when it's far away (StreamingEnabled).
	if typeof(pad) ~= "Instance" or not pad:IsA("BasePart") or typeof(count) ~= "number" or typeof(from) ~= "Vector3" then
		return
	end
	local chuteStart, chuteEnd, mouth = vectorAttribute(pad, "ChuteStart"), vectorAttribute(pad, "ChuteEnd"), vectorAttribute(pad, "Mouth")
	if not (chuteStart and chuteEnd and mouth) then
		return
	end
	local shown = math.min(math.floor(count), cfg.MaxShownLogs)
	local eater = gnawbertAt(mouth)
	if eater then
		eater.Coming += shown
		eater.BurpAt = nil
	end
	for index = 1, shown do
		task.delay((index - 1) * cfg.LogGap, addRider, pad, from, chuteStart, chuteEnd, mouth, eater)
	end
end

-- A log has reached the mouth: snap shut on it.
local function eat(rider: Rider, now: number)
	rider.Part:Destroy()
	chips(rider.Mouth)
	local gnawbert = rider.Eater
	if not gnawbert then
		return
	end
	gnawbert.ChompedAt = now
	gnawbert.Eaten += 1
	gnawbert.Coming = math.max(gnawbert.Coming - 1, 0)
	if gnawbert.Coming == 0 then
		gnawbert.BurpAt = now + look.BurpDelay
	end
	Fx.playSound(Config.Sounds.Chomp, gnawbert.Mouth, random:NextNumber(0.9, 1.1))
end

-- Move every riding log along its path; eaten ones disappear in a puff of chips.
local function moveRiders(now: number)
	for index = #riders, 1, -1 do
		local rider = riders[index]
		local elapsed = now - rider.Started
		local ends = rider.Ends
		if elapsed >= ends[#ends] then
			eat(rider, now)
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
		local tumble = CFrame.identity
		if leg == HOP_LEG then
			local hop = math.abs(math.sin(alpha * math.pi * cfg.Hops))
			position += Vector3.yAxis * hop * cfg.HopHeight
			tumble = CFrame.Angles(hop * 0.5, 0, 0)
		elseif leg == LAST_LEG then
			position += Vector3.yAxis * math.sin(alpha * math.pi) * cfg.LastHop
		end
		-- Falling straight down it keeps facing the way it will slide.
		local ahead = if leg == 1 then rider.Points[3] else to
		local flat = Vector3.new(ahead.X - position.X, if leg >= HOP_LEG then ahead.Y - position.Y else 0, ahead.Z - position.Z)
		rider.Part.CFrame = if flat.Magnitude > 0.01 then CFrame.lookAt(position, position + flat) * tumble else rider.Part.CFrame.Rotation + position
		local eater = rider.Eater
		if eater then
			local arrives = rider.Started + ends[#ends]
			local nextBite = eater.NextBite
			if not nextBite or arrives < nextBite then
				eater.NextBite = arrives
			end
		end
	end
end

-- How far (degrees) the lid wants to be open now, and how quickly it gets there.
local function lidGoal(gnawbert: Gnawbert, now: number, cameraPosition: Vector3): (number, number)
	if now - gnawbert.ChompedAt < look.ChompTime then
		return look.ChompAngle, look.SnapSpeed
	end
	if now - gnawbert.BurpedAt < look.BurpTime then
		return look.BurpAngle + math.sin(now * look.BurpShakeSpeed) * look.BurpShake, look.LidSpeed
	end
	local nextBite = gnawbert.NextBite
	if nextBite and nextBite - now < look.OpenBefore then
		return look.OpenAngle, look.LidSpeed
	end
	local carry = player:GetAttribute("Carry")
	local hasLogs = typeof(carry) == "number" and carry > 0
	if gnawbert.Coming > 0 or (hasLogs and (gnawbert.Mouth - cameraPosition).Magnitude < look.HungryDistance) then
		return look.HungryAngle + math.sin(now * look.BreatheSpeed * 3) * look.Breathe, look.LidSpeed
	end
	return look.RestAngle + math.sin(now * look.BreatheSpeed) * look.Breathe, look.LidSpeed
end

local function moveGnawbert(gnawbert: Gnawbert, now: number, deltaTime: number, cameraPosition: Vector3)
	local burpAt = gnawbert.BurpAt
	if burpAt and now >= burpAt then
		gnawbert.BurpAt = nil
		gnawbert.BurpedAt = now
		burpCoins(gnawbert, math.clamp(gnawbert.Eaten * 2, look.BurpCoinsMin, look.BurpCoinsMax))
		gnawbert.Eaten = 0
		Fx.playSound(Config.Sounds.Burp, gnawbert.Mouth)
	end

	local goal, speed = lidGoal(gnawbert, now, cameraPosition)
	gnawbert.Angle += (goal - gnawbert.Angle) * (1 - math.exp(-speed * deltaTime))
	local frame = gnawbert.Rest * CFrame.Angles(-math.rad(gnawbert.Angle), 0, 0)
	gnawbert.Lid:PivotTo(frame)

	local pupils, fromLid = gnawbert.Pupils, gnawbert.PupilsFromLid
	if pupils and fromLid then
		-- They look down at the logs while it's eating, and at you the rest of the time.
		local toCamera = frame:PointToObjectSpace(cameraPosition) - look.EyesFromHinge
		local wanted = if gnawbert.Coming > 0
			then Vector3.new(0, -look.PupilShift, 0)
			else Vector3.new(math.clamp(toCamera.X / 6, -1, 1), math.clamp(toCamera.Y / 6, -1, 1), 0) * look.PupilShift
		gnawbert.Look = gnawbert.Look:Lerp(wanted, 1 - math.exp(-look.PupilSpeed * deltaTime))
		pupils:PivotTo(frame * fromLid * CFrame.new(gnawbert.Look))
	end
end

local function moveGnawberts(now: number, deltaTime: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	for _, gnawbert in gnawberts do
		-- Far away you can't see it moving, so don't bother. A burp there just never happens.
		if (gnawbert.Mouth - cameraPosition).Magnitude <= look.ViewDistance then
			moveGnawbert(gnawbert, now, deltaTime, cameraPosition)
		else
			gnawbert.BurpAt = nil
			gnawbert.Eaten = 0
		end
		gnawbert.NextBite = nil -- moveRiders works it out again next frame
	end
end

local function addLid(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	-- With StreamingEnabled the model can arrive before its parts. Its pivot is only right once its
	-- main part is here (the server streams the lid in whole: ModelStreamingMode Atomic).
	if not instance.PrimaryPart then
		local connection: RBXScriptConnection
		connection = instance:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
			if instance.PrimaryPart then
				connection:Disconnect()
				addLid(instance)
			end
		end)
		return
	end
	local mouth = vectorAttribute(instance, "Mouth")
	if not mouth then
		return
	end
	local rest = instance:GetPivot()
	local pupils = instance:FindFirstChild("Pupils")
	local pupilModel = if pupils and pupils:IsA("Model") and pupils.PrimaryPart then pupils else nil
	gnawberts[instance] = {
		Lid = instance,
		Pupils = pupilModel,
		Rest = rest,
		PupilsFromLid = if pupilModel then rest:ToObjectSpace(pupilModel:GetPivot()) else nil,
		Mouth = mouth,
		Angle = look.RestAngle,
		Look = Vector3.zero,
		Coming = 0,
		NextBite = nil,
		ChompedAt = -math.huge,
		Eaten = 0,
		BurpAt = nil,
		BurpedAt = -math.huge,
	}
end

function SellYardController.init()
	folder = Instance.new("Folder")
	folder.Name = "SoldLogs"
	folder.Parent = workspace
end

function SellYardController.start()
	Remotes.getEvent("LogsSold").OnClientEvent:Connect(onSold)
	for _, instance in CollectionService:GetTagged(Tags.GnawbertLid) do
		addLid(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.GnawbertLid):Connect(addLid)
	CollectionService:GetInstanceRemovedSignal(Tags.GnawbertLid):Connect(function(instance: Instance)
		gnawberts[instance] = nil
	end)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		local now = os.clock()
		moveRiders(now)
		moveGnawberts(now, deltaTime)
	end)
end

return SellYardController
