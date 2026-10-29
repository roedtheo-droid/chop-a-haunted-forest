--!strict
-- First person, like in Chop a Forest (see STYLE_GUIDE.md and Config.FirstPerson):
--   * the camera is locked in your head, and Roblox hides your own body
--   * two big blocky forearms and fists with rounded corners sit at the bottom of the screen.
--     Each swing punches with one fist, taking turns: left, right, left...
--   * when you hold a tool, a copy of it sits in your right hand instead, and chops down
--   * a small hollow circle in the middle of the screen shows what you'll hit
-- A punch moves like a real one: the fist pulls back a little (wind-up), then jabs forward
-- faster and faster and turns as it goes. On a hit it stops right at the bark, freezes for a
-- split second and bounces back off it; on a miss it carries on a bit. Then it springs back to
-- rest with a small bounce, and the other fist pulls back a little while it punches.
-- The arms are parts inside the camera. Parts in the camera only exist on your own computer, so
-- nobody else sees them (they see your character's normal swing, see ChopController).
-- Only for looks: ChopController still decides when you can swing, and the server decides the hits.
-- With Config.FirstPerson.FirstPersonOnly = false, none of this happens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local UiKit = require(script.Parent.Parent.UiKit)
local IntroController = require(script.Parent.IntroController)

local cfg = Config.FirstPerson
local RENDER_NAME = "FirstPersonArms"
local MAX_STEP = 1 / 30 -- the springs never take a bigger step than this, so a slow frame can't fling them

type Side = "Left" | "Right"
local SIDES: { Side } = { "Left", "Right" }

-- A block with rounded corners, made of parts: three boxes crossing each other, a cylinder
-- along each edge and a ball in each corner. Offsets place each part from the block's middle.
type Block = {
	Parts: { BasePart },
	Offsets: { CFrame },
}

type Arm = {
	Forearm: Block,
	Fist: Block,
	Side: Side,
	-- The punch: X is how far the fist is forward (studs, below 0 while it winds up), V its speed.
	Started: number, -- os.clock() when its last punch started
	Reach: number, -- how far this punch goes (to the bark, or its full reach)
	Hit: boolean, -- does this punch hit a tree? (then it stops and bounces off the bark)
	Springing: boolean, -- true once it has landed and is springing back
	X: number,
	V: number,
}

local ViewmodelController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local random = Random.new()
local active = false -- true once first person is on (after the intro)
local viewmodel: Model -- holds the arms and the tool copy, inside the camera
local arms: { [Side]: Arm } = {}
local crosshair: Frame

local punchSide: Side = "Right" -- the fist that punched last (the next punch uses the other one)
local punchScale = 1 -- below 1 if the punch has to be quicker to fit the tool's cooldown

-- A tool swing (fists use the punches above instead).
local swingStarted = -math.huge
local swingScale = 1 -- below 1 when the tool swings faster than a full swing (the Chainsaw)
local swingSize = 1 -- how big the movement is (Config.ChopFeel SwingSize)

-- The tool in your hand: the real one (hidden on your screen) and our copy of it.
local heldTool: Tool? = nil
local toolCopy: { { Part: BasePart, Offset: CFrame } } = {} -- each copied part, placed from the handle
local handleLength = 0 -- the copied handle's length (handles are long along Z)

-- Every arm part and where it goes this frame, moved all at once with BulkMoveTo (much faster
-- than setting 90-odd CFrames one by one).
local movingParts: { BasePart } = {}
local movingFrames: { CFrame } = {}

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Is a menu open that frees the mouse (the Tool Shed, Forest Cleared; see UiKit.freeMouse)?
local function menuOpen(): boolean
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled and gui:GetAttribute(UiKit.FREES_MOUSE) then
			return true
		end
	end
	return false
end

-- Is a screen open that takes over the camera (the Garage; see UiKit.HIDES_ARMS)?
local function cameraTaken(): boolean
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled and gui:GetAttribute(UiKit.HIDES_ARMS) then
			return true
		end
	end
	return false
end

local function plainPart(name: string, size: Vector3, shape: Enum.PartType): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = cfg.SkinColor
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false -- clicks go straight through to the tree
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = viewmodel
	return part
end

-- Build a block of `size` with rounded corners (see the Block type above).
local function roundedBlock(name: string, size: Vector3): Block
	local radius = math.min(size.X, size.Y, size.Z) * cfg.Roundness
	local diameter = radius * 2
	local half = size / 2 - Vector3.one * radius -- where the middles of the round edges are
	local block: Block = { Parts = {}, Offsets = {} }
	local function add(partSize: Vector3, shape: Enum.PartType, offset: CFrame)
		table.insert(block.Parts, plainPart(name, partSize, shape))
		table.insert(block.Offsets, offset)
	end

	-- Three boxes, each one full size in one direction and shorter in the other two.
	add(Vector3.new(size.X, size.Y - diameter, size.Z - diameter), Enum.PartType.Block, CFrame.identity)
	add(Vector3.new(size.X - diameter, size.Y, size.Z - diameter), Enum.PartType.Block, CFrame.identity)
	add(Vector3.new(size.X - diameter, size.Y - diameter, size.Z), Enum.PartType.Block, CFrame.identity)
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			-- Round edges: a cylinder lies along its X axis, so the Y and Z ones are turned.
			add(Vector3.new(size.X - diameter, diameter, diameter), Enum.PartType.Cylinder, CFrame.new(0, a * half.Y, b * half.Z))
			add(
				Vector3.new(size.Y - diameter, diameter, diameter),
				Enum.PartType.Cylinder,
				CFrame.new(a * half.X, 0, b * half.Z) * CFrame.Angles(0, 0, math.pi / 2)
			)
			add(
				Vector3.new(size.Z - diameter, diameter, diameter),
				Enum.PartType.Cylinder,
				CFrame.new(a * half.X, b * half.Y, 0) * CFrame.Angles(0, math.pi / 2, 0)
			)
			-- Round corners.
			for _, c in { -1, 1 } do
				add(Vector3.one * diameter, Enum.PartType.Ball, CFrame.new(a * half.X, b * half.Y, c * half.Z))
			end
		end
	end
	return block
end

-- Queue a block to be moved to `cframe` this frame.
local function placeBlock(block: Block, cframe: CFrame)
	for index, part in block.Parts do
		table.insert(movingParts, part)
		table.insert(movingFrames, cframe * block.Offsets[index])
	end
end

-- Your character's skin colour, so the fists match your avatar.
local function skinColor(): Color3
	local character = player.Character
	if character then
		local bodyColors = character:FindFirstChildOfClass("BodyColors")
		if bodyColors then
			return bodyColors.RightArmColor3
		end
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		if hand and hand:IsA("BasePart") then
			return hand.Color
		end
	end
	return cfg.SkinColor
end

local function paintArms()
	local color = skinColor()
	local fistColor = color:Lerp(Color3.new(1, 1, 1), 0.06) -- a hair lighter, so the fist reads as its own block
	for _, arm in arms do
		for _, part in arm.Forearm.Parts do
			part.Color = color
		end
		for _, part in arm.Fist.Parts do
			part.Color = fistColor
		end
	end
end

---------------------------------------------------------------------------
-- The tool in your right hand
---------------------------------------------------------------------------

-- Show the real tool again (it's hidden on your screen while it's in your hand).
local function releaseTool()
	local tool = heldTool
	if tool then
		for _, descendant in tool:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = 0
			elseif descendant:IsA("Fire") then
				descendant.Enabled = true
			end
		end
	end
	for _, copy in toolCopy do
		copy.Part:Destroy()
	end
	table.clear(toolCopy)
	heldTool = nil
end

-- Copy the tool's parts (handle, head, its flame) into the viewmodel.
-- Lights aren't copied: the real tool still lights up the ground around you.
local function takeTool(tool: Tool)
	releaseTool()
	local handle = tool:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		return
	end
	heldTool = tool
	handleLength = handle.Size.Z
	for _, part in tool:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local copy = part:Clone()
		for _, child in copy:GetDescendants() do
			if child:IsA("JointInstance") or child:IsA("WeldConstraint") or child:IsA("Light") then
				child:Destroy()
			end
		end
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CastShadow = false
		copy.Massless = true
		copy.Parent = viewmodel
		table.insert(toolCopy, { Part = copy, Offset = handle.CFrame:ToObjectSpace(part.CFrame) })
	end
end

-- The tool we should be holding right now (nil = fists).
local function currentTool(): Tool?
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	if tool and typeof(tool:GetAttribute("ToolId")) == "string" then
		return tool
	end
	return nil
end

-- Keep the real tool invisible on your screen (and its flame off), so only our copy shows.
local function hideRealTool(tool: Tool)
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
		elseif descendant:IsA("Fire") then
			descendant.Enabled = false
		end
	end
end

---------------------------------------------------------------------------
-- Moving the arms every frame
---------------------------------------------------------------------------

-- How far into a tool swing we are: 0 at rest, 1 at full stretch. Quick out, a bit slower back.
local function swingAmount(now: number): number
	local out = cfg.PunchOut * swingScale
	local back = cfg.PunchBack * swingScale
	local t = now - swingStarted
	if t < 0 or t >= out + back then
		return 0
	elseif t < out then
		local u = t / out
		return 1 - (1 - u) * (1 - u) -- fast at first, slowing down as it lands
	end
	local u = (t - out) / back
	return 1 - u * u * (3 - 2 * u) -- smooth on the way back
end

-- Move one fist's punch on by `dt` seconds. Sets arm.X (how far forward) and arm.V.
local function updatePunch(arm: Arm, now: number, dt: number)
	local out = cfg.PunchOut * punchScale
	local windUpTime = out * cfg.WindUpShare
	local t = now - arm.Started
	if t < windUpTime then
		-- Wind-up: pull back, slowing down as it gets there.
		arm.X = -cfg.WindUp * math.sin(t / windUpTime * math.pi / 2)
		return
	elseif t < out then
		-- The jab: faster and faster until it lands.
		local u = (t - windUpTime) / (out - windUpTime)
		arm.X = -cfg.WindUp + (arm.Reach + cfg.WindUp) * u * u
		return
	elseif arm.Hit and t < out + cfg.HitStop * punchScale then
		-- It hit the bark: hold still for a split second (with a tiny shiver).
		arm.X = arm.Reach
		return
	end

	if not arm.Springing then
		-- It just landed: bounce back off the bark, or carry on a little through thin air.
		arm.Springing = true
		arm.X = arm.Reach
		arm.V = if arm.Hit then -cfg.RecoilSpeed else cfg.AirFollow
	end
	-- Spring back to rest. The stiffness is picked so it's (almost) back after PunchBack seconds.
	local damping = cfg.ReturnBounce
	local stiffness = 3 / (damping * cfg.PunchBack * punchScale)
	local left = dt
	while left > 0 do
		local step = math.min(left, MAX_STEP)
		local accel = -stiffness * stiffness * arm.X - 2 * damping * stiffness * arm.V
		arm.V += accel * step
		arm.X += arm.V * step
		left -= step
	end
end

-- Where a fist rests on the screen (the left one is the right one mirrored).
local function restFrame(camera: Camera, side: Side): CFrame
	local mirror = if side == "Left" then -1 else 1
	local offset = cfg.RestOffset
	return camera.CFrame
		* CFrame.new(offset.X * mirror, offset.Y, offset.Z)
		* CFrame.Angles(math.rad(cfg.RestPitch), math.rad(cfg.RestYaw) * mirror, 0)
end

-- Where a punching fist is, from where it rests and how far into the punch it is.
local function punchFrame(arm: Arm, rest: CFrame, otherForward: number): CFrame
	local inward = if arm.Side == "Left" then 1 else -1 -- the way towards the middle of the screen
	local forward = arm.X
	local stretch = math.clamp(forward / math.max(arm.Reach, 0.01), 0, 1)
	local cocked = math.clamp(-forward / cfg.WindUp, 0, 1) -- 1 at the end of the wind-up
	-- The other fist pulls back a little while this one punches.
	local pull = math.max(otherForward, 0) * cfg.CounterPull
	local shiver = Vector3.zero
	if arm.Hit and not arm.Springing and forward >= arm.Reach then
		shiver = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), 0) * cfg.HitShake
	end
	return rest
		* CFrame.new(Vector3.new(0.22 * inward * stretch, 0.12 * stretch - 0.05 * pull, -forward + pull) + shiver)
		* CFrame.Angles(math.rad(12) * cocked - math.rad(4) * stretch, 0, math.rad(cfg.PunchTwist) * inward * stretch)
