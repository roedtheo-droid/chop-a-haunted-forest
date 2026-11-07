--!strict
-- Decides every player's walk speed and jump, all in one place:
--   walk speed = base speed + WalkSpeed upgrade + sprint bonus (while sprinting)
--   knocked down, or inside a mimic = can't walk or jump at all
-- Sprinting uses up stamina, and when it's gone you walk until it has filled up a bit. In the camp
-- it doesn't run out, because nothing chases you there.
-- The client only says "I'm sprinting" or "I stopped"; the server picks the numbers and keeps the
-- stamina. The client shows it from two player attributes that only the server sets:
--   Stamina  how much is left (0 to Config.Player.Stamina.Max)
--   Tired    true from running out until you can sprint again

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Zones = require(ReplicatedStorage.Shared.Zones)

local MovementManager = {}

local sprinting: { [Player]: boolean } = {}
local stamina: { [Player]: number } = {}
local restAt: { [Player]: number } = {} -- when stamina starts filling up again (os.clock)

local function isTired(player: Player): boolean
	return player:GetAttribute("Tired") == true
end

-- How fast this player walks, without sprinting. (Mimics chase a little faster than this.)
function MovementManager.walkSpeedOf(player: Player): number
	local level = player:GetAttribute(Shop.levelAttribute("WalkSpeed"))
	return Config.Player.BaseWalkSpeed + (if typeof(level) == "number" then level else 0) * Config.Upgrades.WalkSpeed.PerLevel
end

-- Set the speed and jump again. Call this whenever something that changes them happens
-- (an upgrade, sprinting, running out of stamina, getting knocked down or back up, a new character).
function MovementManager.refresh(player: Player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return
	end

	if player:GetAttribute("KnockedDown") == true then
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
		return
	end

	local speed = MovementManager.walkSpeedOf(player)
	if sprinting[player] and not isTired(player) then
		speed += Config.Player.SprintBonus
	end
	humanoid.WalkSpeed = speed
	-- Jumping goes back to the place's normal settings (StarterPlayer in Studio).
	humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
	humanoid.JumpPower = StarterPlayer.CharacterJumpPower
end

local function setStamina(player: Player, value: number)
	stamina[player] = value
	local shown = math.round(value)
	if player:GetAttribute("Stamina") ~= shown then
		player:SetAttribute("Stamina", shown)
	end
end

-- Is this player really using up stamina: running on their own feet, away from the camp?
-- (Holding Shift while standing still or driving doesn't count.)
local function isRunning(player: Player): boolean
	if not sprinting[player] or isTired(player) then
		return false
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (humanoid and root and root:IsA("BasePart")) or humanoid.Sit then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	return Vector2.new(velocity.X, velocity.Z).Magnitude >= Config.Player.Stamina.MovingSpeed and not Zones.isInCamp(root.Position)
end

local function updateStamina(player: Player, dt: number)
	local cfg = Config.Player.Stamina
	local value = stamina[player] or cfg.Max
	if isRunning(player) then
		value = math.max(value - cfg.Drain * dt, 0)
		restAt[player] = os.clock() + cfg.RegenDelay
		setStamina(player, value)
		if value <= 0 then
			player:SetAttribute("Tired", true)
			MovementManager.refresh(player)
		end
	elseif value < cfg.Max and os.clock() >= (restAt[player] or 0) then
		value = math.min(value + cfg.Regen * dt, cfg.Max)
		setStamina(player, value)
		if isTired(player) and value >= cfg.RecoverAt then
			player:SetAttribute("Tired", false)
			MovementManager.refresh(player)
		end
	end
end

local function fillStamina(player: Player)
	setStamina(player, Config.Player.Stamina.Max)
	player:SetAttribute("Tired", false)
end

local function onSetSprint(player: Player, on: unknown)
	if typeof(on) ~= "boolean" then
		return
	end
	sprinting[player] = on
	MovementManager.refresh(player)
end

local function onPlayerAdded(player: Player)
	fillStamina(player)
	-- A new character gets Roblox's default speed, so set ours again.
	player.CharacterAdded:Connect(function(character: Model)
		character:WaitForChild("Humanoid")
		fillStamina(player)
		MovementManager.refresh(player)
	end)
	MovementManager.refresh(player)
end

function MovementManager.init() end

function MovementManager.start()
	Remotes.getEvent("SetSprint").OnServerEvent:Connect(onSetSprint)

	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this ran (can happen in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		sprinting[player] = nil
		stamina[player] = nil
		restAt[player] = nil
	end)

	task.spawn(function()
		while true do
			local dt = task.wait(Config.Player.Stamina.Tick)
			for _, player in Players:GetPlayers() do
				updateStamina(player, dt)
			end
		end
	end)
end

return MovementManager
