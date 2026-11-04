--!strict
-- The Log Vacuum on your side.
--
-- Clicking: while you hold the vacuum, pressing the mouse button (or your finger) tells the
-- server "I started sucking", and letting go "I stopped" (the VacuumLogs remote). A quick
-- click still sucks for Config.LogVacuum.MinBurst seconds. No positions or numbers are sent:
-- the server picks the logs (see Server/Systems/LogVacuumManager).
--
-- Drawing (for everyone's vacuum, only for looks):
--   * a player who is sucking has the VacuumingLogs attribute: air streams into the nozzle
--     and the motor hums;
--   * a log the server grabbed has SuckedBy / SuckedAt: it lifts off the ground, wobbles,
--     then whooshes along a curve into the nozzle, spinning and shrinking, and goes in with
--     a pop. Logs in a row pop higher and higher.
-- The log is moved only on this computer; the server takes it away when it's in the sack.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Fx = require(ReplicatedStorage.Shared.Fx)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MouseController = require(script.Parent.MouseController)
local ViewmodelController = require(script.Parent.ViewmodelController)

local cfg = Config.LogVacuum

local LogVacuumController = {}

local player = Players.LocalPlayer
local vacuumRemote: RemoteEvent

-- Our own button.
local pressed = false -- the button is down right now
local pressedAt = 0
local sentOn = false -- what we last told the server

-- A log on its way into a vacuum.
type Flight = {
	Log: BasePart,
	Sucker: Player?,
	Start: CFrame, -- where it lay (put back if the server drops it again)
	Size: Vector3,
	Started: number, -- os.clock() when it left the ground
	Spin: Vector3, -- the axis it spins around
	Wobble: number, -- a random start for its wobble
	Done: boolean, -- it's in the nozzle (hidden until the server removes it)
}
local flights: { [BasePart]: Flight } = {}

-- The air and hum at the nozzle of each player who is sucking.
type Wind = { Part: Part, Hum: Sound }
local winds: { [Player]: Wind } = {}

-- Logs in a row pop higher and higher: per player, how many and when the last one went in.
local combos: { [Player]: { Count: number, Last: number } } = {}

local function heldVacuum(who: Player): Tool?
	local character = who.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	if tool and tool:GetAttribute("ToolId") == "LogVacuum" then
		return tool
	end
	return nil
end

-- Where `who`'s nozzle is: your own first-person copy, or the real tool's Head (the invisible
-- part at the nozzle, see Server/Systems/ToolManager). Falls back to their body.
local function nozzle(who: Player?): CFrame?
	if who == player then
		local copy = ViewmodelController.getToolPart("Head")
		if copy then
			return copy.CFrame
		end
	end
	local tool = if who then heldVacuum(who) else nil
	local head = if tool then tool:FindFirstChild("Head") else nil
	if head and head:IsA("BasePart") then
		return head.CFrame
	end
	local character = if who then who.Character else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.CFrame
	end
	return nil
end

---------------------------------------------------------------------------
-- Telling the server
---------------------------------------------------------------------------

local function send(on: boolean)
	if on ~= sentOn then
		sentOn = on
		vacuumRemote:FireServer(on)
	end
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	-- gameProcessed is true when the click was on a button or the mobile joystick.
	if gameProcessed or not isPress(input) or MouseController.isFree() then
		return
	end
	if not heldVacuum(player) or player:GetAttribute("KnockedDown") == true then
		return
	end
	pressed = true
	pressedAt = os.clock()
	send(true)
end

local function onInputEnded(input: InputObject)
	if not (isPress(input) and pressed) then
		return
	end
	pressed = false
	-- A quick click still sucks for a moment, so it always gets something.
	local left = cfg.MinBurst - (os.clock() - pressedAt)
	if left <= 0 then
		send(false)
	else
		task.delay(left, function()
			if not pressed then
				send(false)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Air and hum at the nozzle
---------------------------------------------------------------------------

local function makeWind(): Wind
	-- An invisible ball of air around the nozzle's mouth; the specks fly from its edge to its
	-- middle, right in front of the mouth.
	local part = Instance.new("Part")
	part.Name = "VacuumAir"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * cfg.WindSize
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local air = Instance.new("ParticleEmitter")
	air.Shape = Enum.ParticleEmitterShape.Sphere
	air.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	air.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	air.Rate = 90
	air.Lifetime = NumberRange.new(0.25, 0.3)
	air.Speed = NumberRange.new(cfg.WindSize / 2 / 0.28) -- reaches the middle as it fades
	air.Orientation = Enum.ParticleOrientation.VelocityParallel
	air.Squash = NumberSequence.new(1.5)
	air.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0.06) })
	air.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.3),
		NumberSequenceKeypoint.new(1, 0.8),
	})
	air.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	air.LightEmission = 0.4
	air.Parent = part

	local hum = Instance.new("Sound")
	hum.SoundId = Config.Sounds.VacuumHum.Id
	hum.Volume = Config.Sounds.VacuumHum.Volume
	hum.PlaybackSpeed = Config.Sounds.VacuumHum.Speed or 1
	hum.Looped = true
	hum.RollOffMode = Enum.RollOffMode.InverseTapered
	hum.RollOffMinDistance = Config.Effects.SoundFullVolume
	hum.RollOffMaxDistance = Config.Sounds.VacuumHum.Range or Config.Effects.SoundRange
	hum.TimePosition = cfg.HumStart
	hum.Parent = part

	part.Parent = workspace
	hum:Play()
	return { Part = part, Hum = hum }
