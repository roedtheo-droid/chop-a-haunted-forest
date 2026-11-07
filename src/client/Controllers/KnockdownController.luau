--!strict
-- What you see when you're down. The server decides all of it (the KnockedDown, DownUntil, DownCause
-- and EscapeProgress attributes, and your speed); this only SHOWS it:
--   * Flattened by the Elder Hollow's slam: your character falls over, the screen turns red and shows
--     how long until you get up.
--   * Swallowed by a mimic: teeth snap shut over your screen, and you mash a key to pry them open. The
--     more you've mashed, the more you can see out between them. Each press only tells the server you
--     pressed; the server counts them.
-- It also hides the "Revive" prompt on your own character (that one is for your friends) and the
-- characters of other players who are inside a mimic.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local UiKit = require(script.Parent.Parent.UiKit)

local TIP_OVER_SPEED = 6 -- how hard your character tips over when you're knocked down
local MASH_ACTION = "MashEscape"

local cfg = Config.Swallow
local Style = Config.Style

local KnockdownController = {}

local player = Players.LocalPlayer
local mashRemote: RemoteEvent

-- The slam's red screen
local gui: ScreenGui
local message: TextLabel
local wasFallen = false

-- The teeth
local jawsGui: ScreenGui
local tint: Frame
local topJaw: Frame
local bottomJaw: Frame
local info: Frame
local mashArea: TextButton
local escapeBar: UiKit.Bar
local hint: TextLabel
local wasSwallowed = false
local swallowedIn: Model? -- the character you were swallowed in
local leaving = false -- they're opening to let you out
local closed = 0 -- 0: off the screen, 1: where they should be
local shownProgress = 0 -- follows EscapeProgress smoothly
local pop = 0 -- 1 just after a press, then fades: the teeth jump open a little

local function isDown(): boolean
	return player:GetAttribute("KnockedDown") == true
end

local function isSwallowed(): boolean
	return isDown() and player:GetAttribute("DownCause") == "Swallowed"
