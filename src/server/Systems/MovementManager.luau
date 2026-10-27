--!strict
-- Decides every player's walk speed and jump, all in one place:
--   walk speed = base speed + WalkSpeed upgrade + sprint bonus (while sprinting)
--   knocked down by a mimic = can't walk or jump at all
-- The client only says "I'm sprinting" or "I stopped"; the server picks the numbers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)

local MovementManager = {}

local sprinting: { [Player]: boolean } = {}

-- Set the speed and jump again. Call this whenever something that changes them happens
-- (an upgrade, sprinting, getting knocked down or back up, a new character).
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

	local level = player:GetAttribute(Shop.levelAttribute("WalkSpeed"))
	local speed = Config.Player.BaseWalkSpeed
		+ (if typeof(level) == "number" then level else 0) * Config.Upgrades.WalkSpeed.PerLevel
	if sprinting[player] then
		speed += Config.Player.SprintBonus
	end
	humanoid.WalkSpeed = speed
	-- Jumping goes back to the place's normal settings (StarterPlayer in Studio).
	humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
	humanoid.JumpPower = StarterPlayer.CharacterJumpPower
end

local function onSetSprint(player: Player, on: unknown)
	if typeof(on) ~= "boolean" then
		return
	end
	sprinting[player] = on
	MovementManager.refresh(player)
end

local function onPlayerAdded(player: Player)
	-- A new character gets Roblox's default speed, so set ours again.
	player.CharacterAdded:Connect(function(character: Model)
		character:WaitForChild("Humanoid")
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
	end)
end

return MovementManager