end

-- Put the forearm behind the fist. `fist` is the middle of the fist, facing forward (-Z).
local function placeArm(arm: Arm, fist: CFrame)
	placeBlock(arm.Fist, fist)
	local length = cfg.ForearmSize.Z
	placeBlock(arm.Forearm, fist * CFrame.new(0, 0, cfg.FistSize.Z / 2 + length / 2 - 0.15))
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	if not (active and camera) then
		return
	end
	if cameraTaken() then
		-- The camera is looking at something else: no arms, no crosshair, and a free mouse.
		viewmodel.Parent = nil
		crosshair.Visible = false
		UserInputService.MouseIconEnabled = not isTouch()
		return
	end
	viewmodel.Parent = camera

	-- Swap between fists and a tool when you equip or put away a tool.
	local tool = currentTool()
	if tool ~= heldTool then
		if tool then
			takeTool(tool)
		else
			releaseTool()
		end
	end
	if tool then
		hideRealTool(tool)
	end

	local now = os.clock()
	table.clear(movingParts)
	table.clear(movingFrames)
	if heldTool then
		-- Holding a tool: the right hand chops it down (around the elbow), the left fist waits.
		local amount = swingAmount(now) * swingSize
		local rest = restFrame(camera, "Right")
		local elbow = rest * CFrame.new(0, 0, cfg.ForearmSize.Z)
		local chop = CFrame.Angles(-math.rad(cfg.ToolSwingAngle) * amount, 0, 0)
		local rightFist = elbow * chop * elbow:ToObjectSpace(rest)
		placeArm(arms.Right, rightFist)
		placeArm(arms.Left, restFrame(camera, "Left"))
		-- The tool sits in the right fist, pointing up and forward, its head at the far end.
		local grip = rightFist
			* CFrame.Angles(math.rad(cfg.ToolPitch), 0, 0)
			* CFrame.new(0, 0, -handleLength * (0.5 - cfg.ToolGrip))
		for _, copy in toolCopy do
			copy.Part.CFrame = grip * copy.Offset
		end
	else
		for _, arm in arms do
			updatePunch(arm, now, dt)
		end
		for side, arm in arms do
			local other = arms[if side == "Left" then "Right" else "Left"]
			placeArm(arm, punchFrame(arm, restFrame(camera, side), other.X))
		end
	end
	workspace:BulkMoveTo(movingParts, movingFrames, Enum.BulkMoveMode.FireCFrameChanged)

	-- The crosshair shows while you aim; while a menu is open you get the mouse instead.
	local aiming = not menuOpen()
	crosshair.Visible = aiming
	UserInputService.MouseIconEnabled = not aiming and not isTouch()
