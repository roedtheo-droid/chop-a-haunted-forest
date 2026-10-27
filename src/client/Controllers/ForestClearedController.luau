--!strict
-- The FOREST CLEARED! screen, shown when the Elder Hollow falls.
-- The server sends the party's totals for the run (RunManager); this only shows them.
-- Close it to keep walking around the cleared forest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local UiKit = require(script.Parent.Parent.UiKit)

local Style = Config.Style
local ROW_COUNT = 4 -- trees, mimics, coins, time
local ROW_GAP = 6

local ForestClearedController = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local panelScale: UIScale
local values: { [string]: TextLabel } = {} -- the number label in each stat row
local embersLabel: TextLabel

-- 75 seconds -> "1:15", 3725 seconds -> "1:02:05"
local function formatTime(seconds: number): string
	local hours = seconds // 3600
	local minutes = (seconds // 60) % 60
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

local function addRow(list: Frame, key: string, title: string, order: number)
	local row = UiKit.card(list, key)
	-- A quarter of the list each (minus the gaps), so the rows shrink on small phone screens.
	row.Size = UDim2.new(1, 0, 1 / ROW_COUNT, -ROW_GAP)
	row.LayoutOrder = order

	local name = UiKit.text(row, "Title", title, Style.Cream)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Position = UDim2.new(0, 12, 0.2, 0)
	name.Size = UDim2.new(0.6, -12, 0.6, 0)

	local value = UiKit.text(row, "Value", "0")
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, -12, 0.2, 0)
	value.Size = UDim2.new(0.4, -12, 0.6, 0)
	values[key] = value
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "ForestCleared"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10 -- on top of the HUD and the knockdown screen
	gui.Enabled = false

	-- Darken the whole screen behind the panel.
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.Parent = gui

	-- The panel uses a share of the screen, but never gets too big on a PC
	-- (UISizeConstraint), so it reads well on phones and computers alike.
	local panel = UiKit.panel(gui, "Panel")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.85)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(420, 400)
	sizeLimit.Parent = panel

	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	local title = UiKit.text(panel, "Title", "FOREST CLEARED!", Style.Gold, Style.TitleFont)
	title.Position = UDim2.new(0, 16, 0, 14)
	title.Size = UDim2.new(1, -32, 0, 44)

	local subtitle = UiKit.smallText(panel, "Subtitle", "The Elder Hollow has fallen.", Style.Cream)
	subtitle.Position = UDim2.new(0, 16, 0, 60)
	subtitle.Size = UDim2.new(1, -32, 0, 20)

	local list = Instance.new("Frame")
	list.Name = "Stats"
	list.Position = UDim2.new(0, 16, 0, 92)
	list.Size = UDim2.new(1, -32, 1, -92 - 120)
	list.BackgroundTransparency = 1
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	addRow(list, "TreesFelled", "Trees felled", 1)
	addRow(list, "MimicsBurned", "Mimics burned", 2)
	addRow(list, "CoinsEarned", "Coins earned", 3)
	addRow(list, "Time", "Time", 4)

	embersLabel = UiKit.text(panel, "Embers", "", Style.Ember)
	embersLabel.AnchorPoint = Vector2.new(0.5, 1)
	embersLabel.Position = UDim2.new(0.5, 0, 1, -72)
	embersLabel.Size = UDim2.new(1, -32, 0, 30)

	local close = UiKit.button(panel, "Close", "Close", Style.Green)
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -16)
	close.Size = UDim2.new(0.6, 0, 0, 44)
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function show(summary: Types.RunSummary)
	values.TreesFelled.Text = tostring(summary.TreesFelled)
	values.MimicsBurned.Text = tostring(summary.MimicsBurned)
	values.CoinsEarned.Text = tostring(summary.CoinsEarned)
	values.Time.Text = formatTime(summary.Seconds)
	embersLabel.Text = `+{summary.Embers} Embers for everyone!`

	-- Pop in: start small and grow to full size with a little overshoot.
	gui.Enabled = true
	panelScale.Scale = 0.6
	TweenService:Create(panelScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

function ForestClearedController.init()
	buildGui()
end

function ForestClearedController.start()
	Remotes.getEvent("ForestCleared").OnClientEvent:Connect(show)
end

return ForestClearedController
