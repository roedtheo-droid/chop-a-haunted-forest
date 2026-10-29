--!strict
-- Mr. Graves, the landowner at the vault (see Config.Landowner and Server/Systems/LandownerManager),
-- on this player's screen:
--   * his relaxed idle: he breathes, leans a little and slowly looks around
--   * a small red bird that hops around on the grass in front of the vault
--   * the dialogue box that opens when you press E on his "Talk" prompt: a round portrait,
--     a gold name tag and his line typing out letter by letter. It hides by itself a moment
--     after you walk away.
-- All of it is only for looks. Which line he says depends on whether the Elder Hollow has
-- been beaten (the boss state the server shares, see Shared/Boss).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Boss = require(ReplicatedStorage.Shared.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local UiKit = require(script.Parent.Parent.UiKit)

local ANIMATE_DISTANCE = 200 -- his idle only plays when your camera is this close
local PORTRAIT_SIZE = 116
local BOX_HEIGHT = 96

local LandownerController = {}

type NpcPart = { Part: BasePart, Group: string, Offset: CFrame }
type Npc = {
	Model: Model,
	Pivot: CFrame,
	Parts: { NpcPart },
	Hip: Vector3,
	Neck: Vector3,
	ShoulderL: Vector3,
	ShoulderR: Vector3,
}

type BirdPiece = { Part: BasePart, Offset: CFrame }
type Bird = {
	Pieces: { BirdPiece },
	Home: Vector3,
	From: Vector3,
	To: Vector3,
	Facing: number, -- which way it looks (radians around Y)
	HopStart: number,
	RestUntil: number,
	Random: Random,
}

local player = Players.LocalPlayer
local npcs: { [Model]: Npc } = {}
local birds: { Bird } = {}

local gui: ScreenGui
local holder: Frame
local lineLabel: TextLabel
local viewport: ViewportFrame
local talkingTo: BasePart? -- the part his prompt is on, while the box is open
local talkId = 0 -- goes up with every talk, so an old typing loop stops
local farSince: number? = nil -- when you walked out of range (nil while you're close)

local function vectorAttribute(model: Model, name: string): Vector3
	local value = model:GetAttribute(name)
	return if typeof(value) == "Vector3" then value else Vector3.zero
end

-- Remember where every piece of him stands, so the idle can move them from there.
local function addNpc(instance: Instance)
	if not instance:IsA("Model") or npcs[instance] then
		return
	end
	local pivot = instance:GetPivot()
	local parts: { NpcPart } = {}
	for _, part in instance:GetChildren() do
		local group = part:GetAttribute("Group")
		if part:IsA("BasePart") and typeof(group) == "string" then
			table.insert(parts, { Part = part, Group = group, Offset = pivot:ToObjectSpace(part.CFrame) })
		end
	end
	npcs[instance] = {
		Model = instance,
		Pivot = pivot,
		Parts = parts,
		Hip = vectorAttribute(instance, "Hip"),
		Neck = vectorAttribute(instance, "Neck"),
		ShoulderL = vectorAttribute(instance, "ShoulderL"),
		ShoulderR = vectorAttribute(instance, "ShoulderR"),
	}
end

-- Turn `angles` around `point` (both in his own space).
local function around(point: Vector3, angles: CFrame): CFrame
	return CFrame.new(point) * angles * CFrame.new(-point)
end

local function animateNpc(npc: Npc, now: number, cameraPosition: Vector3)
	if (npc.Pivot.Position - cameraPosition).Magnitude > ANIMATE_DISTANCE then
		return
	end
	local cfg = Config.Landowner
	local breath = math.sin(now * cfg.BreatheSpeed)
	local body = around(npc.Hip, CFrame.Angles(0, 0, math.rad(cfg.SwayAngle) * math.sin(now * cfg.BreatheSpeed * 0.5)))
		* CFrame.new(0, breath * cfg.BreatheHeight, 0)
	local swing = math.rad(cfg.ArmSwingAngle) * breath
	local groups: { [string]: CFrame } = {
		Legs = CFrame.identity,
		Body = body,
		Head = body * around(npc.Neck, CFrame.Angles(0, math.rad(cfg.HeadTurnAngle) * math.sin(now * 0.35), 0)),
		ArmL = body * around(npc.ShoulderL, CFrame.Angles(swing, 0, 0)),
		ArmR = body * around(npc.ShoulderR, CFrame.Angles(-swing, 0, 0)),
	}
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for _, info in npc.Parts do
		if info.Part.Parent then
			table.insert(parts, info.Part)
			table.insert(cframes, npc.Pivot * (groups[info.Group] or CFrame.identity) * info.Offset)
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- A small blocky red bird near `home`, built on this computer only.
local function addBird(home: Vector3)
	local cfg = Config.Landowner
	local folder = Instance.new("Model")
	folder.Name = "Bird"
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3): BirdPiece
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = folder
		return { Part = part, Offset = offset }
	end
	local red = cfg.BirdColor
	local pieces = {
		piece("Body", Vector3.new(0.45, 0.4, 0.6), CFrame.new(0, 0.38, 0), red),
		piece("Belly", Vector3.new(0.36, 0.25, 0.4), CFrame.new(0, 0.3, -0.12), Color3.fromRGB(240, 150, 120)),
		piece("Head", Vector3.new(0.34, 0.34, 0.34), CFrame.new(0, 0.66, -0.26), red),
		piece("Beak", Vector3.new(0.12, 0.1, 0.18), CFrame.new(0, 0.63, -0.49), Color3.fromRGB(245, 170, 40)),
		piece("Eye", Vector3.new(0.36, 0.07, 0.07), CFrame.new(0, 0.72, -0.34), Color3.new(0, 0, 0)),
		piece("Tail", Vector3.new(0.25, 0.08, 0.35), CFrame.new(0, 0.48, 0.4) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(150, 25, 25)),
		piece("Leg", Vector3.new(0.05, 0.2, 0.05), CFrame.new(-0.1, 0.1, 0), Color3.fromRGB(245, 170, 40)),
		piece("Leg", Vector3.new(0.05, 0.2, 0.05), CFrame.new(0.1, 0.1, 0), Color3.fromRGB(245, 170, 40)),
	}
	folder.Parent = workspace

	local random = Random.new()
	table.insert(birds, {
		Pieces = pieces,
		Home = home,
		From = home,
		To = home,
		Facing = random:NextNumber(0, math.pi * 2),
		HopStart = -math.huge,
		RestUntil = 0,
		Random = random,
	})
end

local function groundAt(position: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = player.Character
	params.FilterDescendantsInstances = if character then { character } else {}
	local result = workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	return if result then result.Position.Y else position.Y
end

local function animateBird(bird: Bird, now: number)
	local cfg = Config.Landowner
	local t = (now - bird.HopStart) / cfg.BirdHopTime
	if t >= 1 and now >= bird.RestUntil then
		-- Pick a new spot near home, turn towards it and hop.
		local angle = bird.Random:NextNumber(0, math.pi * 2)
		local distance = bird.Random:NextNumber(0, cfg.BirdRadius)
		local spot = bird.Home + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		bird.From = bird.To
		bird.To = Vector3.new(spot.X, groundAt(spot), spot.Z)
		local flat = Vector3.new(bird.To.X - bird.From.X, 0, bird.To.Z - bird.From.Z)
		if flat.Magnitude > 0.05 then
			bird.Facing = math.atan2(-flat.X, -flat.Z)
		end
		bird.HopStart = now
		bird.RestUntil = now + cfg.BirdHopTime + bird.Random:NextNumber(cfg.BirdRest[1], cfg.BirdRest[2])
		t = 0
	end
	t = math.clamp(t, 0, 1)
	local position = bird.From:Lerp(bird.To, t) + Vector3.new(0, 4 * t * (1 - t) * 0.6, 0)
	-- Between hops it sometimes pecks at the grass.
	local peck = if t >= 1 and math.sin(now * 9) > 0.7 then math.rad(-30) else 0
	local root = CFrame.new(position) * CFrame.Angles(0, bird.Facing, 0) * CFrame.Angles(peck, 0, 0)
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for _, piece in bird.Pieces do
		table.insert(parts, piece.Part)
		table.insert(cframes, root * piece.Offset)
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- The dialogue box at the bottom centre: a round portrait on the left, a gold name tag
-- above the box and the text inside.
local function buildGui()
	local style = Config.Style
	gui = Instance.new("ScreenGui")
	gui.Name = "Dialogue"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 6

	holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -20)
	holder.Size = UDim2.new(0.9, 0, 0, PORTRAIT_SIZE + 14)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(660, math.huge)
	limit.Parent = holder

	local box = UiKit.box(holder, "Box")
	box.AnchorPoint = Vector2.new(0, 1)
	box.Position = UDim2.new(0, PORTRAIT_SIZE / 2, 1, -6)
	box.Size = UDim2.new(1, -PORTRAIT_SIZE / 2, 0, BOX_HEIGHT)

	lineLabel = UiKit.text(box, "Line", "")
	lineLabel.Position = UDim2.new(0, PORTRAIT_SIZE / 2 + 16, 0, 22)
	lineLabel.Size = UDim2.new(1, -(PORTRAIT_SIZE / 2 + 32), 1, -32)
	lineLabel.TextXAlignment = Enum.TextXAlignment.Left
	lineLabel.TextWrapped = true
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 28
	textLimit.Parent = lineLabel

	-- The gold name tag sits on the box's top edge, next to the portrait.
	local tag = Instance.new("Frame")
	tag.Name = "NameTag"
	tag.AnchorPoint = Vector2.new(0, 0.5)
	tag.Position = UDim2.new(0, PORTRAIT_SIZE + 6, 1, -6 - BOX_HEIGHT)
	tag.Size = UDim2.fromOffset(280, 32)
	tag.BackgroundColor3 = style.Gold
	tag.ZIndex = 3
	UiKit.corner(tag)
	UiKit.border(tag)
	tag.Parent = holder
	local name = UiKit.text(tag, "Name", Config.Landowner.NameTag)
	name.AnchorPoint = Vector2.new(0.5, 0.5)
	name.Position = UDim2.fromScale(0.5, 0.5)
	name.Size = UDim2.new(1, -16, 1, -8)
	name.ZIndex = 4

	-- The round portrait, on top of the box's left end.
	local frame = Instance.new("Frame")
	frame.Name = "Portrait"
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.new(0, 0, 1, 0)
	frame.Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE)
	frame.BackgroundColor3 = Color3.fromRGB(70, 82, 98)
	frame.ZIndex = 3
	UiKit.corner(frame, 999)
	UiKit.border(frame, style.Gold, 4)
	frame.Parent = holder
	viewport = Instance.new("ViewportFrame")
	viewport.Name = "Face"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(170, 170, 170)
	viewport.LightColor = Color3.fromRGB(255, 245, 230)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.ZIndex = 4
	UiKit.corner(viewport, 999)
	viewport.Parent = frame

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Put a copy of his head and shoulders in the portrait, with a camera looking at his face.
local function fillPortrait(model: Model)
	viewport:ClearAllChildren()
	UiKit.corner(viewport, 999)
	local copy = Instance.new("Model")
	for _, part in model:GetChildren() do
		local group = part:GetAttribute("Group")
		if part:IsA("BasePart") and (group == "Head" or group == "Body" or group == "ArmL" or group == "ArmR") then
			local clone = part:Clone()
			for _, child in clone:GetChildren() do
				child:Destroy() -- like the Talk prompt on his torso
			end
			clone.Parent = copy
		end
	end
	copy.Parent = viewport

	local pivot = model:GetPivot()
	local face = pivot * CFrame.new(vectorAttribute(model, "Neck") + Vector3.new(0, 0.5 * Config.Landowner.Scale, 0))
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	-- He faces his pivot's front (LookVector), so stand a few studs in front of him.
	camera.CFrame = CFrame.lookAt((face * CFrame.new(0.6, 0.2, -6.5)).Position, face.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function hide()
	talkId += 1
	talkingTo = nil
	farSince = nil
	gui.Enabled = false
end

local function talk(at: BasePart)
	local cfg = Config.Landowner
	local model = at:FindFirstAncestorOfClass("Model")
	if model then
		fillPortrait(model)
	end
	local bossState = ReplicatedStorage:FindFirstChild(Boss.StateFolderName)
	local beaten = bossState ~= nil and bossState:GetAttribute("State") == "Defeated"
	local line = if beaten then cfg.ThanksLine else cfg.NotDoneLine

	talkId += 1
	local myId = talkId
	talkingTo = at
	farSince = nil
	lineLabel.Text = line
	lineLabel.MaxVisibleGraphemes = 0
	gui.Enabled = true
	UiKit.bounce(holder)

	-- Type it out, one letter at a time.
	local letters = utf8.len(line) or #line
	task.spawn(function()
		for count = 1, letters do
			if talkId ~= myId then
				return
			end
			lineLabel.MaxVisibleGraphemes = count
			task.wait(cfg.TypeSpeed)
		end
		if talkId == myId then
			lineLabel.MaxVisibleGraphemes = -1
		end
	end)
end

local function hookPrompt(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	instance.Triggered:Connect(function()
		local parent = instance.Parent
		if parent and parent:IsA("BasePart") then
			talk(parent)
		end
	end)
end

-- Hide the box once you've been out of range for a moment.
local function checkDistance(now: number)
	local at = talkingTo
	if not gui.Enabled or not at then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return
	end
	if (root.Position - at.Position).Magnitude <= Config.Landowner.HideDistance then
		farSince = nil
		return
	end
	local since = farSince or now
	farSince = since
	if now - since >= Config.Landowner.HideDelay then
		hide()
	end
end

local function onNpcAdded(instance: Instance)
	addNpc(instance)
	-- The bird hops on the grass in front of him, a little to one side.
	if instance:IsA("Model") and #birds == 0 then
		local spot = (instance:GetPivot() * CFrame.new(-3, 0, -4)).Position
		addBird(Vector3.new(spot.X, groundAt(spot), spot.Z))
	end
end

function LandownerController.init()
	buildGui()
end

function LandownerController.start()
	for _, model in CollectionService:GetTagged(Tags.Landowner) do
		onNpcAdded(model)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Landowner):Connect(onNpcAdded)
	CollectionService:GetInstanceRemovedSignal(Tags.Landowner):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			npcs[instance] = nil -- streamed out: it gets added again when it streams back in
		end
	end)

	for _, prompt in CollectionService:GetTagged(Tags.LandownerPrompt) do
		hookPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal(Tags.LandownerPrompt):Connect(hookPrompt)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local camera = workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
		for _, npc in npcs do
			animateNpc(npc, now, cameraPosition)
		end
		for _, bird in birds do
			animateBird(bird, now)
		end
		checkDistance(now)
	end)
end

return LandownerController
