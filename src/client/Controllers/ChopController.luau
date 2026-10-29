--!strict
-- Click (or tap) a tree to swing at it. Hold the button to keep chopping.
-- In first person (Config.FirstPerson) you aim with the crosshair in the middle of the screen,
-- and ViewmodelController swings your fists or tool.
-- The client only tells the server WHICH tree. The server checks distance and
-- cooldown and decides the damage, so changing numbers here can't cheat.
--
-- To make chopping feel instant, your computer doesn't wait for the server before it shows
-- anything: your character swings right away, and when the swing lands
-- (Config.ChopEffects.ImpactDelay later) ChopEffectsController draws the hit. It checks the
-- same rules as the server (Shared/ChopRules), so its guess is almost always right.

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ChopRules = require(ReplicatedStorage.Shared.ChopRules)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Types = require(ReplicatedStorage.Shared.Types)
local Zones = require(ReplicatedStorage.Shared.Zones)
local ChopEffectsController = require(script.Parent.ChopEffectsController)
local ViewmodelController = require(script.Parent.ViewmodelController)

local MAX_CLICK_DISTANCE = 200

local ChopController = {}

local player = Players.LocalPlayer
local swingRemote: RemoteEvent
local lastSwing = 0
local holding = false -- is the mouse button / finger held down?
local pointer = Vector3.zero -- where on the screen the mouse or finger is
local swingTracks: { [string]: AnimationTrack } = {} -- swing animations loaded on your character

-- Tags of things you can swing at.
local SWINGABLE = { Tags.Tree, Tags.AwakeMimic, Tags.ElderHollow, Tags.BossRoot }
-- Tags of things whose hits your computer draws right away. (Boss hits are all up to the server.)
local CHOPPABLE = { Tags.Tree, Tags.AwakeMimic }

local function hasAnyTag(model: Model, tags: { string }): boolean
	for _, tag in tags do
		if CollectionService:HasTag(model, tag) then
			return true
		end
	end
	return false
end

-- The ray from the camera through what you're aiming at: the crosshair in the middle of the
-- screen in first person (see ViewmodelController), otherwise the mouse or your finger.
local function aimRay(): Ray?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	if ViewmodelController.isActive() then
		local size = camera.ViewportSize
		return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	end
	return camera:ScreenPointToRay(pointer.X, pointer.Y)
end

-- Find the tree (or awake mimic, or the boss or one of its roots) you're aiming at, and the
-- point where the aim touches it.
local function findTree(): (Model?, Vector3?)
	local ray = aimRay()
	if not ray then
		return nil, nil
	end

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
		return nil, nil
	end

	local model = result.Instance:FindFirstAncestorWhichIsA("Model")
	if model and hasAnyTag(model, SWINGABLE) then
		return model, result.Position
	end
	return nil, nil
end

local function getTrunk(tree: Model): BasePart?
	local trunk = tree:FindFirstChild("Trunk")
	return if trunk and trunk:IsA("BasePart") then trunk else nil
end

local function getHead(): BasePart?
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	return if head and head:IsA("BasePart") then head else nil
end

-- The id of the tool we're holding ("Fists" if none).
local function heldToolId(): string
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	local toolId = if tool then tool:GetAttribute("ToolId") else nil
	if typeof(toolId) == "string" and Config.Tools[toolId] then
		return toolId
	end
	return "Fists"
end

-- Play the tool's swing on your character. Animations you play on your own character
-- show for everyone automatically, so this needs no remote.
local function playSwing(feel: Types.ChopFeelConfig)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if not animator then
		return
	end
	local track = swingTracks[feel.Swing]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = feel.Swing
		local loaded = animator:LoadAnimation(animation)
		loaded.Priority = Enum.AnimationPriority.Action -- above walking and holding a tool
		loaded.Looped = false
		swingTracks[feel.Swing] = loaded
		track = loaded
	end
	if track.IsPlaying then
		-- Fast tools (the Chainsaw) swing again before the last swing ended: start it over.
		track.TimePosition = 0
		track:AdjustSpeed(feel.SwingSpeed)
		track:AdjustWeight(feel.SwingSize)
	else
		track:Play(0.05, feel.SwingSize, feel.SwingSpeed)
	end
