--!strict
-- First person, like in Chop a Forest (see STYLE_GUIDE.md and Config.FirstPerson):
--   * the camera is locked in your head, and Roblox hides your own body
--   * two big blocky forearms and fists sit at the bottom of the screen. Each swing jabs one
--     fist forward and back, taking turns: left, right, left...
--   * when you hold a tool, a copy of it sits in your right hand instead, and chops down
--   * a small hollow circle in the middle of the screen shows what you'll hit
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

type Side = "Left" | "Right"
local SIDES: { Side } = { "Left", "Right" }
type Arm = {
	Forearm: Part,
	Fist: Part,
	Side: Side,
}

local ViewmodelController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local active = false -- true once first person is on (after the intro)
local viewmodel: Model -- holds the arms and the tool copy, inside the camera
local arms: { [Side]: Arm } = {}
local crosshair: Frame

-- The swing that's playing right now.
local swingSide: Side = "Right" -- the fist that jabbed last (the next jab uses the other one)
local swingStarted = -math.huge
local swingScale = 1 -- below 1 when the tool swings faster than a full jab (the Chainsaw)
local swingSize = 1 -- how big the movement is (Config.ChopFeel SwingSize)

-- The tool in your hand: the real one (hidden on your screen) and our copy of it.
local heldTool: Tool? = nil
local toolCopy: { { Part: BasePart, Offset: CFrame } } = {} -- each copied part, placed from the handle
local handleLength = 0 -- the copied handle's length (handles are long along Z)

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

local function plainPart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
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
	for _, arm in arms do
		arm.Forearm.Color = color
		arm.Fist.Color = color:Lerp(Color3.new(1, 1, 1), 0.06) -- a hair lighter, so the fist reads as its own block
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

-- How far into the swing we are: 0 at rest, 1 at full stretch. Quick out, a bit slower back.
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

-- Where a fist rests on the screen (the left one is the right one mirrored).
local function restFrame(camera: Camera, side: Side): CFrame
	local mirror = if side == "Left" then -1 else 1
	local offset = cfg.RestOffset
	return camera.CFrame
		* CFrame.new(offset.X * mirror, offset.Y, offset.Z)
		* CFrame.Angles(math.rad(cfg.RestPitch), math.rad(cfg.RestYaw) * mirror, 0)
end

-- Put the forearm behind the fist. `fist` is the middle of the fist, facing forward (-Z).
local function placeArm(arm: Arm, fist: CFrame)
	arm.Fist.CFrame = fist
	local length = cfg.ForearmSize.Z
	arm.Forearm.CFrame = fist * CFrame.new(0, 0, cfg.FistSize.Z / 2 + length / 2 - 0.15)
end

local function update()
	local camera = workspace.CurrentCamera
	if not (active and camera) then
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

	local amount = swingAmount(os.clock()) * swingSize
	for side, arm in arms do
		local fist = restFrame(camera, side)
		if heldTool then
			-- Holding a tool: the right hand chops it down, the left fist waits.
			if side == "Right" then
				-- Turn around the elbow (the back of the forearm), forwards and down.
				local elbow = fist * CFrame.new(0, 0, cfg.ForearmSize.Z)
				local chop = CFrame.Angles(-math.rad(cfg.ToolSwingAngle) * amount, 0, 0)
				fist = elbow * chop * elbow:ToObjectSpace(fist)
			end
		elseif side == swingSide then
			-- A jab: straight forward, a little in towards the middle and up.
			local mirror = if side == "Left" then 1 else -1
			fist *= CFrame.new(0.25 * mirror * amount, 0.15 * amount, -cfg.PunchReach * amount)
		end
		placeArm(arm, fist)
	end

	-- The tool sits in the right fist, pointing up and forward, its head at the far end.
	if heldTool then
		local grip = arms.Right.Fist.CFrame
			* CFrame.Angles(math.rad(cfg.ToolPitch), 0, 0)
			* CFrame.new(0, 0, -handleLength * (0.5 - cfg.ToolGrip))
		for _, copy in toolCopy do
			copy.Part.CFrame = grip * copy.Offset
		end
	end

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

-- Play one swing: a jab with the next fist, or a chop with the tool in your hand.
-- `cooldown` is the tool's time between swings: a swing that would take longer is sped up to fit.
-- `size` makes the movement smaller (the Chainsaw's short, fast sawing).
function ViewmodelController.swing(cooldown: number, size: number)
	if not active then
		return
	end
	if not heldTool then
		swingSide = if swingSide == "Left" then "Right" else "Left"
	end
	local full = cfg.PunchOut + cfg.PunchBack
	swingScale = math.min(1, cooldown * 0.95 / full)
	swingSize = size
	swingStarted = os.clock()
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
	gui.Parent = player:WaitForChild("PlayerGui")
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
			Forearm = plainPart(`{side}Forearm`, cfg.ForearmSize, cfg.SkinColor),
			Fist = plainPart(`{side}Fist`, cfg.FistSize, cfg.SkinColor),
			Side = side,
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