end

---------------------------------------------------------------------------

-- Is first person on (switched on in Config, and the intro is over)?
function ViewmodelController.isActive(): boolean
	return active
end

-- Play one swing: a punch with the next fist, or a chop with the tool in your hand.
-- `cooldown` is the tool's time between swings: a swing that would take longer is sped up to fit.
-- `size` makes a tool's movement smaller (the Chainsaw's short, fast sawing).
-- `distance` is how far away the bark you're aiming at is (nil if you aren't aiming at a tree),
-- so the fist can stop right on it, and `hit` says whether the hit will count.
function ViewmodelController.swing(cooldown: number, size: number, distance: number?, hit: boolean)
	if not active then
		return
	end
	if heldTool then
		swingScale = math.min(1, cooldown * 0.95 / (cfg.PunchOut + cfg.PunchBack))
		swingSize = size
		swingStarted = os.clock()
		return
	end

	punchSide = if punchSide == "Left" then "Right" else "Left"
	punchScale = math.min(1, cooldown * 0.95 / (cfg.PunchOut + cfg.HitStop + cfg.PunchBack))
	local arm = arms[punchSide]
	-- Reach just far enough to touch the bark (the fist rests about -RestOffset.Z in front of you).
	local reach = cfg.PunchReachMax
	if distance then
		reach = math.clamp(distance + cfg.RestOffset.Z - cfg.FistSize.Z / 2, cfg.PunchReachMin, cfg.PunchReachMax)
	end
	arm.Started = os.clock()
	arm.Reach = reach
	arm.Hit = hit
	arm.Springing = false
	arm.V = 0
