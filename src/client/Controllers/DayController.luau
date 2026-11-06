--!strict
-- The clock plank at the top middle of the screen, hanging on two ropes (the zone sign hangs under
-- it, see ZoneController):
--   * a stopwatch and the run's time ("0:31"), from the server's start time
--   * the day bar: it fills up with amber during the day, with the sun riding the end of the fill
--     and the time left until night ("6m 59s") next to it. At night the fill turns blue and the
--     sun becomes the moon.
-- Sizes and colours are in Config.Hud and Config.Day.
--
-- The server owns the clocks (Server/Systems/RunManager and DayManager); this only reads when
-- they started and works out the time with Shared/DayClock, so every player sees the same time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DayClock = require(ReplicatedStorage.Shared.DayClock)
local Icons = require(script.Parent.Parent.Icons)
local UiKit = require(script.Parent.Parent.UiKit)

local Day = Config.Day
local Hud = Config.Hud
local Text = Hud.Text
local Timber = Config.TimberUi
local UPDATE_EVERY = 0.1 -- seconds between updates
local RUN_STARTED_AT = "RunStartedAt" -- set on ReplicatedStorage by Server/Systems/RunManager
local RUN_ENDED_AT = "RunEndedAt"
local ROPE_ABOVE = 170 -- the ropes start this far above the plank, off the screen

local DayController = {}

local player = Players.LocalPlayer
local fill: Frame? = nil
local sun: Frame? = nil
local moon: Frame? = nil
local timeLabel: TextLabel? = nil
local runLabel: TextLabel? = nil

-- "6m 59s", or "42s" under a minute.
local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	if whole < 60 then
		return string.format(Day.Text.SecondsLeft, whole)
	end
	return string.format(Day.Text.TimeLeft, whole // 60, whole % 60)
end

-- The sun or moon, sitting on the bar's fill.
local function makeIcon(parent: Instance, name: string, draw: (parent: Instance, name: string) -> Frame): Frame
	local icon = draw(parent, name)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.Size = UDim2.fromOffset(Day.Icon, Day.Icon)
	icon.ZIndex = 2
	return icon
end

local function updateDay()
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

-- The run's time: from when the server started the run until now (or until the forest was cleared).
local function updateRunTime()
	local label = runLabel
	if not label then
		return
	end
	local started = ReplicatedStorage:GetAttribute(RUN_STARTED_AT)
	if typeof(started) ~= "number" then
		label.Text = string.format(Text.RunTime, 0, 0)
		return
	end
	local ended = ReplicatedStorage:GetAttribute(RUN_ENDED_AT)
	local now = if typeof(ended) == "number" then ended else workspace:GetServerTimeNow()
	local seconds = math.max(0, math.floor(now - started))
	local hours = seconds // 3600
	label.Text = if hours > 0
		then string.format(Text.RunTimeLong, hours, (seconds // 60) % 60, seconds % 60)
		else string.format(Text.RunTime, seconds // 60, seconds % 60)
end

function DayController.init()
	local gui = UiKit.screen("DayBar")

	local plank = UiKit.plank(gui, "Clock", 1)
	plank.AnchorPoint = Vector2.new(0.5, 0)
	plank.Position = UDim2.new(0.5, 0, 0, Hud.ClockY)
	plank.Size = UDim2.fromOffset(Hud.SignWidth, Hud.ClockHeight)

	for _, x in { Hud.RopeInset, Hud.SignWidth - Hud.RopeInset } do
		UiKit.rope(plank, "Rope", UDim2.fromOffset(x, -ROPE_ABOVE), ROPE_ABOVE + 8)
	end

	-- The stopwatch and the run's time, on the left.
	local left = Timber.NailInset + 8
	local watch = Icons.stopwatch(plank, "Stopwatch")
	watch.AnchorPoint = Vector2.new(0, 0.5)
	watch.Position = UDim2.new(0, left, 0.5, 0)
	watch.Size = UDim2.fromOffset(Hud.TimerIcon, Hud.TimerIcon)

	local run = UiKit.text(plank, "RunTime", "")
	run.AnchorPoint = Vector2.new(0, 0.5)
	run.Position = UDim2.new(0, left + Hud.TimerIcon + 4, 0.5, 0)
	run.Size = UDim2.fromOffset(Hud.TimerWidth, Hud.TimerText)
	run.TextXAlignment = Enum.TextXAlignment.Left
	runLabel = run

	-- The day bar, on the right. The holder keeps the sun from being cut off with the bar's fill.
	local barLeft = left + Hud.TimerIcon + Hud.TimerWidth + 16
	local holder = Instance.new("Frame")
	holder.Name = "Day"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, barLeft, 0.5, 0)
	holder.Size = UDim2.new(1, -(barLeft + Timber.NailInset + 18 + Day.TimeWidth), 0, Day.BarHeight)
	holder.Parent = plank

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Config.Style.BarBack
	UiKit.corner(bar, 4)
	UiKit.border(bar, Timber.Edge)
	bar.Parent = holder

	local newFill = Instance.new("Frame")
	newFill.Name = "Fill"
	newFill.Size = UDim2.fromScale(0, 1)
	newFill.BackgroundColor3 = Day.DayFill
	newFill.BorderSizePixel = 0
	UiKit.corner(newFill, 4)
	newFill.Parent = bar
	fill = newFill

	sun = makeIcon(holder, "Sun", Icons.sun)
	local newMoon = makeIcon(holder, "Moon", Icons.moon)
	newMoon.Visible = false
	moon = newMoon

	-- The time left, next to the bar.
	local label = UiKit.smallText(plank, "TimeLeft", "")
	label.AnchorPoint = Vector2.new(1, 0.5)
	label.Position = UDim2.new(1, -(Timber.NailInset + 12), 0.5, 0)
	label.Size = UDim2.fromOffset(Day.TimeWidth, Day.TimeText)
	label.TextXAlignment = Enum.TextXAlignment.Right
	timeLabel = label

	gui.Parent = player:WaitForChild("PlayerGui")
end

function DayController.start()
	while true do
		updateDay()
		updateRunTime()
		task.wait(UPDATE_EVERY)
	end
end

return DayController
