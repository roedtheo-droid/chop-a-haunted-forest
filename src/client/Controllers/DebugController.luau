--!strict
-- Studio-only test buttons. In the real game this does nothing.
-- "Skip to boss" asks the server to clear the forest and move you to the Elder Hollow.
-- "+ Coins" asks the server for Config.DebugCoins coins (click as often as you like).
-- The server checks again that it's running in Studio (see Server/Systems/DebugManager).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.Parent.UiKit)

local BUTTON_COLOR = Color3.fromRGB(150, 50, 60) -- red-ish, so it's clearly not part of the game
local CLICK_COOLDOWN = 2 -- seconds, so a double click doesn't send it twice
local COINS_COOLDOWN = 0.2 -- seconds; short, so you can click a few times quickly

local DebugController = {}

local player = Players.LocalPlayer
local button: TextButton? = nil
local coinsButton: TextButton? = nil

function DebugController.init()
	if not (RunService:IsStudio() and Config.StudioShortcuts) then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "StudioShortcuts"
	gui.ResetOnSpawn = false

	-- Left side, a bit above the middle (the right side has the coins and quests).
	local newButton = UiKit.button(gui, "SkipToBoss", "STUDIO: Skip to boss", BUTTON_COLOR)
	newButton.AnchorPoint = Vector2.new(0, 0.5)
	newButton.Position = UDim2.new(0, 16, 0.45, 0)
	newButton.Size = UDim2.fromOffset(190, 40)

	-- Right under Skip to boss.
	local newCoinsButton = UiKit.button(gui, "GiveCoins", `STUDIO: +{Config.DebugCoins} Coins`, BUTTON_COLOR)
	newCoinsButton.AnchorPoint = Vector2.new(0, 0.5)
	newCoinsButton.Position = UDim2.new(0, 16, 0.45, 48)
	newCoinsButton.Size = UDim2.fromOffset(190, 40)

	gui.Parent = player:WaitForChild("PlayerGui")
	button = newButton
	coinsButton = newCoinsButton
end

function DebugController.start()
	local skipButton = button
	if not skipButton then
		return -- not in Studio
	end
	local remote = Remotes.getEvent("DebugSkipToBoss")
	local lastClick = 0
	skipButton.Activated:Connect(function()
		local now = os.clock()
		if now - lastClick < CLICK_COOLDOWN then
			return
		end
		lastClick = now
		remote:FireServer()
	end)

	local giveButton = coinsButton
	if giveButton then
		local coinsRemote = Remotes.getEvent("DebugGiveCoins")
		local lastCoinsClick = 0
		giveButton.Activated:Connect(function()
			local now = os.clock()
			if now - lastCoinsClick < COINS_COOLDOWN then
				return
			end
			lastCoinsClick = now
			coinsRemote:FireServer()
		end)
	end
end

return DebugController