end

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function getHumanoid(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function getRoot(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Fall over (or get back up). Your own computer moves your character,
-- so this is done here; the server already stopped you from walking.
local function setFallen(fallen: boolean)
	local humanoid = getHumanoid()
	if not humanoid then
		return
	end
	humanoid.PlatformStand = fallen
	local root = getRoot()
	if fallen and root then
		root.AssemblyAngularVelocity = root.CFrame.RightVector * TIP_OVER_SPEED
	elseif not fallen then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

-- Tell the server you pressed. It does the counting.
local function mash()
	pop = 1
	mashRemote:FireServer()
end

local function onMashKey(_actionName: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		mash()
	end
	return Enum.ContextActionResult.Sink -- so it doesn't also make you jump
end

-- A little hop as you land, once the server has let go of your character. You're still facing the
-- way the mimic faces, which is away from it. (Not if you got here by respawning.)
local function hop()
	local root = getRoot()
	if not root or player.Character ~= swallowedIn then
		return
	end
	local forward = root.CFrame.LookVector
	task.delay(cfg.HopDelay, function()
		root.AssemblyLinearVelocity = forward * cfg.HopForward + Vector3.yAxis * cfg.HopUp
	end)
end

local function setSwallowed(on: boolean)
	-- E is a key to mash, so it mustn't press a prompt close by as well.
	ProximityPromptService.Enabled = not on
	info.Visible = on
	mashArea.Visible = on
	if on then
		leaving = false
		swallowedIn = player.Character
		shownProgress = 0
		pop = 0
		UiKit.setBar(escapeBar, 0, "")
		jawsGui.Enabled = true
		ContextActionService:BindActionAtPriority(
			MASH_ACTION,
			onMashKey,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.E,
			Enum.KeyCode.Space,
			Enum.KeyCode.ButtonA,
			Enum.KeyCode.ButtonX
		)
	else
		leaving = true
		ContextActionService:UnbindAction(MASH_ACTION)
		hop()
	end
end

local function onKnockedDownChanged()
	local swallowed = isSwallowed()
	local fallen = isDown() and not swallowed
	gui.Enabled = fallen
	if fallen ~= wasFallen then
		wasFallen = fallen
		setFallen(fallen)
	end
	if swallowed ~= wasSwallowed then
		wasSwallowed = swallowed
		setSwallowed(swallowed)
	end
end

local function updateCountdown()
	if not gui.Enabled then
		return
	end
	local secondsLeft = math.max(math.ceil(getNumber("DownUntil") - workspace:GetServerTimeNow()), 0)
	message.Text = `The Elder Hollow flattened you!\nGetting up in {secondsLeft}s. A friend can hold E on you to revive you.`
end

local function updateJaws(dt: number)
	if not jawsGui.Enabled then
		return
	end
	if leaving then
		closed = math.max(closed - dt / cfg.OpenTime, 0)
		if closed <= 0 then
			jawsGui.Enabled = false
			return
		end
	else
		closed = math.min(closed + dt / cfg.BiteTime, 1)
		shownProgress += (getNumber("EscapeProgress") - shownProgress) * math.min(dt * cfg.FollowSpeed, 1)
		local secondsLeft = math.max(math.ceil(getNumber("DownUntil") - workspace:GetServerTimeNow()), 0)
		hint.Text = string.format(cfg.Text.Hint, secondsLeft)
	end
	pop = math.max(pop - dt * cfg.PopFade, 0)
	local chew = math.sin(os.clock() * cfg.JawChewSpeed) * cfg.JawChew
	local reach = cfg.ShutAt + (cfg.OpenAt - cfg.ShutAt) * shownProgress + chew - pop * cfg.PopSize
	local y = cfg.GoneAt + (reach - cfg.GoneAt) * closed
	topJaw.Position = UDim2.fromScale(0, y)
	bottomJaw.Position = UDim2.fromScale(0, 1 - y)
	tint.BackgroundTransparency = 1 - (1 - cfg.TintTransparency) * closed
end

local function hideIfMine(prompt: Instance)
	local character = player.Character
	if prompt:IsA("ProximityPrompt") and character and prompt:IsDescendantOf(character) then
		prompt.Enabled = false -- only on this screen; friends still see it
	end
end

-- Another player inside a mimic is held at the front of its trunk: hide them on this screen, so
-- they're really gone until they get out.
local function watchOtherPlayer(other: Player)
	if other == player then
		return
	end
	local function refresh()
		local hidden = other:GetAttribute("KnockedDown") == true and other:GetAttribute("DownCause") == "Swallowed"
		local character = other.Character
		if character then
			local modifier = if hidden then 1 else 0
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = modifier
				elseif part:IsA("Decal") then
					part.LocalTransparencyModifier = modifier
				end
			end
		end
	end
	other:GetAttributeChangedSignal("KnockedDown"):Connect(refresh)
	refresh()
end

local function buildSlamScreen()
	gui = Instance.new("ScreenGui")
	gui.Name = "Knockdown"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 8 -- below the Notify messages

	local slamTint = Instance.new("Frame")
	slamTint.Name = "Tint"
	slamTint.Size = UDim2.fromScale(1, 1)
	slamTint.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	slamTint.BackgroundTransparency = 0.8 -- light enough to still see what's going on
	slamTint.BorderSizePixel = 0
	slamTint.Parent = gui

	message = UiKit.text(slamTint, "Message", "")
	-- A fixed distance from the top, just under the boss HP bar (which ends 168 pixels down),
	-- so it never covers the bar, even on short screens.
	message.AnchorPoint = Vector2.new(0.5, 0)
	message.Position = UDim2.new(0.5, 0, 0, 176)
	message.Size = UDim2.new(0.8, 0, 0, 90)

	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 36
	limit.Parent = message

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function buildJawsScreen()
	jawsGui = Instance.new("ScreenGui")
	jawsGui.Name = "Swallowed"
	jawsGui.ResetOnSpawn = false
	jawsGui.Enabled = false
	jawsGui.IgnoreGuiInset = true -- cover the whole screen, also behind Roblox's top bar
	jawsGui.DisplayOrder = 8 -- below the Notify messages
	jawsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	tint = Instance.new("Frame")
	tint.Name = "Tint"
	tint.Size = UDim2.fromScale(1, 1)
	tint.BackgroundColor3 = cfg.TintColor
	tint.BackgroundTransparency = 1
	tint.BorderSizePixel = 0
	tint.Parent = jawsGui

	topJaw = UiKit.jaw(jawsGui, "TopJaw", true, cfg.GoneAt)
	bottomJaw = UiKit.jaw(jawsGui, "BottomJaw", false, cfg.GoneAt)

	-- Low on the screen: on the bottom jaw at first, and it stays there as you pry the jaw open.
	info = Instance.new("Frame")
	info.Name = "Info"
	info.AnchorPoint = Vector2.new(0.5, 0)
	info.Position = UDim2.fromScale(0.5, 0.68)
	info.Size = UDim2.fromScale(0.7, 0.26)
	info.BackgroundTransparency = 1
	info.ZIndex = 6
	info.Parent = jawsGui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(640, 170)
	sizeLimit.Parent = info

	local mashText = UiKit.text(info, "Mash", if UiKit.hasKeyboard() then cfg.Text.Mash else cfg.Text.MashTouch, Style.Gold, Style.TitleFont)
	mashText.Size = UDim2.fromScale(1, 0.5)

	escapeBar = UiKit.bar(info, "Escape", Style.Green)
	escapeBar.Frame.Position = UDim2.fromScale(0, 0.54)
	escapeBar.Frame.Size = UDim2.fromScale(1, 0.18)

	hint = UiKit.smallText(info, "Hint", "", Style.Cream)
	hint.Position = UDim2.fromScale(0, 0.76)
	hint.Size = UDim2.fromScale(1, 0.2)

	-- Clicks and taps count anywhere. This covers the whole screen, so they can't press the HUD's
	-- buttons behind the teeth by accident.
	mashArea = Instance.new("TextButton")
	mashArea.Name = "MashArea"
	mashArea.Size = UDim2.fromScale(1, 1)
	mashArea.BackgroundTransparency = 1
	mashArea.Text = ""
	mashArea.AutoButtonColor = false
	mashArea.Selectable = false
	mashArea.ZIndex = 7
	mashArea.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			mash()
		end
	end)
	mashArea.Parent = jawsGui

	jawsGui.Parent = player:WaitForChild("PlayerGui")
end

function KnockdownController.init()
	mashRemote = Remotes.getEvent("MashEscape")
	buildSlamScreen()
	buildJawsScreen()
end

function KnockdownController.start()
	player:GetAttributeChangedSignal("KnockedDown"):Connect(onKnockedDownChanged)
	onKnockedDownChanged()
	player:GetAttributeChangedSignal("EscapeProgress"):Connect(function()
		UiKit.setBar(escapeBar, getNumber("EscapeProgress"), "")
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		updateCountdown()
		updateJaws(dt)
	end)

	for _, prompt in CollectionService:GetTagged(Tags.RevivePrompt) do
		hideIfMine(prompt)
	end
	CollectionService:GetInstanceAddedSignal(Tags.RevivePrompt):Connect(hideIfMine)

	Players.PlayerAdded:Connect(watchOtherPlayer)
	for _, other in Players:GetPlayers() do
		watchOtherPlayer(other)
	end
end

return KnockdownController
