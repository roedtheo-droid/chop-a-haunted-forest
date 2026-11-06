--!strict
-- The current tutorial quest, on a pinned parchment note in the top-right column (under the ledger
-- plank and the trial tag, see HudController), with a green bar for quests that take more than
-- one step ("Pick up 3 logs"). Sizes are in Config.Hud (pixels on a 1080p screen).
-- It only DISPLAYS the QuestIndex and QuestProgress attributes the server sets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local UiKit = require(script.Parent.Parent.UiKit)
local HudController = require(script.Parent.HudController)

local Hud = Config.Hud
local Timber = Config.TimberUi
local EDGE = 16 -- pixels from the note's sides to its writing

local QuestController = {}

local player = Players.LocalPlayer
local note: Frame
local titleLabel: TextLabel
local textLabel: TextLabel
local bar: UiKit.Bar
local hideToken = 0 -- so an old "hide" timer can't hide the note after it changed again

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- The bar only shows for quests with more than one step. The note grows to make room for it.
local function showBar(visible: boolean)
	bar.Frame.Visible = visible
	local height = if visible then Hud.QuestHeight + Hud.QuestBarHeight + 8 else Hud.QuestHeight
	note.Size = UDim2.fromOffset(Hud.QuestWidth, height)
end

local function refresh()
	local index = getNumber("QuestIndex")
	local total = #Config.Quests
	local quest = Config.Quests[index]
	hideToken += 1

	if index < 1 then
		note.Visible = false -- no quests: the server hasn't set them up, or you've done the tutorial
		return
	end

	if not quest then
		titleLabel.Text = "Quests"
		textLabel.Text = "All quests done!"
		showBar(false)
		note.Visible = true
		local myToken = hideToken
		task.delay(Config.UI.QuestsDoneHideDelay, function()
			if hideToken == myToken then
				note.Visible = false
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
	note.Visible = true
end

function QuestController.init()
	note = UiKit.paper(HudController.rightColumn(), "Quest")
	note.LayoutOrder = 3
	note.Rotation = Hud.QuestTilt
	note.Size = UDim2.fromOffset(Hud.QuestWidth, Hud.QuestHeight)
	note.Visible = false

	titleLabel = UiKit.ink(note, "Title", "", Timber.Pin)
	titleLabel.Position = UDim2.fromOffset(EDGE, 12)
	titleLabel.Size = UDim2.new(1, -2 * EDGE, 0, Hud.QuestTitleText)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	textLabel = UiKit.ink(note, "Text", "")
	textLabel.Position = UDim2.fromOffset(EDGE, 14 + Hud.QuestTitleText)
	textLabel.Size = UDim2.new(1, -2 * EDGE, 0, Hud.QuestHeight - Hud.QuestTitleText - 22)
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = Hud.QuestText
	textLimit.Parent = textLabel

	bar = UiKit.bar(note, "Bar")
	bar.Frame.Position = UDim2.fromOffset(EDGE, Hud.QuestHeight - 6)
	bar.Frame.Size = UDim2.new(1, -2 * EDGE, 0, Hud.QuestBarHeight)
	bar.Frame.Visible = false
end

function QuestController.start()
	refresh()
	player:GetAttributeChangedSignal("QuestIndex"):Connect(refresh)
	player:GetAttributeChangedSignal("QuestProgress"):Connect(refresh)
end

return QuestController
