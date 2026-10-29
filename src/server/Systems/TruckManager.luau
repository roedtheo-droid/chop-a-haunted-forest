--!strict
-- Driving the log trucks you own (see Config.Truck and Config.Trucks).
--
--   Spawn   In the Garage, a truck you own has a SPAWN button. The server checks that you
--           own it and stand on the Garage pad, then parks it next to the driveway (see
--           Build/TruckRig). One truck per player: spawning again swaps it, and it's gone
--           when you leave.
--   Drive   Only the owner can get in (its "Drive" prompt). While they drive, their own
--           computer moves the truck (network ownership), so it feels smooth. The server reads
--           the seat's throttle and steering and turns the wheel motors: never faster than
--           the truck's Speed.
--   Load    The "Load logs" prompt behind the bed moves logs from your backpack into the bed,
--           up to the truck's Carry. They show as logs piled in the bed.
--   Sell    Drive onto a sawmill's DROP LOGS pad: the server sells the whole bed and pays the
--           owner, like selling from your backpack.
-- The server keeps the bed's count and value; nothing the client sends is trusted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TruckBuilder = require(ReplicatedStorage.Shared.TruckBuilder)
local Trucks = require(ReplicatedStorage.Shared.Trucks)
local Types = require(ReplicatedStorage.Shared.Types)
local CoinManager = require(script.Parent.CoinManager)
local EffectsManager = require(script.Parent.EffectsManager)
local GarageManager = require(script.Parent.GarageManager)
local LogManager = require(script.Parent.LogManager)
local QuestManager = require(script.Parent.QuestManager)
local RunManager = require(script.Parent.RunManager)
local SawmillManager = require(script.Parent.SawmillManager)
local TruckRig = require(script.Parent.Parent.Build.TruckRig)

-- Which way the motors and steering turn (found by testing: a wheel hinge's positive
-- direction depends on how its attachments face).
local WHEEL_DIRECTION = -1
local STEER_DIRECTION = -1
local LOG_BARK = Color3.fromRGB(120, 75, 45)
local SPAWN_COOLDOWN = 2 -- seconds between two SPAWN presses

type Truck = {
	Owner: Player,
	Config: Types.TruckConfig,
	Rig: TruckRig.Rig,
	Load: number, -- logs in the bed
	Value: number, -- what they're worth at a sawmill
	LoadPrompt: ProximityPrompt,
	LoadParts: { BasePart },
	LastSell: number,
}

local TruckManager = {}

local notifyRemote: RemoteEvent
local folder: Folder
local trucks: { [Player]: Truck } = {}
local lastSpawn: { [Player]: number } = {}

local function notify(player: Player, text: string, ...: any)
	notifyRemote:FireClient(player, string.format(text, ...))
end

local function despawn(player: Player)
	local truck = trucks[player]
	if not truck then
		return
	end
	trucks[player] = nil
	local occupant = truck.Rig.Seat.Occupant
	if occupant then
		occupant.Sit = false
	end
	truck.Rig.Model:Destroy()
end

-- Draw the load: rows of logs lying along the bed, as many as the bed is full.
local function drawLoad(truck: Truck)
	for _, part in truck.LoadParts do
		part:Destroy()
	end
	table.clear(truck.LoadParts)
	truck.LoadPrompt.ObjectText = string.format(Config.Truck.Text.BedCount, truck.Load, truck.Config.Carry)
	if truck.Load <= 0 then
		return
	end
	local floor = truck.Rig.BedFloor
	local scale = truck.Config.Look.Scale
	local size = Config.Truck.LogSize * scale
	local columns = math.max(math.floor((floor.Size.X - 0.8 * scale) / (size + 0.05)), 1)
	local rows = 3
	local shown = math.ceil(truck.Load / truck.Config.Carry * columns * rows)
	local length = floor.Size.Z - 0.8 * scale
	for index = 1, shown do
		local row = (index - 1) // columns
		local column = (index - 1) % columns
		local x = (column - (columns - 1) / 2) * (size + 0.05)
		local y = floor.Size.Y / 2 + size / 2 + row * size
		local log = Instance.new("Part")
		log.Name = "LoadLog"
		log.Size = Vector3.new(size, size, length)
		log.CFrame = floor.CFrame * CFrame.new(x, y, 0)
		log.Color = LOG_BARK
		log.Material = Enum.Material.Wood
		log.CanCollide = false
		log.CanQuery = false
		log.Massless = true
		log.Parent = truck.Rig.Model
		local joint = Instance.new("WeldConstraint")
		joint.Part0 = floor
		joint.Part1 = log
		joint.Parent = log
		table.insert(truck.LoadParts, log)
	end
