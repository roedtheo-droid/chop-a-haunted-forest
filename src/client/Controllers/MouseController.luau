--!strict
-- Left Alt frees the mouse in first person, so you can move it out of the game window
-- (or click something else) without opening a menu. Press Left Alt again to lock it.
-- A small hint in the bottom-left corner says what the key does right now.
--
-- It frees the mouse the same way the menus do (UiKit.freeMouse): a screen with an invisible
-- "Modal" button. While that screen is on, ViewmodelController hides the crosshair and shows
-- the mouse, and ChopController ignores clicks (MouseController.isFree), so you don't punch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local UiKit = require(script.Parent.Parent.UiKit)
local ViewmodelController = require(script.Parent.ViewmodelController)

local cfg = Config.FreeMouse

local MouseController = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui
local freeGui: ScreenGui -- switched on while the mouse is free
local hintGui: ScreenGui
local hint: TextLabel
local free = false

-- Is the mouse freed with Left Alt right now?
function MouseController.isFree(): boolean
	return free
end

-- Is another screen open that already frees the mouse (a menu, the Garage)?
local function otherMenuOpen(): boolean
	for _, gui in playerGui:GetChildren() do
		if
			gui ~= freeGui
			and gui:IsA("ScreenGui")
			and gui.Enabled
			and (gui:GetAttribute(UiKit.FREES_MOUSE) or gui:GetAttribute(UiKit.HIDES_ARMS))
		then
			return true
		end
	end
	return false
end

-- Left Alt only matters in first person (after the intro), with a keyboard, and when no
-- menu has freed the mouse already.
local function canToggle(): boolean
	return ViewmodelController.isActive() and UserInputService.KeyboardEnabled and not otherMenuOpen()
end

local function setFree(on: boolean)
	free = on
	freeGui.Enabled = on
	hint.Text = if on then cfg.LockText else cfg.FreeText
end

function MouseController.init()
	playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	freeGui = Instance.new("ScreenGui")
	freeGui.Name = "FreeMouse"
	freeGui.ResetOnSpawn = false
	freeGui.Enabled = false
	UiKit.freeMouse(freeGui)
	freeGui.Parent = playerGui

	hintGui = Instance.new("ScreenGui")
	hintGui.Name = "FreeMouseHint"
	hintGui.ResetOnSpawn = false
	UiKit.hudScale(hintGui) -- the same size as the rest of the HUD
	hint = UiKit.smallText(hintGui, "Hint", cfg.FreeText)
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, cfg.HintMargin, 1, -cfg.HintMargin)
	hint.Size = UDim2.fromOffset(cfg.HintWidth, cfg.HintHeight)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextTransparency = cfg.HintTransparency
	hint.Visible = false
	hintGui.Parent = playerGui
end

function MouseController.start()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		-- gameProcessed is true while you type in the chat.
		if gameProcessed or input.KeyCode ~= cfg.Key then
			return
		end
		if free then
			setFree(false)
		elseif canToggle() then
			setFree(true)
		end
	end)

	RunService.Heartbeat:Connect(function()
		-- If first person turns off or a menu opens, the menu takes over the mouse.
		if free and not ViewmodelController.isActive() then
			setFree(false)
		end
		local show = canToggle() or free
		if hint.Visible ~= show then
			hint.Visible = show
		end
	end)
end

return MouseController
