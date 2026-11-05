--!strict
-- Handles logs on the ground and how many logs each player carries.
--
-- Each player has attributes the client can read (but not change):
--   Carry       how many logs they carry now
--   CarryValue  how many coins those logs are worth at a sawmill
--   CarryLimit  how many logs fit in their backpack (set by UpgradeManager)
-- Each log on the ground has a Value attribute: coins it's worth (depends on its tree).
-- You pick logs up by walking over them or with the Log Vacuum (both in LogVacuumManager, which
-- calls tryPickUp), so the server always decides, and the client sends nothing.
-- Dying drops your logs where you fell, so dying isn't a free trip back to a sawmill.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Tags = require(ReplicatedStorage.Shared.Tags)
local AnalyticsManager = require(script.Parent.AnalyticsManager)
local QuestManager = require(script.Parent.QuestManager)
local Blocky = require(script.Parent.Parent.Build.Blocky)

local LOG_COLOR = Color3.fromRGB(125, 80, 48)
local CURSED_LOG_COLOR = Color3.fromRGB(120, 60, 150)

local LogManager = {}

local logsFolder: Folder
local notifyRemote: RemoteEvent
local droppedLogs: { [Player]: number } = {} -- how many logs a player dropped when they last died (told when they respawn)

local function getNumberAttribute(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

function LogManager.getCarry(player: Player): number
	return getNumberAttribute(player, "Carry")
end

function LogManager.setCarry(player: Player, amount: number)
	player:SetAttribute("Carry", amount)
end

-- Empty the player's backpack. Returns how many logs were in it and what they're worth.
-- Used by the sawmill when the player sells.
function LogManager.takeAll(player: Player): (number, number)
	local carry = LogManager.getCarry(player)
	local value = getNumberAttribute(player, "CarryValue")
	LogManager.setCarry(player, 0)
	player:SetAttribute("CarryValue", 0)
	return carry, value
end

-- Take up to `count` logs out of the player's backpack (to load them into a truck). Returns
-- how many were taken and what they're worth: their share of the backpack's value.
function LogManager.take(player: Player, count: number): (number, number)
	local carry = LogManager.getCarry(player)
	local taken = math.clamp(math.floor(count), 0, carry)
	if taken <= 0 then
		return 0, 0
	end
	local total = getNumberAttribute(player, "CarryValue")
	local value = if taken == carry then total else math.floor(total * taken / carry)
	LogManager.setCarry(player, carry - taken)
	player:SetAttribute("CarryValue", total - value)
	return taken, value
end

-- The Infinite Bag game pass has room for any number of logs.
function LogManager.hasRoom(player: Player): boolean
	return Shop.hasPerk(player, "InfiniteBag") or LogManager.getCarry(player) < getNumberAttribute(player, "CarryLimit")
end

-- All logs lying on the ground right now.
function LogManager.getLogs(): { Instance }
	return logsFolder:GetChildren()
end

-- Put a log in the player's backpack. Returns false if the backpack is full
-- or the log is already gone. Used by LogVacuumManager.
function LogManager.tryPickUp(player: Player, log: BasePart): boolean
	-- Two players could grab the same log at the same moment; only the first one gets it.
	if log.Parent == nil or not LogManager.hasRoom(player) then
		return false
	end

	local value = getNumberAttribute(log, "Value")
	log:Destroy()
	LogManager.setCarry(player, LogManager.getCarry(player) + 1)
	player:SetAttribute("CarryValue", getNumberAttribute(player, "CarryValue") + value)
	QuestManager.report(player, "PickUpLog")
	return true
end

local function createLog(position: Vector3, yaw: number, value: number, cursed: boolean): BasePart
	local cfg = Config.Logs

	-- A square, blocky log lying along its X axis, with light ringed ends. It's the Log model
	-- from Blender when that's imported (the same size), or a plain block.
	local log = Blocky.block(
		Config.Models.Log,
		"Log",
		Vector3.new(cfg.Length, cfg.Thickness, cfg.Thickness),
		CFrame.new(position) * CFrame.Angles(0, yaw, 0),
		if cursed then CURSED_LOG_COLOR else LOG_COLOR,
		Enum.Material.Wood,
		nil -- parented once it's ready (see spawnLogs)
	)
	log:SetAttribute("Value", value)
	log.CanCollide = false -- so players don't trip over logs
	Blocky.rings(log, Enum.NormalId.Left)
	Blocky.rings(log, Enum.NormalId.Right)
	return log
end

-- Make one log on the ground. Every player's computer makes it pop out from just above where it
-- ends up (Client/Controllers/ChopEffectsController), using the PopFrom and SpawnedAt attributes.
local function addLog(position: Vector3, yaw: number, value: number, cursed: boolean, now: number)
	local log = createLog(position, yaw, value, cursed)
	log:SetAttribute("PopFrom", position + Vector3.new(0, Config.Logs.PopStart, 0))
	log:SetAttribute("SpawnedAt", now)
	log.Parent = logsFolder
	CollectionService:AddTag(log, Tags.Log)
end

-- Drop logs on the ground along a fallen tree, starting at `origin` and going along `direction`.
-- Each log is worth `value` coins. Called by TreeManager when a tree lands.
function LogManager.spawnLogs(origin: Vector3, direction: Vector3, length: number, count: number, value: number, cursed: boolean)
	local cfg = Config.Logs
	local random = Random.new()
	-- The fallen trunk lies from `origin` along `direction`, `length` long. It breaks into
	-- `count` logs lying end to end along it, like in Chop a Forest.
	local spacing = math.max(length / count, cfg.Length + cfg.Gap)
	local yaw = math.atan2(-direction.Z, direction.X) -- a log lies along its X axis
	local now = workspace:GetServerTimeNow()

	for i = 1, count do
		local along = origin + direction * (spacing * (i - 0.5))
		local position = along + Vector3.new(0, cfg.Thickness / 2, 0)
		addLog(position, yaw + random:NextNumber(-0.08, 0.08), value, cursed, now)
	end
end

-- Someone died: their logs drop around where they fell, and are worth the same as before.
local function dropLogs(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local count, value = LogManager.takeAll(player)
	if count <= 0 then
		return
	end
	droppedLogs[player] = count

	local cfg = Config.Logs
	local shown = math.min(count, cfg.MaxDropped)
	local each = value // shown
	local extra = value % shown -- the coins that don't share out evenly go on the first few logs

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, logsFolder }
	local ground = workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -50, 0), params)
	local y = if ground then ground.Position.Y else root.Position.Y - 3

	local random = Random.new()
	local now = workspace:GetServerTimeNow()
	for i = 1, shown do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(1, cfg.DropSpread)
		local position = Vector3.new(
			root.Position.X + math.cos(angle) * distance,
			y + cfg.Thickness / 2,
			root.Position.Z + math.sin(angle) * distance
		)
		addLog(position, random:NextNumber(0, math.pi * 2), each + (if i <= extra then 1 else 0), false, now)
	end
end

-- Is this log still popping out of its tree? (Server time, so it's the same on every computer.)
function LogManager.isPopping(log: Instance): boolean
	local spawnedAt = log:GetAttribute("SpawnedAt")
	return typeof(spawnedAt) == "number" and workspace:GetServerTimeNow() - spawnedAt < Config.Logs.PopTime
end

local function onCharacterAdded(player: Player, character: Model)
	local dropped = droppedLogs[player]
	if dropped then
		droppedLogs[player] = nil
		notifyRemote:FireClient(player, string.format(Config.Logs.Text.Dropped, dropped))
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Once(function()
			dropLogs(player, character)
			AnalyticsManager.event(player, "Died")
		end)
	end
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Carry", 0)
	player:SetAttribute("CarryValue", 0)
	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(onCharacterAdded, player, character)
	end
end

function LogManager.init()
	logsFolder = Instance.new("Folder")
	logsFolder.Name = "Logs"
	logsFolder.Parent = workspace
end

function LogManager.start()
	notifyRemote = Remotes.getEvent("Notify")

	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this ran (can happen in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		droppedLogs[player] = nil
	end)
end

return LogManager
