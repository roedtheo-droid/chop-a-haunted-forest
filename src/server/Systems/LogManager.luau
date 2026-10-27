--!strict
-- Handles logs on the ground and how many logs each player carries.
--
-- Each player has two attributes the client can read (but not change):
--   Carry       how many logs they carry now
--   CarryLimit  how many logs fit in their backpack (set by UpgradeManager)
-- Logs get a ProximityPrompt ("Pick up"). Prompts are triggered on the server,
-- so the server always decides whether a pickup is allowed.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local QuestManager = require(script.Parent.QuestManager)

local LOG_COLOR = Color3.fromRGB(130, 90, 55)

local LogManager = {}

local logsFolder: Folder
local notifyRemote: RemoteEvent

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

-- Empty the player's backpack and return how many logs were in it.
-- Used by the sawmill when the player sells.
function LogManager.takeAll(player: Player): number
	local carry = LogManager.getCarry(player)
	LogManager.setCarry(player, 0)
	return carry
end

function LogManager.hasRoom(player: Player): boolean
	return LogManager.getCarry(player) < getNumberAttribute(player, "CarryLimit")
end

-- All logs lying on the ground right now.
function LogManager.getLogs(): { Instance }
	return logsFolder:GetChildren()
end

-- Put a log in the player's backpack. Returns false if the backpack is full
-- or the log is already gone. Used by the "Pick up" prompt and the Log Vacuum.
function LogManager.tryPickUp(player: Player, log: BasePart): boolean
	-- Two players could grab the same log at the same moment; only the first one gets it.
	if log.Parent == nil or not LogManager.hasRoom(player) then
		return false
	end

	log:Destroy()
	LogManager.setCarry(player, LogManager.getCarry(player) + 1)
	QuestManager.report(player, "PickUpLog")
	return true
end

local function onPickUp(log: BasePart, player: Player)
	if log.Parent ~= nil and not LogManager.tryPickUp(player, log) then
		notifyRemote:FireClient(player, "Your backpack is full!")
	end
end

local function createLog(position: Vector3, yaw: number): BasePart
	local cfg = Config.Logs

	-- A cylinder lies along its X axis, which is exactly how a log lies on the ground.
	local log = Instance.new("Part")
	log.Name = "Log"
	log.Shape = Enum.PartType.Cylinder
	log.Size = Vector3.new(cfg.Length, cfg.Thickness, cfg.Thickness)
	log.CFrame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	log.Color = LOG_COLOR
	log.Material = Enum.Material.Wood
	log.Anchored = true
	log.CanCollide = false -- so players don't trip over logs

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = "Log"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = cfg.PickupDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = log

	prompt.Triggered:Connect(function(player: Player)
		onPickUp(log, player)
	end)

	return log
end

-- Drop logs on the ground in a line, starting at `origin` and going along `direction`.
-- Called by TreeManager when a tree falls.
function LogManager.spawnLogs(origin: Vector3, direction: Vector3, count: number)
	local random = Random.new()
	local spacing = Config.Tree.TrunkHeight / (count + 1)
	local side = Vector3.yAxis:Cross(direction)

	for i = 1, count do
		local offset = direction * (spacing * i) + side * random:NextNumber(-1.5, 1.5)
		local position = origin + offset + Vector3.new(0, Config.Logs.Thickness / 2, 0)
		local log = createLog(position, random:NextNumber(0, math.pi * 2))
		log.Parent = logsFolder
		CollectionService:AddTag(log, Tags.Log)
	end
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Carry", 0)
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
end

return LogManager