end

local function updateWinds()
	for _, who in Players:GetPlayers() do
		local on = who:GetAttribute("VacuumingLogs") == true and heldVacuum(who) ~= nil
		local wind = winds[who]
		local mouth = if on then nozzle(who) else nil
		if mouth then
			if not wind then
				wind = makeWind()
				winds[who] = wind
			end
			local wanted = wind :: Wind
			wanted.Part.CFrame = mouth * CFrame.new(0, 0, -cfg.WindDistance)
		elseif wind then
			wind.Part:Destroy()
			winds[who] = nil
		end
	end
	ViewmodelController.setRumble(if winds[player] then cfg.Rumble else 0)
end

---------------------------------------------------------------------------
-- Logs flying in
---------------------------------------------------------------------------

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- Hide or show a log on this computer only (its end rings are SurfaceGuis).
local function setShown(log: BasePart, shown: boolean)
	log.LocalTransparencyModifier = if shown then 0 else 1
	for _, child in log:GetChildren() do
		if child:IsA("SurfaceGui") then
			child.Enabled = shown
		end
	end
end

-- The pop as a log goes in: a suction pop (higher for each log in a row) and a puff of
-- wood dust at the nozzle.
local function popIn(flight: Flight, at: Vector3)
	local sucker = flight.Sucker
	local pitch = 1
	if sucker then
		local now = os.clock()
		local combo = combos[sucker]
		if not combo or now - combo.Last > cfg.ComboReset then
			combo = { Count = 0, Last = now }
			combos[sucker] = combo
		end
		local current = combo :: { Count: number, Last: number }
		current.Count += 1
		current.Last = now
		pitch = math.min(1 + (current.Count - 1) * cfg.PitchStep, cfg.PitchMax)
	end
	Fx.playSound(Config.Sounds.LogSuck, at, pitch)

	local anchor = Fx.anchorAt(at)
	local dust = Instance.new("ParticleEmitter")
	dust.Rate = 0
	dust.Lifetime = NumberRange.new(0.2, 0.35)
	dust.Speed = NumberRange.new(3, 6)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	dust.Color = ColorSequence.new(Config.Style.InnerWood)
	dust.Drag = 6
	dust.Parent = anchor
	dust:Emit(8)
	Debris:AddItem(anchor, 1)
end

local function finish(flight: Flight)
	if flight.Done then
		return
	end
	flight.Done = true
	local mouth = nozzle(flight.Sucker)
	popIn(flight, if mouth then mouth.Position else flight.Log.Position)
	setShown(flight.Log, false)
end

