--!strict
-- Shows the current tutorial quest on the left side of the screen, under the Coins.
-- It only DISPLAYS the QuestIndex and QuestProgress attributes the server sets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local GOLD = Color3.fromRGB(255, 220, 90)

local QuestController = {}

local player = Players.LocalPlayer
local box: Frame
local titleLabel: TextLabel
local textLabel: TextLabel
local hideToken = 0 -- so an old "hide" timer can't hide the box after it changed again

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refresh()
	local index = getNumber("QuestIndex")
	local total = #Config.Quests
	local quest = Config.Quests[index]
	hideToken += 1

	if index < 1 then
		box.Visible = false -- the server hasn't set up quests yet
		return
	end

	if not quest then
		titleLabel.Text = "Quests"
		textLabel.Text = "All quests done!"
		box.Visible = true
		local myToken = hideToken
		task.delay(Config.UI.QuestsDoneHideDelay, function()
			if hideToken == myToken then
				box.Visible = false
			end
		end)
		return
	end

	titleLabel.Text = `Quest {index}/{total}`
	if quest.Goal > 1 then
		textLabel.Text = `{quest.Text}  {getNumber("QuestProgress")}/{quest.Goal}`
	else
		textLabel.Text = quest.Text
	end
	box.Visible = true
end

function QuestController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Quests"
	gui.ResetOnSpawn = false

	box = Instance.new("Frame")
	box.Name = "Box"
	-- Just under the Coins label (which is centered at 45% height).
	box.Position = UDim2.new(0, 16, 0.45, 28)
	box.Size = UDim2.fromOffset(250, 62)
	box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	box.BackgroundTransparency = 0.3
	box.Visible = false
	box.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = box

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(10, 6)
	titleLabel.Size = UDim2.new(1, -20, 0, 20)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextColor3 = GOLD
	titleLabel.TextScaled = true
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = box

	textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.BackgroundTransparency = 1
	textLabel.Position = UDim2.fromOffset(10, 30)
	textLabel.Size = UDim2.new(1, -20, 0, 24)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextScaled = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.Parent = box

	gui.Parent = player:WaitForChild("PlayerGui")
end

function QuestController.start()
	refresh()
	player:GetAttributeChangedSignal("QuestIndex"):Connect(refresh)
	player:GetAttributeChangedSignal("QuestProgress"):Connect(refresh)
end

return QuestController
