--!strict
-- Hold Shift to sprint. Phones and tablets get a "Sprint" button to hold instead.
-- This only tells the server "sprinting" or "stopped"; the server sets the actual speed,
-- so changing numbers here can't make anyone faster.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ACTION = "Sprint"

local SprintController = {}

local sprintRemote: RemoteEvent
local sprinting = false

local function setSprinting(on: boolean)
	if on ~= sprinting then
		sprinting = on
		sprintRemote:FireServer(on)
	end
end

local function onSprintAction(
	_actionName: string,
	inputState: Enum.UserInputState,
	_input: InputObject
): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		setSprinting(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		setSprinting(false)
	end
	-- "Sink" so Shift doesn't also switch Roblox's Shift Lock camera on and off.
	return Enum.ContextActionResult.Sink
end

function SprintController.init()
	sprintRemote = Remotes.getEvent("SetSprint")
end

function SprintController.start()
	-- The `true` makes Roblox add an on-screen button on touch screens.
	ContextActionService:BindActionAtPriority(
		ACTION,
		onSprintAction,
		true,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift,
		Enum.KeyCode.ButtonL3
	)
	ContextActionService:SetTitle(ACTION, "Sprint")
end

return SprintController