end

-- Will the server count this hit? The same checks as Server/Systems/TreeManager, using only
-- what this computer can see. (It can't see which trees are mimics, and doesn't need to.)
local function willCount(tree: Model, toolId: string, point: Vector3): boolean
	if Config.Tools[toolId].Damage <= 0 then
		return false -- the Torch doesn't chop
	end
	if not tree:IsDescendantOf(workspace) or not hasAnyTag(tree, CHOPPABLE) then
		return false -- someone else just chopped it down, or it's the boss
	end
	local trunk = getTrunk(tree)
	local head = getHead()
	if not (trunk and head and ChopRules.pointOnTrunk(trunk, point)) then
		return false -- you hit its leaves or roots, not the trunk
	end
	if not ChopRules.pointInReach(head.Position, point, toolId) then
		return false
	end
	-- Trees behind a closed gate can't be chopped.
	local zoneState = ReplicatedStorage:FindFirstChild(Zones.StateFolderName)
	local zone = if zoneState then zoneState:FindFirstChild(tostring(tree:GetAttribute("ZoneId"))) else nil
	return zone == nil or zone:GetAttribute("Open") ~= false
end

local function trySwing()
	local toolId = heldToolId()
	if toolId == "Lantern" then
		return -- the Lantern is for looking, not hitting (the server ignores it too)
	end
	if player:GetAttribute("KnockedDown") == true then
		return -- you can't swing while you're lying on the ground
	end
	-- Don't spam the server faster than the server would accept anyway.
	local now = os.clock()
	local cooldown = Config.Tools[toolId].Cooldown
	if now - lastSwing < cooldown then
		return
	end
	-- The Torch has no feel of its own: it swings like Fists.
	local feel = Config.ChopFeel[toolId] or Config.ChopFeel.Fists

	local tree, aimedAt = findTree()
	-- In first person your fists (or tool) swing on every click, even at thin air. A punch
	-- reaches for the bark you aim at and bounces off it if the hit will count.
	if ViewmodelController.isActive() then
		lastSwing = now
		local camera = workspace.CurrentCamera
		local distance = if aimedAt and camera then (aimedAt - camera.CFrame.Position).Magnitude else nil
		local hit = tree ~= nil and aimedAt ~= nil and willCount(tree, toolId, aimedAt)
		ViewmodelController.swing(cooldown, feel.SwingSize, distance, hit)
	end
	if not (tree and aimedAt) then
		return
	end
	lastSwing = now
	playSwing(feel)

	-- Remember the point on the tree itself, so it's still right if the tree moves (an awake
	-- mimic) before the swing lands. The boss has no Trunk: the server ignores its point anyway.
	local trunk = getTrunk(tree)
	local onTrunk = if trunk then trunk.CFrame:PointToObjectSpace(aimedAt) else aimedAt

	-- The hit lands partway through the swing.
	task.delay(Config.ChopEffects.ImpactDelay, function()
		local point = if trunk then trunk.CFrame:PointToWorldSpace(onTrunk) else aimedAt
		swingRemote:FireServer(tree, point)
		if willCount(tree, toolId, point) then
			ChopEffectsController.showMyHit(tree, toolId, point)
		end
	end)
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

	-- A new character needs its swing animations loaded again.
	player.CharacterAdded:Connect(function()
		table.clear(swingTracks)
	end)

	-- Hold the button to keep chopping, one swing per cooldown.
	RunService.Heartbeat:Connect(function()
		if holding then
			trySwing()
		end
	end)

	-- Load the swing now, so the very first swing doesn't wait for it.
	-- PreloadAsync needs Animation objects: a plain id would be loaded as a picture, and fail.
	local ids: { string } = {}
	for _, feel in Config.ChopFeel do
		if not table.find(ids, feel.Swing) then
			table.insert(ids, feel.Swing)
		end
	end
	local swings: { Instance } = {}
	for _, id in ids do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		table.insert(swings, animation)
	end
	ContentProvider:PreloadAsync(swings)
end

return ChopController
