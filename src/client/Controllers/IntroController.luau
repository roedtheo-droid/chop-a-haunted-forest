--!strict
-- The intro when you join, in the Chop a Forest style (see STYLE_GUIDE.md):
--   1. The screen fades in from black and the camera flies over the forest in a few shots,
--      from the sunny camp to the dark graveyard. A Skip button jumps past it.
--   2. The title and a big PLAY button pop up while the camera circles slowly over the camp.
--   3. PLAY swoops the camera down behind your character and gives you back the controls and the HUD.
-- It only plays once, when you join (not when you respawn).
--
-- It's only for looks on YOUR screen, so the server doesn't take part.
-- The texts, timings and camera shots are in Config.Intro.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local UiKit = require(script.Parent.Parent.UiKit)
local AtmosphereController = require(script.Parent.AtmosphereController)

local Style = Config.Style
local cfg = Config.Intro
local shots: { Types.IntroShot } = cfg.Shots
local RENDER_NAME = "IntroCamera"
-- Roblox's own menus, hidden during the intro so only the forest and the title show.
local CORE_GUIS = {
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.EmotesMenu,
	Enum.CoreGuiType.Health,
}

type CameraMode = "Shot" | "Orbit" | "Swoop"

local IntroController = {}

local player = Players.LocalPlayer

-- What the camera is doing right now (updateCamera moves it every frame).
local mode: CameraMode = "Shot"
local shot: Types.IntroShot = shots[1]
local modeStart = 0 -- os.clock() when the current shot, orbit or swoop began
local swoopFrom = CFrame.identity -- where the camera was when PLAY was pressed
local skipped = false
local finished = false -- true once the intro is over (or switched off)
local finishedCallbacks: { () -> () } = {}

local introGui: ScreenGui
local blackout: Frame -- the black screen we fade in from and dip to between shots
local topBar: Frame -- black "cinema" bars at the top and bottom during the flyover
local bottomBar: Frame
local titleGroup: Frame -- the title, the subtitle and the PLAY button
local titleScale: UIScale
local playButton: TextButton
local playScale: UIScale
local skipButton: TextButton

-- Everything we hid, so we can show exactly that again at the end.
local hiddenGuis: { ScreenGui } = {}
local hiddenCore: { Enum.CoreGuiType } = {}
local guiAddedConnection: RBXScriptConnection? = nil
local controls: any = nil -- Roblox's movement controls (see getControls)

-- 0 to 1, starting and ending gently instead of with a jerk.
local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- Plays a tween, and also sets the end values when it should be done. TweenService stops
-- while Studio's window is hidden, so this way nothing stays stuck halfway.
local function tween(object: Instance, seconds: number, goals: { [string]: any }, info: TweenInfo?)
	TweenService:Create(object, info or TweenInfo.new(seconds, Enum.EasingStyle.Quad), goals):Play()
	task.delay(seconds, function()
		for property, value in goals do
			(object :: any)[property] = value
		end
	end)
end

-- Fade the black screen to `transparency` (0 = black, 1 = see-through) and wait until it's done.
local function fade(transparency: number, seconds: number)
	blackout.Visible = true
	TweenService:Create(blackout, TweenInfo.new(seconds), { BackgroundTransparency = transparency }):Play()
	task.wait(seconds)
	blackout.BackgroundTransparency = transparency
	blackout.Visible = transparency < 1 -- a see-through frame on top could still catch clicks
end

-- Wait, but stop early if Skip was pressed.
local function waitOrSkip(seconds: number)
	local finish = os.clock() + seconds
	while not skipped and os.clock() < finish do
		task.wait()
	end
end