local function startFlight(log: BasePart)
	if flights[log] then
		return
	end
	local suckedBy = log:GetAttribute("SuckedBy")
	local suckedAt = log:GetAttribute("SuckedAt")
	if typeof(suckedBy) ~= "number" or typeof(suckedAt) ~= "number" then
		return
	end
	-- Start part of the way in if the message took a while, so it ends when the server's does.
	local late = math.clamp(workspace:GetServerTimeNow() - suckedAt, 0, cfg.PullTime * 0.5)
	local random = Random.new()
	flights[log] = {
		Log = log,
		Sucker = Players:GetPlayerByUserId(suckedBy),
		Start = log.CFrame,
		Size = log.Size,
		Started = os.clock() - late,
		Spin = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(0.3, 1), random:NextNumber(-1, 1)).Unit,
		Wobble = random:NextNumber(0, math.pi * 2),
		Done = false,
	}
end

-- The server dropped the log again (the sack was full after all): put it back as it was.
local function cancelFlight(log: BasePart)
	local flight = flights[log]
	if not flight then
		return
	end
	flights[log] = nil
	log.Size = flight.Size
	log.CFrame = flight.Start
	setShown(log, true)
end

local function updateFlights()
	for log, flight in flights do
		if log.Parent == nil then
			-- In the sack: if it vanished a moment before reaching the nozzle, still pop.
			finish(flight)
			flights[log] = nil
			continue
		end
		if flight.Done then
			continue
		end
		local t = (os.clock() - flight.Started) / cfg.PullTime
		if t >= 1 then
			finish(flight)
			continue
		end
		local start = flight.Start
		local lifted = start.Position + Vector3.yAxis * cfg.LiftHeight
		if t < cfg.LiftShare then
			-- Lift off the ground and wobble, like it's being tugged loose.
			local u = t / cfg.LiftShare
			local position = start.Position:Lerp(lifted, smooth(u))
			local wobble = math.sin(u * math.pi * 5 + flight.Wobble) * 0.25 * u
			log.CFrame = CFrame.new(position) * CFrame.Angles(wobble, 0, wobble * 0.6) * start.Rotation
		else
			-- Whoosh: faster and faster along a curve into the nozzle, spinning, shrinking.
			local v = (t - cfg.LiftShare) / (1 - cfg.LiftShare)
			local eased = v * v
			local mouth = nozzle(flight.Sucker)
			local target = if mouth then mouth.Position else lifted
			local bend = (lifted + target) / 2 + Vector3.yAxis * cfg.Arc
			local a = lifted:Lerp(bend, eased)
			local b = bend:Lerp(target, eased)
			local position = a:Lerp(b, eased)
			local spin = CFrame.fromAxisAngle(flight.Spin, eased * cfg.Spin * math.pi * 2)
			log.CFrame = CFrame.new(position) * spin * start.Rotation
			local shrink = smooth(math.clamp((v - 0.4) / 0.6, 0, 1))
			log.Size = flight.Size * (1 + (cfg.EndSize - 1) * shrink)
		end
	end
end

---------------------------------------------------------------------------

local function watchLog(log: Instance)
	if not log:IsA("BasePart") then
		return
	end
	if log:GetAttribute("SuckedAt") ~= nil then
		startFlight(log)
	end
	log:GetAttributeChangedSignal("SuckedAt"):Connect(function()
		if log:GetAttribute("SuckedAt") ~= nil then
			startFlight(log)
		else
			cancelFlight(log)
		end
	end)
end

function LogVacuumController.init() end

function LogVacuumController.start()
	vacuumRemote = Remotes.getEvent("VacuumLogs")
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)

	RunService.RenderStepped:Connect(function()
		-- Put the vacuum away (or got knocked down) while sucking: stop.
		if sentOn and (not heldVacuum(player) or player:GetAttribute("KnockedDown") == true) then
			pressed = false
			send(false)
		end
		updateWinds()
		updateFlights()
	end)

	Players.PlayerRemoving:Connect(function(leaving: Player)
		local wind = winds[leaving]
		if wind then
			wind.Part:Destroy()
			winds[leaving] = nil
		end
		combos[leaving] = nil
	end)

	-- Logs are made by the server (Server/Systems/LogManager) in this folder.
	task.spawn(function()
		local logs = workspace:WaitForChild("Logs")
		logs.ChildAdded:Connect(watchLog)
		for _, log in logs:GetChildren() do
			watchLog(log)
		end
	end)
end

return LogVacuumController
