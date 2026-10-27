--!strict
-- Click (or tap) a tree to swing at it. Hold the button to keep chopping.
-- The client only tells the server WHICH tree. The server checks distance and
-- cooldown and decides the damage, so changing numbers here can't cheat.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)

local MAX_CLICK_DISTANCE = 200

local ChopController = {}

local player = Players.LocalPlayer
local swingRemote: RemoteEvent
local lastSwing = 0
local holding = false -- is the mouse button / finger held down?
local pointer = Vector3.zero -- where on the screen the mouse or finger is

-- Find the tree (if any) under a point on the screen.
local function findTreeAt(screenPosition: Vector3): Model?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	local character = player.Character
	if character then
		table.insert(ignore, character)
	end
	params.FilterDescendantsInstances = ignore

	local result = workspace:Raycast(ray.Origin, ray.Direction * MAX_CLICK_DISTANCE, params)
	if not result then
		return nil
	end

	local model = result.Instance:FindFirstAncestorWhichIsA("Model")
	if model and CollectionService:HasTag(model, Tags.Tree) then
		return model
	end
	return nil
end

-- The cooldown of the tool we're holding (the server checks this too).
local function currentCooldown(): number
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	local toolId = if tool then tool:GetAttribute("ToolId") else nil
	if typeof(toolId) == "string" and Config.Tools[toolId] then
		return Config.Tools[toolId].Cooldown
	end
	return Config.Tools.Fists.Cooldown
end

local function trySwing()
	-- Don't spam the server faster than the server would accept anyway.
	local now = os.clock()
	if now - lastSwing < currentCooldown() then
		return
	end

	local tree = findTreeAt(pointer)
	if tree then
		lastSwing = now
		swingRemote:FireServer(tree)
	end
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	-- gameProcessed is true when the click was on a button or the mobile joystick.
	if gameProcessed or not isPress(input) then
		return
	end
	holding = true
	pointer = input.Position
	trySwing()
end

local function onInputChanged(input: InputObject)
	-- Follow the mouse (or finger) so you can hold and sweep across a tree.
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		pointer = input.Position
	end
end

local function onInputEnded(input: InputObject)
	if isPress(input) then
		holding = false
	end
end

function ChopController.init()
	swingRemote = Remotes.getEvent("SwingAtTree")
end

function ChopController.start()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)

	-- Hold the button to keep chopping, one swing per cooldown.
	RunService.Heartbeat:Connect(function()
		if holding then
			trySwing()
		end
	end)
end

return ChopController
