--!strict
-- Shows the current tutorial quest in the top-left corner (as STYLE_GUIDE.md says), with a
-- little scroll icon and a green bar for quests that take more than one step ("Pick up 3 logs").
-- Sizes are on a 1080p screen and grow and shrink with it (UiKit.hudScale, Config.Hud).
-- It only DISPLAYS the QuestIndex and QuestProgress attributes the server sets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(script.Parent.Parent.Icons)
local UiKit = require(script.Parent.Parent.UiKit)

local Hud = Config.Hud
local BOX_WIDTH = Hud.QuestWidth
local ICON_SIZE = 48
local TEXT_LEFT = ICON_SIZE + 22 -- the texts start right of the scroll
local BOX_HEIGHT = 84 -- without the bar
local BAR_HEIGHT = 24

local QuestController = {}

local player = Players.LocalPlayer
local box: Frame
local titleLabel: TextLabel
local textLabel: TextLabel
local bar: UiKit.Bar
local hideToken = 0 -- so an old "hide" timer can't hide the box after it changed again

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- The bar only shows for quests with more than one step. The box grows to make room for it.
local function showBar(visible: boolean)
	bar.Frame.Visible = visible
	box.Size = UDim2.fromOffset(BOX_WIDTH, if visible then BOX_HEIGHT + BAR_HEIGHT + 12 else BOX_HEIGHT)
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
		showBar(false)
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
	textLabel.Text = quest.Text
	if quest.Goal > 1 then
		local progress = getNumber("QuestProgress")
		UiKit.setBar(bar, progress / quest.Goal, `{progress}/{quest.Goal}`)
	end
	showBar(quest.Goal > 1)
	box.Visible = true
end

function QuestController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Quests"
	gui.ResetOnSpawn = false

	UiKit.hudScale(gui)

	box = UiKit.box(gui, "Box")
	-- Top-left corner (below Roblox's own buttons, which the ScreenGui already keeps clear of).
	box.Position = UDim2.fromOffset(Hud.Margin, Hud.Margin)
	box.Size = UDim2.fromOffset(BOX_WIDTH, BOX_HEIGHT)
	box.Visible = false

	local icon = Icons.quest(box, "Icon")
	icon.Position = UDim2.fromOffset(12, 14)
	icon.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)

	titleLabel = UiKit.text(box, "Title", "", Config.Style.Gold)
	titleLabel.Position = UDim2.fromOffset(TEXT_LEFT, 10)
	titleLabel.Size = UDim2.new(1, -(TEXT_LEFT + 12), 0, Hud.QuestText - 2)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	textLabel = UiKit.text(box, "Text", "")
	textLabel.Position = UDim2.fromOffset(TEXT_LEFT, 14 + Hud.QuestText)
	textLabel.Size = UDim2.new(1, -(TEXT_LEFT + 12), 0, Hud.QuestText + 4)
	textLabel.TextXAlignment = Enum.TextXAlignment.Left

	bar = UiKit.bar(box, "Bar")
	bar.Frame.Position = UDim2.fromOffset(12, BOX_HEIGHT)
	bar.Frame.Size = UDim2.new(1, -24, 0, BAR_HEIGHT)
	bar.Frame.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")
end

function QuestController.start()
	refresh()
	player:GetAttributeChangedSignal("QuestIndex"):Connect(refresh)
	player:GetAttributeChangedSignal("QuestProgress"):Connect(refresh)
end

return QuestController
