--!strict
-- The Log Vacuum: a tool. While a player holds it and holds the mouse button down (the
-- VacuumLogs remote says "started" / "stopped"), the server grabs the logs in front of them,
-- a few at a time, and puts each one in their backpack once it has flown into the nozzle.
--
-- The server only decides WHICH logs and WHEN: it marks a grabbed log (Pulling, SuckedBy,
-- SuckedAt) and leaves it where it is. Every player's computer draws it lifting off the
-- ground and whooshing into the vacuum (Client/Controllers/LogVacuumController).
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

local function setPromptEnabled(log: BasePart, enabled: boolean)
	local prompt = log:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = enabled
	end
end

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

local function pull(player: Player, log: BasePart)
	log:SetAttribute("Pulling", true)
	log:SetAttribute("SuckedBy", player.UserId)
	log:SetAttribute("SuckedAt", workspace:GetServerTimeNow())
	setPromptEnabled(log, false) -- nobody else can grab it mid-air
	inFlight[player] = (inFlight[player] or 0) + 1

	task.delay(cfg.PullTime, function()
		inFlight[player] = math.max((inFlight[player] or 1) - 1, 0)
		if log.Parent == nil then
			return
		end
		if not LogManager.tryPickUp(player, log) then
			-- No room after all (or the player left): the log drops back where it was.
			log:SetAttribute("Pulling", nil)
			log:SetAttribute("SuckedBy", nil)
			log:SetAttribute("SuckedAt", nil)
			setPromptEnabled(log, true)
		end
	end)
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
		-- Only say so once it really is full (not while the last logs are still flying in).
		if not LogManager.hasRoom(player) and now - (toldFull[player] or 0) > 2 then
			toldFull[player] = now
			notifyRemote:FireClient(player, "Your backpack is full!")
		end
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
		pull(player, candidates[index].Log)
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