local function getRoot(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function waitForRoot(): BasePart
	while true do
		local root = getRoot()
		if root then
			return root
		end
		task.wait(0.1)
	end
end

-- Roblox's movement controls live in its PlayerModule script. Turning them off stops you
-- walking away while the camera is busy.
local function getControls(): any
	local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
	if not playerModule then
		return nil
	end
	-- PlayerModule is Roblox's own script, so the type checker can't see inside it (hence `any`).
	local ok, module = pcall(require :: any, playerModule)
	return if ok and module then module:GetControls() else nil
end

local function updateCamera()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- Roblox's camera script would move the camera itself unless it's Scriptable.
	camera.CameraType = Enum.CameraType.Scriptable
	local elapsed = os.clock() - modeStart

	if mode == "Shot" then
		-- Glide steadily from From to To, while the view turns gently from LookFrom to LookTo.
		local t = math.clamp(elapsed / shot.Time, 0, 1)
		camera.CFrame = CFrame.lookAt(shot.From:Lerp(shot.To, t), shot.LookFrom:Lerp(shot.LookTo, smooth(t)))
	elseif mode == "Orbit" then
		local angle = elapsed * cfg.OrbitSpeed
		local offset = Vector3.new(math.sin(angle) * cfg.OrbitRadius, cfg.OrbitHeight, math.cos(angle) * cfg.OrbitRadius)
		camera.CFrame = CFrame.lookAt(cfg.OrbitCenter + offset, cfg.OrbitCenter)
	else
		-- Swoop: from wherever the orbit was to just behind your character.
		local root = getRoot()
		if root then
			local t = smooth(math.clamp(elapsed / cfg.SwoopTime, 0, 1))
			local behind = (root.CFrame * CFrame.new(cfg.SwoopOffset)).Position
			local goal = CFrame.lookAt(behind, root.Position + Vector3.new(0, 2, 0))
			camera.CFrame = swoopFrom:Lerp(goal, t)
		end
	end
end

local function makeBar(name: string, anchorY: number): Frame
	local bar = Instance.new("Frame")
	bar.Name = name
	bar.AnchorPoint = Vector2.new(0, anchorY)
	bar.Position = UDim2.fromScale(0, anchorY)
	bar.Size = UDim2.fromScale(1, cfg.BarSize)
	bar.BackgroundColor3 = Color3.new(0, 0, 0)
	bar.BorderSizePixel = 0
	bar.Parent = introGui
	return bar
end

local function buildGui()
	introGui = Instance.new("ScreenGui")
	introGui.Name = "Intro"
	introGui.ResetOnSpawn = false
	introGui.IgnoreGuiInset = true -- cover the whole screen, also behind Roblox's top bar
	introGui.DisplayOrder = 20 -- on top of every other screen

	topBar = makeBar("TopBar", 0)
	bottomBar = makeBar("BottomBar", 1)

	-- The title block uses a share of the screen, but never gets too big on a PC.
	titleGroup = Instance.new("Frame")
	titleGroup.Name = "Title"
	titleGroup.AnchorPoint = Vector2.new(0.5, 0.5)
	titleGroup.Position = UDim2.fromScale(0.5, 0.45)
	titleGroup.Size = UDim2.fromScale(0.9, 0.6)
	titleGroup.BackgroundTransparency = 1
	titleGroup.Visible = false
	titleGroup.Parent = introGui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(700, 380)
	sizeLimit.Parent = titleGroup
	titleScale = Instance.new("UIScale")
	titleScale.Parent = titleGroup

	local title = UiKit.text(titleGroup, "Name", cfg.Title, Style.Gold, Style.TitleFont)
	title.TextWrapped = true
	title.Size = UDim2.fromScale(1, 0.5)
	title.Rotation = -3 -- a little crooked, for the cartoony look
	local titleStroke = title:FindFirstChildOfClass("UIStroke")
	if titleStroke then
		titleStroke.Thickness = Style.TextStroke * 2 -- big letters need a thicker outline
	end

	local subtitle = UiKit.smallText(titleGroup, "Subtitle", cfg.Subtitle)
	subtitle.Position = UDim2.fromScale(0.05, 0.52)
	subtitle.Size = UDim2.fromScale(0.9, 0.1)

	-- PLAY sits in its own frame, so it can pulse gently without fighting the button's own squish.
	local playHolder = Instance.new("Frame")
	playHolder.Name = "PlayHolder"
	playHolder.AnchorPoint = Vector2.new(0.5, 0)
	playHolder.Position = UDim2.fromScale(0.5, 0.7)
	playHolder.Size = UDim2.fromScale(0.42, 0.24)
	playHolder.BackgroundTransparency = 1
	playHolder.Parent = titleGroup
	playScale = Instance.new("UIScale")
	playScale.Parent = playHolder
	local button = UiKit.button(playHolder, "Play", "PLAY", Style.Green)
	button.Size = UDim2.fromScale(1, 1)
	playButton = button

	local skip = UiKit.button(introGui, "Skip", "Skip", Style.Grey)
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1, -16, 1 - cfg.BarSize, -12) -- just above the bottom bar
	skip.Size = UDim2.fromOffset(110, 40)
	skip.Activated:Connect(function()
		skipped = true
	end)
	skipButton = skip

	-- Last, so it covers everything else.
	blackout = Instance.new("Frame")
	blackout.Name = "Blackout"
	blackout.Size = UDim2.fromScale(1, 1)
	blackout.BackgroundColor3 = Color3.new(0, 0, 0)
	blackout.BorderSizePixel = 0
	blackout.Parent = introGui

	introGui.Parent = player:WaitForChild("PlayerGui")
end

local function hideGui(instance: Instance)
	if instance:IsA("ScreenGui") and instance ~= introGui and instance.Enabled then
		instance.Enabled = false
		table.insert(hiddenGuis, instance)
	end
end