end

local function buildCrosshair()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Crosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the exact middle of the whole screen
	gui.DisplayOrder = -1 -- under every other screen

	local size = cfg.CrosshairSize
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(size, size)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = cfg.CrosshairColor
	stroke.Thickness = cfg.CrosshairThickness
	stroke.Transparency = 0.1
	stroke.Parent = ring
	-- A thin dark ring just outside it, so it shows on a bright sky too.
	local outline = Instance.new("Frame")
	outline.Name = "Outline"
	outline.AnchorPoint = Vector2.new(0.5, 0.5)
	outline.Position = UDim2.fromScale(0.5, 0.5)
	outline.Size = UDim2.new(1, cfg.CrosshairThickness * 2 + 1, 1, cfg.CrosshairThickness * 2 + 1)
	outline.BackgroundTransparency = 1
	local outlineCorner = Instance.new("UICorner")
	outlineCorner.CornerRadius = UDim.new(0.5, 0)
	outlineCorner.Parent = outline
	local outlineStroke = Instance.new("UIStroke")
	outlineStroke.Color = Color3.new(0, 0, 0)
	outlineStroke.Thickness = 1
	outlineStroke.Transparency = 0.5
	outlineStroke.Parent = outline
	outline.Parent = ring

	ring.Parent = gui
	gui.Parent = playerGui
	crosshair = ring
end

-- Lock the camera in your head and show the arms.
local function turnOn()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	paintArms()
	active = true
end

function ViewmodelController.init()
	if not cfg.FirstPersonOnly then
		return
	end
	viewmodel = Instance.new("Model")
	viewmodel.Name = "FirstPersonArms"
	for _, side in SIDES do
		arms[side] = {
			Forearm = roundedBlock(`{side}Forearm`, cfg.ForearmSize),
			Fist = roundedBlock(`{side}Fist`, cfg.FistSize),
			Side = side,
			Started = -math.huge,
			Reach = cfg.PunchReachMax,
			Hit = false,
			Springing = true,
			X = 0,
			V = 0,
		}
	end
	buildCrosshair()
end

function ViewmodelController.start()
	if not cfg.FirstPersonOnly then
		return
	end
	-- Just after Roblox's camera has moved this frame, so the arms stick to it.
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, update)
	player.CharacterAdded:Connect(function()
		releaseTool()
		task.wait(1) -- give the avatar's colours a moment to load
		paintArms()
	end)
	-- Wait for the intro: its camera flies over the forest, and you click PLAY with the mouse.
	IntroController.onFinished(turnOn)
end

return ViewmodelController