end

local function onLoad(truck: Truck, player: Player)
	local text = Config.Truck.Text
	if Config.Truck.OwnerOnlyLoading and player ~= truck.Owner then
		notify(player, text.NotYourBed, truck.Owner.DisplayName)
		return
	end
	local room = truck.Config.Carry - truck.Load
	if room <= 0 then
		notify(player, text.BedFull)
		return
	end
	local count, value = LogManager.take(player, room)
	if count <= 0 then
		notify(player, text.NothingToLoad)
		return
	end
	truck.Load += count
	truck.Value += value
	drawLoad(truck)
	notify(player, text.Loaded, count, truck.Load, truck.Config.Carry)
end

-- Somebody sat down. Only the owner may drive: anyone else is put straight back out.
local function onOccupant(truck: Truck)
	local seat = truck.Rig.Seat
	local humanoid = seat.Occupant
	if not humanoid then
		return
	end
	local character = humanoid.Parent
	local player = if character then Players:GetPlayerFromCharacter(character) else nil
	if player ~= truck.Owner then
		humanoid.Sit = false
		local seatWeld = seat:FindFirstChild("SeatWeld")
		if seatWeld then
			seatWeld:Destroy()
		end
		if player then
			notify(player, Config.Truck.Text.NotYourTruck, truck.Owner.DisplayName)
		end
		return
	end
	-- The driver's computer moves the truck while they drive, so it reacts at once.
	pcall(function()
		truck.Rig.Chassis:SetNetworkOwner(truck.Owner)
	end)
end

local function spawnTruck(player: Player, config: Types.TruckConfig)
	despawn(player)

	-- The first parking spot that no other truck stands on.
	local spots = GarageManager.parkingSpots()
	local spot = spots[1]
	for _, candidate in spots do
		local free = true
		for _, other in trucks do
			if (other.Rig.Chassis.Position - candidate.Position).Magnitude < 10 then
				free = false
			end
		end
		if free then
			spot = candidate
			break
		end
	end

	local model = TruckBuilder.build(config.Look, `{player.Name}_{config.Id}`)
	local rig = TruckRig.make(model, config.Look, config.Speed)
	model:PivotTo(spot + Vector3.new(0, 0.2, 0))
	model.Parent = folder

	local text = Config.Truck.Text
	local drivePrompt = Instance.new("ProximityPrompt")
	drivePrompt.ActionText = text.DriveAction
	drivePrompt.ObjectText = string.format(text.TruckName, player.DisplayName, config.Name)
	drivePrompt.KeyboardKeyCode = Enum.KeyCode.E
	drivePrompt.HoldDuration = 0
	drivePrompt.MaxActivationDistance = 12 * config.Look.Scale
	drivePrompt.RequiresLineOfSight = false
	drivePrompt.Parent = rig.Seat

	local loadPrompt = Instance.new("ProximityPrompt")
	loadPrompt.ActionText = text.LoadAction
	loadPrompt.KeyboardKeyCode = Enum.KeyCode.E
	loadPrompt.HoldDuration = 0
	loadPrompt.MaxActivationDistance = Config.Truck.LoadDistance
	loadPrompt.RequiresLineOfSight = false
	loadPrompt.Parent = rig.LoadPoint

	local truck: Truck = {
		Owner = player,
		Config = config,
		Rig = rig,
		Load = 0,
		Value = 0,
		LoadPrompt = loadPrompt,
		LoadParts = {},
		LastSell = 0,
	}
	trucks[player] = truck
	drawLoad(truck)
	TruckRig.release(rig)

	drivePrompt.Triggered:Connect(function(who: Player)
		if who ~= player then
			notify(who, text.NotYourTruck, player.DisplayName)
			return
		end
		local character = who.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid and humanoid.Health > 0 and not rig.Seat.Occupant then
			rig.Seat:Sit(humanoid)
		end
	end)
	loadPrompt.Triggered:Connect(function(who: Player)
		onLoad(truck, who)
	end)
	rig.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		onOccupant(truck)
	end)
	-- The drive prompt hides while you sit in the seat.
	rig.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		drivePrompt.Enabled = rig.Seat.Occupant == nil
	end)

	notify(player, text.Spawned, config.Name)