-- Hide the HUD, Roblox's menus and the controls while the intro plays.
local function hideEverythingElse()
	local playerGui = player:WaitForChild("PlayerGui")
	for _, child in playerGui:GetChildren() do
		hideGui(child)
	end
	-- Screens that show up during the intro (like the phone thumbstick) wait too.
	guiAddedConnection = playerGui.ChildAdded:Connect(hideGui)

	for _, coreGui in CORE_GUIS do
		if StarterGui:GetCoreGuiEnabled(coreGui) then
			StarterGui:SetCoreGuiEnabled(coreGui, false)
			table.insert(hiddenCore, coreGui)
		end
	end

	controls = getControls()
	if controls then
		controls:Disable()
	end
end

local function showEverythingElse()
	if guiAddedConnection then
		guiAddedConnection:Disconnect()
		guiAddedConnection = nil
	end
	for _, gui in hiddenGuis do
		gui.Enabled = true
	end
	for _, coreGui in hiddenCore do
		StarterGui:SetCoreGuiEnabled(coreGui, true)
	end
	if controls then
		controls:Enable()
	end
end

-- With StreamingEnabled, your computer only gets the parts of the map near your character.
-- Ask the server for the places the camera will fly over, so the shots aren't empty.
local function preloadShots()
	for _, nextShot in shots do
		pcall(function()
			player:RequestStreamAroundAsync(nextShot.LookTo, 5)
		end)
	end
end

local function playFlyover()
	local cutHalf = cfg.CutTime / 2
	for index, nextShot in shots do
		if skipped then
			break
		end
		shot = nextShot
		mode = "Shot"
		modeStart = os.clock()
		-- Each zone the camera flies over gets its own light and fog (at once, while it's black).
		AtmosphereController.setViewPoint(nextShot.LookTo, 0)
		local fadeIn = if index == 1 then cfg.FadeTime else cutHalf
		fade(1, fadeIn)
		waitOrSkip(nextShot.Time - fadeIn - cutHalf)
		fade(0, cutHalf)
	end
end

local function showTitle()
	mode = "Orbit"
	modeStart = os.clock()
	AtmosphereController.setViewPoint(cfg.OrbitCenter, 0)
	skipButton.Visible = false
	topBar.Visible = false
	bottomBar.Visible = false
	fade(1, cfg.CutTime)

	-- Pop in: start small and grow to full size with a little overshoot.
	titleGroup.Visible = true
	titleScale.Scale = 0.3
	tween(titleScale, 0.5, { Scale = 1 }, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out))

	-- PLAY breathes in and out a little, so you know where to press.
	task.spawn(function()
		while titleGroup.Parent and titleGroup.Visible do
			tween(playScale, 0.6, { Scale = 1.06 }, TweenInfo.new(0.6, Enum.EasingStyle.Sine))
			task.wait(0.6)
			tween(playScale, 0.6, { Scale = 1 }, TweenInfo.new(0.6, Enum.EasingStyle.Sine))
			task.wait(0.6)
		end
	end)
end

local function swoopToCharacter()
	tween(titleScale, 0.25, { Scale = 0 }, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In))
	task.delay(0.25, function()
		titleGroup.Visible = false
	end)

	waitForRoot()
	local camera = workspace.CurrentCamera
	swoopFrom = if camera then camera.CFrame else CFrame.identity
	mode = "Swoop"
	modeStart = os.clock()
	AtmosphereController.setViewPoint(nil)
	task.wait(cfg.SwoopTime)
end

-- The intro is over: tell everyone who asked (see IntroController.onFinished).
local function markFinished()
	finished = true
	for _, callback in finishedCallbacks do
		task.spawn(callback)
	end
	table.clear(finishedCallbacks)
end

-- Hand the camera back to Roblox (following your character) and remove the intro.
local function finish()
	RunService:UnbindFromRenderStep(RENDER_NAME)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	AtmosphereController.setViewPoint(nil)
	showEverythingElse()
	introGui:Destroy()
	markFinished()
end

-- Run `callback` once the intro is over and you have control (right away if it already is).
-- The first-person camera waits for this (see ViewmodelController), so the intro camera can
-- fly freely and you can click PLAY with the mouse.
function IntroController.onFinished(callback: () -> ())
	if finished then
		task.spawn(callback)
	else
		table.insert(finishedCallbacks, callback)
	end
end

function IntroController.init() end

function IntroController.start()
	if not cfg.Enabled then
		markFinished()
		return
	end
	buildGui()
	hideEverythingElse()
	task.spawn(preloadShots)
	-- Just after Roblox's own camera, so ours wins every frame.
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, updateCamera)

	playFlyover()
	showTitle()
	playButton.Activated:Wait()
	swoopToCharacter()
	finish()
end

return IntroController
