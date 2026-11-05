--!strict
-- Logs flying into your backpack, in two ways:
--   Walking over them  Logs close to your feet fly to you by themselves.
--   The Log Vacuum     A tool. While a player holds it and holds the mouse button down (the
--                      VacuumLogs remote says "started" / "stopped"), the server grabs the logs
--                      in front of them from much further away, a few at a time.
-- Each log goes in the backpack once it has flown in.
--
-- The server only decides WHICH logs and WHEN: it marks a grabbed log (Pulling, SuckedBy, SuckedAt,
-- SuckedTime, ToSack) and leaves it where it is. Every player's computer draws it lifting off
-- the ground and whooshing in (Client/Controllers/LogVacuumController).
-- The client sends no positions or numbers, so there's nothing to cheat with.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)
local LogManager = require(script.Parent.LogManager)
local ToolManager = require(script.Parent.ToolManager)

local cfg = Config.LogVacuum

local LogVacuumManager = {}

local notifyRemote: RemoteEvent

local sucking: { [Player]: boolean } = {} -- players holding the button down
local inFlight: { [Player]: number } = {} -- logs flying to each player right now
local toldFull: { [Player]: number } = {} -- when we last said "backpack full" (so we don't spam it)
local lastGrab: { [Player]: number } = {} -- so clicking fast can't grab faster than Interval

local function stop(player: Player)
	sucking[player] = nil
	player:SetAttribute("VacuumingLogs", nil) -- every computer stops the wind and the hum
end

-- How many more logs fit in the player's backpack, counting the ones on their way in.
local function freeRoom(player: Player): number
	if Shop.hasPerk(player, "InfiniteBag") then
		return math.huge
	end
	local limit = player:GetAttribute("CarryLimit")
	return (if typeof(limit) == "number" then limit else 0) - LogManager.getCarry(player) - (inFlight[player] or 0)
end

-- Send a log flying to the player. `flyTime` is how long it takes, and `toSack` means it flies
-- to their body (they walked over it) instead of the vacuum's nozzle.
local function pull(player: Player, log: BasePart, flyTime: number, toSack: boolean)
	log:SetAttribute("Pulling", true) -- nobody else can grab it mid-air
	log:SetAttribute("SuckedBy", player.UserId)
	log:SetAttribute("SuckedTime", flyTime)
	log:SetAttribute("ToSack", if toSack then true else nil)
	log:SetAttribute("SuckedAt", workspace:GetServerTimeNow())
	inFlight[player] = (inFlight[player] or 0) + 1

	task.delay(flyTime, function()
		local flying = (inFlight[player] or 1) - 1
		inFlight[player] = if player.Parent and flying > 0 then flying else nil
		if log.Parent == nil then
			return
		end
		if not (player.Parent and LogManager.tryPickUp(player, log)) then
			-- No room after all (or the player left): the log drops back where it was.
			log:SetAttribute("Pulling", nil)
			log:SetAttribute("SuckedBy", nil)
			log:SetAttribute("SuckedTime", nil)
			log:SetAttribute("ToSack", nil)
			log:SetAttribute("SuckedAt", nil)
		end
	end)
end

-- Only say so once it really is full (not while the last logs are still flying in).
local function tellIfFull(player: Player)
	local now = os.clock()
	if not LogManager.hasRoom(player) and now - (toldFull[player] or 0) > Config.Logs.FullMessageEvery then
		toldFull[player] = now
		notifyRemote:FireClient(player, Config.Logs.Text.Full)
	end
end

-- Grab the closest logs in front of the player (up to PerGrab, and only what fits).
local function grab(player: Player)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return
	end

	local now = os.clock()
	if now - (lastGrab[player] or 0) < cfg.Interval * 0.8 then
		return
	end
	lastGrab[player] = now

	local free = freeRoom(player)
	if free <= 0 then
		tellIfFull(player)
		return
	end

	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0 then look.Unit else Vector3.zAxis
	local candidates: { { Log: BasePart, Distance: number } } = {}
	for _, log in LogManager.getLogs() do
		-- Logs still popping out of their tree land first, so the pop looks right on every screen.
		if log:IsA("BasePart") and not log:GetAttribute("Pulling") and not LogManager.isPopping(log) then
			local offset = log.Position - root.Position
			local distance = offset.Magnitude
			local flat = offset * Vector3.new(1, 0, 1)
			-- Right at your feet counts as in front of you.
			local ahead = if flat.Magnitude > 2 then flat.Unit:Dot(look) else 1
			if distance <= cfg.Range and ahead >= cfg.Cone then
				table.insert(candidates, { Log = log, Distance = distance })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)
	for index = 1, math.min(#candidates, cfg.PerGrab, free) do
		pull(player, candidates[index].Log, cfg.PullTime, false)
	end
end

-- Walking over logs: the ones close to your feet fly to you. (Not while you're driving or lying
-- on the ground, and not logs still popping out of their tree.)
local function walkOver(player: Player, logs: { Instance })
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (humanoid and root and root:IsA("BasePart")) or humanoid.Health <= 0 then
		return
	end
	if humanoid.SeatPart or player:GetAttribute("KnockedDown") == true then
		return
	end

	local free = freeRoom(player)
	for _, log in logs do
		if
			log:IsA("BasePart")
			and not log:GetAttribute("Pulling")
			and not LogManager.isPopping(log)
			and (log.Position - root.Position).Magnitude <= Config.Logs.WalkOverRadius
		then
			if free <= 0 then
				tellIfFull(player)
				return
			end
			pull(player, log, Config.Logs.WalkOverFlyTime, true)
			free -= 1
		end
	end
end

local function onVacuum(player: Player, on: any)
	if typeof(on) ~= "boolean" then
		return
	end
	if not on then
		stop(player)
		return
	end
	if ToolManager.getEquippedId(player) ~= "LogVacuum" or player:GetAttribute("KnockedDown") == true then
		return
	end
	local starting = not sucking[player]
	sucking[player] = true
	player:SetAttribute("VacuumingLogs", true)
	if starting then
		grab(player) -- straight away, so a quick click gets a log too
	end
end

function LogVacuumManager.init() end

function LogVacuumManager.start()
	notifyRemote = Remotes.getEvent("Notify")
	Remotes.getEvent("VacuumLogs").OnServerEvent:Connect(onVacuum)

	Players.PlayerRemoving:Connect(function(player: Player)
		sucking[player] = nil
		inFlight[player] = nil
		toldFull[player] = nil
		lastGrab[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Logs.WalkOverCheck)
			local logs = LogManager.getLogs()
			if #logs > 0 then
				for _, player in Players:GetPlayers() do
					walkOver(player, logs)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(cfg.Interval)
			for player in sucking do
				-- Put the vacuum away (or got knocked down) while sucking: it stops.
				if ToolManager.getEquippedId(player) ~= "LogVacuum" or player:GetAttribute("KnockedDown") == true then
					stop(player)
				else
					grab(player)
				end
			end
		end
	end)
end

return LogVacuumManager
