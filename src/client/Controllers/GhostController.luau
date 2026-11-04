--!strict
-- The Ghost Vacuum on your side: when you click (or tap) while holding it, we tell the
-- server "I clicked". The server finds the ghost in front of you, sucks it in and gives you
-- coins and courage (see Server/Systems/GhostManager). We send no positions or numbers,
-- so there's nothing to cheat with.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GhostController = {}

local player = Players.LocalPlayer
local vacuumRemote: RemoteEvent
local lastClick = 0

local function holdsVacuum(): boolean
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	return tool ~= nil and tool:GetAttribute("ToolId") == "GhostVacuum"
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	-- gameProcessed is true when the click was on a button or the mobile joystick.
	if gameProcessed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if not holdsVacuum() or player:GetAttribute("KnockedDown") == true then
		return
	end
	-- Don't ask faster than the server would accept anyway.
	local now = os.clock()
	if now - lastClick < Config.Tools.GhostVacuum.Cooldown then
		return
	end
	lastClick = now
	vacuumRemote:FireServer()
end

function GhostController.init() end

function GhostController.start()
	vacuumRemote = Remotes.getEvent("VacuumGhost")
	UserInputService.InputBegan:Connect(onInputBegan)
end

return GhostController
