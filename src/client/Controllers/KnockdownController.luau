--!strict
-- When a mimic catches you: your character falls over, the screen turns red and shows
-- how long until you get up. The server decides all of this (the KnockedDown and
-- DownUntil attributes, and your speed); this only SHOWS it.
-- It also hides the "Revive" prompt on your own character: that one is for your friends.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)

local TIP_OVER_SPEED = 6 -- how hard your character tips over when you're knocked down

local KnockdownController = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local message: TextLabel
local wasDown = false

local function isDown(): boolean
	return player:GetAttribute("KnockedDown") == true
end

local function getHumanoid(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Fall over (or get back up). Your own computer moves your character,
-- so this is done here; the server already stopped you from walking.
local function setFallen(fallen: boolean)
	local humanoid = getHumanoid()
	if not humanoid then
		return
	end
	humanoid.PlatformStand = fallen
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if fallen and root and root:IsA("BasePart") then
		root.AssemblyAngularVelocity = root.CFrame.RightVector * TIP_OVER_SPEED
	elseif not fallen then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function onKnockedDownChanged()
	local down = isDown()
	gui.Enabled = down
	if down ~= wasDown then
		wasDown = down
		setFallen(down)
	end
end

local function updateCountdown()
	if not gui.Enabled then
		return
	end
	local downUntil = player:GetAttribute("DownUntil")
	local secondsLeft = if typeof(downUntil) == "number"
		then math.max(math.ceil(downUntil - workspace:GetServerTimeNow()), 0)
		else 0
	message.Text = `A mimic caught you!\nGetting up in {secondsLeft}s. A friend can hold E on you to revive you.`
end

local function hideIfMine(prompt: Instance)
	local character = player.Character
	if prompt:IsA("ProximityPrompt") and character and prompt:IsDescendantOf(character) then
		prompt.Enabled = false -- only on this screen; friends still see it
	end
end

function KnockdownController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Knockdown"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 8 -- below the Notify messages

	local tint = Instance.new("Frame")
	tint.Name = "Tint"
	tint.Size = UDim2.fromScale(1, 1)
	tint.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	tint.BackgroundTransparency = 0.8 -- light enough to still see what's going on
	tint.BorderSizePixel = 0
	tint.Parent = gui

	message = Instance.new("TextLabel")
	message.Name = "Message"
	message.AnchorPoint = Vector2.new(0.5, 0.5)
	message.Position = UDim2.fromScale(0.5, 0.4)
	message.Size = UDim2.new(0.8, 0, 0, 90)
	message.BackgroundTransparency = 1
	message.TextColor3 = Color3.fromRGB(255, 255, 255)
	message.TextStrokeTransparency = 0.3
	message.Font = Enum.Font.GothamBlack
	message.TextScaled = true
	message.Parent = tint

	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 36
	limit.Parent = message

	gui.Parent = player:WaitForChild("PlayerGui")
end

function KnockdownController.start()
	player:GetAttributeChangedSignal("KnockedDown"):Connect(onKnockedDownChanged)
	onKnockedDownChanged()
	RunService.Heartbeat:Connect(updateCountdown)

	for _, prompt in CollectionService:GetTagged(Tags.RevivePrompt) do
		hideIfMine(prompt)
	end
	CollectionService:GetInstanceAddedSignal(Tags.RevivePrompt):Connect(hideIfMine)
end

return KnockdownController
