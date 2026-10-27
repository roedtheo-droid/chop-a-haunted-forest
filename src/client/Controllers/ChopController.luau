--!strict
-- Click (or tap) a tree to swing at it.
-- The client only tells the server WHICH tree. The server checks distance and
-- cooldown and decides the damage, so changing numbers here can't cheat.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)

local MAX_CLICK_DISTANCE = 200

local ChopController = {}

local player = Players.LocalPlayer
local swingRemote: RemoteEvent
local lastSwing = 0

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

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	-- gameProcessed is true when the click was on a button or the mobile joystick.
	if gameProcessed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	-- Don't spam the server faster than the server would accept anyway.
	local now = os.clock()
	if now - lastSwing < Config.Fists.Cooldown then
		return
	end

	local tree = findTreeAt(input.Position)
	if tree then
		lastSwing = now
		swingRemote:FireServer(tree)
	end
end

function ChopController.init()
	swingRemote = Remotes.getEvent("SwingAtTree")
end

function ChopController.start()
	UserInputService.InputBegan:Connect(onInputBegan)
end

return ChopController