end

local function onSpawn(player: Player, truckId: unknown)
	if typeof(truckId) ~= "string" then
		return
	end
	local config = Trucks.get(truckId :: string)
	if not config or not Trucks.owns(player, config.Id) then
		return
	end
	local now = os.clock()
	local last = lastSpawn[player]
	if last and now - last < SPAWN_COOLDOWN then
		return
	end
	lastSpawn[player] = now
	if not GarageManager.isOnPad(player) then
		notifyRemote:FireClient(player, Config.Garage.Text.NotOnPad)
		return
	end
	spawnTruck(player, config)
end

-- Turn the wheels from what the driver presses: forward/back on the motors, left/right on
-- the steering. Nobody driving (or letting go) holds the wheels still, like a brake.
local function drive(truck: Truck)
	local rig = truck.Rig
	local seat = rig.Seat
	local throttle = if seat.Occupant then seat.ThrottleFloat else 0
	local steer = if seat.Occupant then seat.SteerFloat else 0
	local spin = WHEEL_DIRECTION * throttle * truck.Config.Speed / rig.WheelRadius
	for _, motor in rig.Motors do
		motor.AngularVelocity = spin
	end
	local angle = STEER_DIRECTION * steer * Config.Truck.SteerAngle
	for _, steering in rig.Steering do
		steering.TargetAngle = angle
	end
end

-- Is the truck standing on a DROP LOGS pad? Then sell the whole bed for the owner.
local function trySell(truck: Truck)
	if truck.Load <= 0 then
		return
	end
	local now = os.clock()
	if now - truck.LastSell < Config.Truck.SellCooldown then
		return
	end
	local position = truck.Rig.Chassis.Position
	local margin = Config.Truck.SellMargin
	for _, pad in SawmillManager.getPads() do
		local offset = pad.CFrame:PointToObjectSpace(position)
		if math.abs(offset.X) <= pad.Size.X / 2 + margin and math.abs(offset.Z) <= pad.Size.Z / 2 + margin and math.abs(offset.Y) < 8 then
			truck.LastSell = now
			local owner = truck.Owner
			local logs, coins = truck.Load, truck.Value
			truck.Load = 0
			truck.Value = 0
			drawLoad(truck)
			CoinManager.add(owner, coins)
			RunManager.record(owner, "CoinsEarned", coins)
			QuestManager.report(owner, "SellLogs")
			EffectsManager.burst("Coins", position)
			notify(owner, Config.Truck.Text.Sold, logs, Format.number(coins))
			return
		end
	end
end

function TruckManager.init()
	folder = Instance.new("Folder")
	folder.Name = "Trucks"
	folder.Parent = workspace
end

function TruckManager.start()
	notifyRemote = Remotes.getEvent("Notify")
	Remotes.getEvent("SpawnTruck").OnServerEvent:Connect(onSpawn)

	Players.PlayerRemoving:Connect(function(player: Player)
		despawn(player)
		lastSpawn[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		for player, truck in trucks do
			if truck.Rig.Model.Parent == nil then
				trucks[player] = nil -- it fell out of the world
				continue
			end
			drive(truck)
			trySell(truck)
		end
	end)
end

return TruckManager
