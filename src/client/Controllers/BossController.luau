--!strict
-- The Elder Hollow's HP bar, at the top of the screen while it's awake.
-- It only SHOWS the boss state the server keeps in ReplicatedStorage.BossState.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boss = require(ReplicatedStorage.Shared.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local UiKit = require(script.Parent.Parent.UiKit)

local BAR_COLOR = Color3.fromRGB(255, 110, 40) -- same as the glowing roots

local BossController = {}

local player = Players.LocalPlayer
local stateFolder: Instance
local box: Frame
local bar: UiKit.Bar

local function getNumber(name: string): number
	local value = stateFolder:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refresh()
	box.Visible = stateFolder:GetAttribute("State") == "Awake"
	local hp = getNumber("HP")
	local maxHP = math.max(getNumber("MaxHP"), 1)
	UiKit.setBar(bar, hp / maxHP, `{math.ceil(hp)} / {maxHP}`)
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossBar"
	gui.ResetOnSpawn = false

	-- Top middle, under the zone box and the message line.
	box = UiKit.box(gui, "Box")
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 116)
	box.Size = UDim2.new(0.6, 0, 0, 54)
	box.Visible = false

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(480, 54)
	sizeLimit.Parent = box

	local title = UiKit.text(box, "Title", "THE ELDER HOLLOW", BAR_COLOR, Config.Style.TitleFont)
	title.Position = UDim2.fromOffset(10, 4)
	title.Size = UDim2.new(1, -20, 0, 20)

	bar = UiKit.bar(box, "Bar", BAR_COLOR)
	bar.Frame.Position = UDim2.fromOffset(10, 28)
	bar.Frame.Size = UDim2.new(1, -20, 0, 18)
	bar.Fill.Size = UDim2.fromScale(1, 1)

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
