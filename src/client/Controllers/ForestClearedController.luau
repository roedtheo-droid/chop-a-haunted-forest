--!strict
-- The FOREST CLEARED! screen, shown when the Elder Hollow falls.
-- The server sends the party's totals for the run (RunManager); this only shows them.
-- Close it to keep walking around the cleared forest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local GOLD = Color3.fromRGB(255, 220, 90)
local EMBER_COLOR = Color3.fromRGB(255, 130, 60)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local DIM_TEXT = Color3.fromRGB(190, 190, 190)
local PANEL_COLOR = Color3.fromRGB(28, 30, 28)
local ROW_COLOR = Color3.fromRGB(45, 50, 45)
local BUTTON_COLOR = Color3.fromRGB(60, 150, 70)
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

local function makeText(parent: Instance, name: string, text: string, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.Font = font
	label.TextScaled = true
	label.Parent = parent
	return label
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function addRow(list: Frame, key: string, title: string, order: number)
	local row = Instance.new("Frame")
	row.Name = key
	-- A quarter of the list each (minus the gaps), so the rows shrink on small phone screens.
	row.Size = UDim2.new(1, 0, 1 / ROW_COUNT, -ROW_GAP)
	row.BackgroundColor3 = ROW_COLOR
	row.LayoutOrder = order
	row.Parent = list
	corner(row, 8)

	local name = makeText(row, "Title", title, DIM_TEXT, Enum.Font.GothamBold)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Position = UDim2.new(0, 12, 0.2, 0)
	name.Size = UDim2.new(0.6, -12, 0.6, 0)

	local value = makeText(row, "Value", "0", TEXT_COLOR, Enum.Font.GothamBlack)
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
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.85)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.Parent = gui
	corner(panel, 14)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(420, 400)
	sizeLimit.Parent = panel

	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	local title = makeText(panel, "Title", "FOREST CLEARED!", GOLD, Enum.Font.GothamBlack)
	title.Position = UDim2.new(0, 16, 0, 14)
	title.Size = UDim2.new(1, -32, 0, 44)

	local subtitle = makeText(panel, "Subtitle", "The Elder Hollow has fallen.", DIM_TEXT, Enum.Font.Gotham)
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

	embersLabel = makeText(panel, "Embers", "", EMBER_COLOR, Enum.Font.GothamBlack)
	embersLabel.AnchorPoint = Vector2.new(0.5, 1)
	embersLabel.Position = UDim2.new(0.5, 0, 1, -72)
	embersLabel.Size = UDim2.new(1, -32, 0, 30)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -16)
	close.Size = UDim2.new(0.6, 0, 0, 44)
	close.BackgroundColor3 = BUTTON_COLOR
	close.Text = "Close"
	close.TextColor3 = TEXT_COLOR
	close.Font = Enum.Font.GothamBold
	close.TextScaled = true
	close.Parent = panel
	corner(close, 10)
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
