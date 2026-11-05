--!strict
-- The day/night bar at the top middle of the screen, like Chop a Forest's.
-- A navy bar fills up with yellow during the day, with the sun riding the end of the fill and
-- the time left until night ("6m 59s") on top. At night the fill turns blue and the sun
-- becomes the moon. Sizes and colours are in Config.Day.
--
-- The server owns the clock (Server/Systems/DayManager); this only reads when it started
-- and works out the time with Shared/DayClock, so every player sees the same time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DayClock = require(ReplicatedStorage.Shared.DayClock)
local Icons = require(script.Parent.Parent.Icons)
local UiKit = require(script.Parent.Parent.UiKit)

local Day = Config.Day
local UPDATE_EVERY = 0.1 -- seconds between bar updates
local ICON_Z = 3 -- how much the sun and moon are raised, so they sit over the fill

local DayController = {}

local player = Players.LocalPlayer
local fill: Frame? = nil
local sun: Frame? = nil
local moon: Frame? = nil
local timeLabel: TextLabel? = nil

-- "6m 59s", or "42s" under a minute.
local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	if whole < 60 then
		return string.format(Day.Text.SecondsLeft, whole)
	end
	return string.format(Day.Text.TimeLeft, whole // 60, whole % 60)
end

-- The sun or moon, sitting on the bar. It's raised above the fill; its pieces are raised too,
-- because a piece with a lower ZIndex than its parent would be drawn behind the bar.
local function makeIcon(parent: Instance, name: string, draw: (parent: Instance, name: string) -> Frame): Frame
	local icon = draw(parent, name)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.Size = UDim2.fromOffset(Day.Icon, Day.Icon)
	icon.ZIndex += ICON_Z
	for _, child in icon:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex += ICON_Z
		end
	end
	return icon
end

local function update()
	local startedAt = ReplicatedStorage:GetAttribute(DayClock.STARTED_AT)
	if typeof(startedAt) ~= "number" or not (fill and sun and moon and timeLabel) then
		return -- the server hasn't started the clock yet
	end
	local state = DayClock.state(startedAt, workspace:GetServerTimeNow())
	fill.Size = UDim2.fromScale(state.Progress, 1)
	fill.BackgroundColor3 = if state.IsNight then Day.NightFill else Day.DayFill
	local icon = if state.IsNight then moon else sun
	icon.Position = UDim2.fromScale(state.Progress, 0.5)
	sun.Visible = not state.IsNight
	moon.Visible = state.IsNight
	timeLabel.Text = formatTime(state.SecondsLeft)
end

function DayController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DayBar"
	gui.ResetOnSpawn = false
	UiKit.hudScale(gui)

	-- The holder is as tall as the sun, so the bar sits in its middle and the sun pokes out.
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, Config.Hud.Margin)
	holder.Size = UDim2.fromOffset(Day.BarWidth, Day.Icon)
	holder.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.Size = UDim2.new(1, 0, 0, Day.BarHeight)
	bar.BackgroundColor3 = Day.Navy
	UiKit.corner(bar, 999)
	UiKit.border(bar)
	bar.Parent = holder

	local newFill = Instance.new("Frame")
	newFill.Name = "Fill"
	newFill.Size = UDim2.fromScale(0, 1)
	newFill.BackgroundColor3 = Day.DayFill
	newFill.BorderSizePixel = 0
	newFill.ZIndex = 2
	UiKit.corner(newFill, 999)
	newFill.Parent = bar
	fill = newFill

	sun = makeIcon(bar, "Sun", Icons.sun)
	local newMoon = makeIcon(bar, "Moon", Icons.moon)
	newMoon.Visible = false
	moon = newMoon

	-- The time left, on top of everything (even the sun when it passes the middle).
	local label = UiKit.text(bar, "TimeLeft", "")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, 0, 0, Day.TimeText)
	label.ZIndex = 10
	timeLabel = label

	gui.Parent = player:WaitForChild("PlayerGui")
end

function DayController.start()
	while true do
		update()
		task.wait(UPDATE_EVERY)
	end
end

return DayController
