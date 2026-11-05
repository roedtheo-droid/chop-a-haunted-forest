--!strict
-- The quest panel in the top-right corner, under the Coins (the purple HUD, see Config.Hud).
-- It shows the tutorial quest you're on and the next ones (Config.Hud.QuestRows in all),
-- each with a green bar. The next ones are faded until you get to them.
-- It only DISPLAYS the QuestIndex and QuestProgress attributes the server sets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local UiKit = require(script.Parent.Parent.UiKit)

local Hud = Config.Hud

local PADDING = 16 -- pixels inside the panel
local HEADER_HEIGHT = 26
local ROW_HEIGHT = 44 -- the quest's text and its bar
local FADED = 0.5 -- how see-through the next quests are

local QuestController = {}

type Row = {
	Frame: Frame,
	Text: TextLabel,
	Count: TextLabel,
	Bar: UiKit.Bar,
}

local player = Players.LocalPlayer
local panel: Frame
local countLabel: TextLabel
local rows: { Row } = {}
local hideToken = 0 -- so an old "hide" timer can't hide the panel after it changed again

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function addRow(index: number): Row
	local frame = Instance.new("Frame")
	frame.Name = `Row{index}`
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(PADDING, PADDING + HEADER_HEIGHT + (index - 1) * ROW_HEIGHT)
	frame.Size = UDim2.new(1, -2 * PADDING, 0, ROW_HEIGHT)
	frame.Parent = panel

	local text = UiKit.hudText(frame, "Text", "", 15)
	text.Size = UDim2.new(0.75, 0, 0, 20)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd

	local count = UiKit.hudText(frame, "Count", "", 15)
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.fromScale(1, 0)
	count.Size = UDim2.new(0.25, 0, 0, 20)
	count.TextXAlignment = Enum.TextXAlignment.Right

	local bar = UiKit.hudBar(frame, "Bar", Hud.Green)
	bar.Frame.Position = UDim2.fromOffset(0, 24)
	bar.Frame.Size = UDim2.new(1, 0, 0, 8)

	return { Frame = frame, Text = text, Count = count, Bar = bar }
end

-- Fill in one row. `active` is false for the quests after the one you're on.
local function showRow(row: Row, text: string, progress: number, goal: number, active: boolean)
	row.Frame.Visible = true
	row.Text.Text = text
	row.Count.Text = `{progress}/{goal}`
	UiKit.setBar(row.Bar, progress / math.max(goal, 1), "")
	local transparency = if active then 0 else FADED
	row.Text.TextTransparency = transparency
	row.Count.TextTransparency = transparency
	row.Bar.Frame.BackgroundTransparency = transparency
end

local function setRowCount(count: number)
	for index, row in rows do
		row.Frame.Visible = index <= count
	end
	panel.Size = UDim2.fromOffset(Hud.QuestWidth, 2 * PADDING + HEADER_HEIGHT + math.max(count, 1) * ROW_HEIGHT - 8)
end

local function refresh()
	local index = getNumber("QuestIndex")
	local quests = Config.Quests
	hideToken += 1

	if index < 1 then
		panel.Visible = false -- the server hasn't set up quests yet
		return
	end

	countLabel.Text = `{math.min(index - 1, #quests)}/{#quests}`

	if not quests[index] then
		-- All done: say so for a few seconds, then hide.
		setRowCount(1)
		local row = rows[1]
		row.Frame.Visible = true
		row.Text.Text = "All quests done!"
		row.Text.TextTransparency = 0
		row.Count.Text = ""
		UiKit.setBar(row.Bar, 1, "")
		row.Bar.Frame.BackgroundTransparency = 0
		panel.Visible = true
		local myToken = hideToken
		task.delay(Config.UI.QuestsDoneHideDelay, function()
			if hideToken == myToken then
				panel.Visible = false
			end
		end)
		return
	end

	local shown = 0
	for offset = 0, #rows - 1 do
		local quest = quests[index + offset]
		if not quest then
			break
		end
		shown += 1
		local progress = if offset == 0 then math.min(getNumber("QuestProgress"), quest.Goal) else 0
		showRow(rows[shown], quest.Text, progress, quest.Goal, offset == 0)
	end
	setRowCount(shown)
	panel.Visible = true
end

-- Make room for "TRIAL 2:59" under the pills (Client/HudController) while a trial runs.
local function placePanel()
	local trial = typeof(player:GetAttribute(Shop.TRIAL_ENDS)) == "number"
	local top = Hud.Margin + Hud.PillHeight + 10 + (if trial then Config.Trial.HudGap else 0)
	panel.Position = UDim2.new(1, -Hud.Margin, 0, top)
end

function QuestController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Quests"
	gui.ResetOnSpawn = false
	UiKit.hudScale(gui)

	panel = UiKit.hudPanel(gui, "Panel")
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Visible = false

	local title = UiKit.hudText(panel, "Title", Hud.QuestTitle, 13, Hud.Green)
	title.Position = UDim2.fromOffset(PADDING, PADDING - 4)
	title.Size = UDim2.new(0.5, 0, 0, 18)
	title.TextXAlignment = Enum.TextXAlignment.Left

	countLabel = UiKit.hudText(panel, "Count", "", 13, Hud.Muted)
	countLabel.AnchorPoint = Vector2.new(1, 0)
	countLabel.Position = UDim2.new(1, -PADDING, 0, PADDING - 4)
	countLabel.Size = UDim2.new(0.5, 0, 0, 18)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right

	for index = 1, Hud.QuestRows do
		table.insert(rows, addRow(index))
	end
	setRowCount(Hud.QuestRows)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function QuestController.start()
	placePanel()
	player:GetAttributeChangedSignal(Shop.TRIAL_ENDS):Connect(placePanel)
	refresh()
	player:GetAttributeChangedSignal("QuestIndex"):Connect(refresh)
	player:GetAttributeChangedSignal("QuestProgress"):Connect(refresh)
end

return QuestController
