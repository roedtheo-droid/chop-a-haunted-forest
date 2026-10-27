--!strict
-- Handles logs on the ground and how many logs each player carries.
--
-- Each player has two attributes the client can read (but not change):
--   Carry       how many logs they carry now
--   CarryLimit  how many logs fit in their backpack
-- Logs get a ProximityPrompt ("Pick up"). Prompts are triggered on the server,
-- so the server always decides whether a pickup is allowed.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)

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

local function onPickUp(log: BasePart, player: Player)
	-- Two players could press E on the same log at the same moment; only the first one gets it.
	if log.Parent == nil then
		return
	end

	local carry = LogManager.getCarry(player)
	local limit = getNumberAttribute(player, "CarryLimit")
	if carry >= limit then
		notifyRemote:FireClient(player, "Your backpack is full!")
		return
	end

	log:Destroy()
	LogManager.setCarry(player, carry + 1)
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
	player:SetAttribute("CarryLimit", Config.Logs.CarryLimit)
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
