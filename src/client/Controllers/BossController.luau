--!strict
-- The Elder Hollow's HP bar, at the top of the screen while it's awake.
-- It only SHOWS the boss state the server keeps in ReplicatedStorage.BossState.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Boss = require(ReplicatedStorage.Shared.Boss)

local BG_COLOR = Color3.fromRGB(25, 20, 22)
local BAR_BG = Color3.fromRGB(60, 45, 45)
local BAR_COLOR = Color3.fromRGB(255, 110, 40) -- same as the glowing roots
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)

local BossController = {}

local player = Players.LocalPlayer
local stateFolder: Instance
local box: Frame
local fill: Frame
local hpLabel: TextLabel

local function getNumber(name: string): number
	local value = stateFolder:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refresh()
	box.Visible = stateFolder:GetAttribute("State") == "Awake"
	local hp = getNumber("HP")
	local maxHP = math.max(getNumber("MaxHP"), 1)
	hpLabel.Text = `{math.ceil(hp)} / {maxHP}`
	-- Slide the bar down smoothly instead of jumping.
	TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(hp / maxHP, 1) }):Play()
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossBar"
	gui.ResetOnSpawn = false

	-- Top middle, under the zone box and the message line.
	box = Instance.new("Frame")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 116)
	box.Size = UDim2.new(0.6, 0, 0, 52)
	box.BackgroundColor3 = BG_COLOR
	box.BackgroundTransparency = 0.2
	box.Visible = false
	box.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(480, 52)
	sizeLimit.Parent = box

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = box

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(10, 4)
	title.Size = UDim2.new(1, -20, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = "THE ELDER HOLLOW"
	title.TextColor3 = BAR_COLOR
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Parent = box

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(10, 27)
	bar.Size = UDim2.new(1, -20, 0, 18)
	bar.BackgroundColor3 = BAR_BG
	bar.Parent = box

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 6)
	barCorner.Parent = bar

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = BAR_COLOR
	fill.Parent = bar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HP"
	hpLabel.Size = UDim2.fromScale(1, 1)
	hpLabel.BackgroundTransparency = 1
	hpLabel.TextColor3 = TEXT_COLOR
	hpLabel.TextStrokeTransparency = 0.4
	hpLabel.Font = Enum.Font.GothamBold
	hpLabel.TextScaled = true
	hpLabel.ZIndex = 2
	hpLabel.Parent = bar

	gui.Parent = player:WaitForChild("PlayerGui")
end

function BossController.init()
	buildGui()
end

function BossController.start()
	stateFolder = ReplicatedStorage:WaitForChild(Boss.StateFolderName)
	stateFolder.AttributeChanged:Connect(refresh)
	refresh()
end

return BossController
