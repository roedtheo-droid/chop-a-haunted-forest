--!strict
-- The HUD's top-right corner, laid out like Chop a Forest (sizes and texts in Config.Hud):
--   * a stopwatch and the run's time ("0:31"), from the server's start time
--   * a red pin and the zone you're in ("Pale Pines"), "ZONE 1/3" under it
--   * a bar with "45.0% cleared" and the Elder Hollow's face on its end, and a small line under it
-- In the camp it only shows the stopwatch and "Lumber Camp".
-- When the zone is almost cleared, a glowing line points to the nearest tree that's left,
-- so nobody gets stuck hunting for the last tree.
-- It only DISPLAYS the progress the server shares in ReplicatedStorage.ZoneState.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local Boss = require(ReplicatedStorage.Shared.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Icons = require(script.Parent.Parent.Icons)
local UiKit = require(script.Parent.Parent.UiKit)

local GOLD = Config.Style.Gold
local Hud = Config.Hud
local Text = Hud.Text
local RUN_STARTED_AT = "RunStartedAt" -- set on ReplicatedStorage by Server/Systems/RunManager
local RUN_ENDED_AT = "RunEndedAt"
local MARKER_HEIGHT = 3 -- the line ends this far up the trunk

local ZoneController = {}

local player = Players.LocalPlayer
local stateFolder: Instance
local zoneRow: Frame
local zoneLabel: TextLabel
local countLabel: TextLabel
local barHolder: Frame
local bar: UiKit.Bar
local hintLabel: TextLabel
local timerLabel: TextLabel
-- The "nearest tree" helper. These only exist on this player's screen.
local marker: Part -- invisible; sits at the nearest tree, the line ends here
local markerSign: BillboardGui -- an arrow above that tree
local beam: Beam -- the glowing line
local playerAttachment: Attachment? -- the line starts here (inside your character)

local function getNumber(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function getRoot(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function findNearestTree(zoneIndex: number, from: Vector3): Model?
	local nearest: Model? = nil
	local nearestDistance = math.huge
	for _, instance in CollectionService:GetTagged(Tags.Tree) do
		if instance:IsA("Model") and instance:GetAttribute("ZoneId") == zoneIndex then
			local distance = (instance:GetPivot().Position - from).Magnitude
			if distance < nearestDistance then
				nearest = instance
				nearestDistance = distance
			end
		end
	end
	return nearest
end

local function hideHelper()
	beam.Enabled = false
	markerSign.Enabled = false
end

local function showHelper(root: BasePart, tree: Model)
	-- Your character is new after you respawn, so make a new start point for the line.
	local attachment = playerAttachment
	if not attachment or attachment.Parent ~= root then
		local newAttachment = Instance.new("Attachment")
		newAttachment.Name = "NearestTreeLine"
		newAttachment.Parent = root
		beam.Attachment0 = newAttachment
		playerAttachment = newAttachment
	end
	marker.CFrame = CFrame.new(tree:GetPivot().Position + Vector3.new(0, MARKER_HEIGHT, 0))
	beam.Enabled = true
	markerSign.Enabled = true
end

-- Show the zone's name, and its count, bar and hint (or only the name, in the camp).
local function showZone(name: string?, withProgress: boolean)
	zoneRow.Visible = name ~= nil
	zoneLabel.Text = name or ""
	countLabel.Visible = withProgress
	barHolder.Visible = withProgress
	hintLabel.Visible = withProgress
end

local function hideAll()
	local root = getRoot()
	showZone(if root and Zones.isInCamp(root.Position) then Text.Camp else nil, false)
	hideHelper()
end

-- The small line under the bar.
local function zoneHint(index: number, left: number): string
	local bossState = if index == Boss.ZoneId then ReplicatedStorage:FindFirstChild(Boss.StateFolderName) else nil
	local state = if bossState then bossState:GetAttribute("State") else nil
	if state == "Awake" then
		return Text.BossAwakeHint
	elseif state == "Defeated" then
		return Text.BossDefeatedHint
	elseif left == 0 then
		return Text.GateOpenHint
	end
	return Text.ZoneHints[index] or ""
end

local function update()
	local root = getRoot()
	if not root then
		hideAll()
		return
	end
	local index = Zones.indexAt(root.Position)
	if not index then
		hideAll()
		return
	end
	local state = stateFolder:FindFirstChild(tostring(index))
	local total = if state then getNumber(state, "Total") else 0
	if not state or total <= 0 then
		hideAll()
		return
	end

	local left = getNumber(state, "Left")
	local cleared = total - left
	local percent = math.floor(cleared * 100 / total)
	showZone(Config.Zones[index].Name, true)
	countLabel.Text = string.format(Text.ZoneCount, index, Zones.count())
	hintLabel.Text = zoneHint(index, left)
	UiKit.setBar(bar, cleared / total, if left == 0 then Text.AllCleared else string.format(Text.Cleared, cleared * 100 / total))
	bar.Fill.BackgroundColor3 = if left == 0 then GOLD else Config.Style.Green

	local tree = if left > 0 and percent >= Config.NearestTree.ShowAtPercent
		then findNearestTree(index, root.Position)
		else nil
	if tree then
		showHelper(root, tree)
	else
		hideHelper()
	end
end

-- Text at a fixed size (in 1080p pixels) that's exactly as wide as its words.
local function autoText(parent: Instance, name: string, size: number, color: Color3?): TextLabel
	local label = UiKit.text(parent, name, "", color)
	label.TextScaled = false
	label.TextSize = size
	label.Size = UDim2.fromOffset(0, size)
	label.AutomaticSize = Enum.AutomaticSize.X
	return label
end

-- A row of things lined up from the right edge: an icon, then text.
local function rightRow(parent: Instance, name: string, y: number, height: number): Frame
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(1, 0)
	row.Position = UDim2.new(1, 0, 0, y)
	row.Size = UDim2.new(1, 0, 0, height)
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row
	return row
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Zone"
	gui.ResetOnSpawn = false
	UiKit.hudScale(gui)

	-- Everything is stacked in the top-right corner, lined up on the right.
	local stack = Instance.new("Frame")
	stack.Name = "TopRight"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(1, 0)
	stack.Position = UDim2.new(1, -Hud.Margin, 0, Hud.Margin)
	stack.Size = UDim2.fromOffset(Hud.StackWidth, 260)
	stack.Parent = gui

	-- The stopwatch and the run's time.
	local timerRow = rightRow(stack, "Timer", 0, Hud.TimerIcon)
	local watch = Icons.stopwatch(timerRow, "Icon")
	watch.LayoutOrder = 1
	watch.Size = UDim2.fromOffset(Hud.TimerIcon, Hud.TimerIcon)
	timerLabel = autoText(timerRow, "Time", Hud.TimerText)
	timerLabel.LayoutOrder = 2

	-- The pin and the zone's name.
	local y = Hud.TimerIcon + 8
	zoneRow = rightRow(stack, "Zone", y, Hud.PinIcon)
	local pin = Icons.pin(zoneRow, "Icon")
	pin.LayoutOrder = 1
	pin.Size = UDim2.fromOffset(Hud.PinIcon, Hud.PinIcon)
	zoneLabel = autoText(zoneRow, "Name", Hud.ZoneText)
	zoneLabel.LayoutOrder = 2

	-- "ZONE 1/3"
	y += Hud.PinIcon + 2
	countLabel = UiKit.smallText(stack, "Count", "")
	countLabel.AnchorPoint = Vector2.new(1, 0)
	countLabel.Position = UDim2.new(1, 0, 0, y)
	countLabel.Size = UDim2.fromOffset(Hud.StackWidth, Hud.ZoneCountText)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- The "% cleared" bar, with the Elder Hollow's face sitting on its right end.
	y += Hud.ZoneCountText + 10
	barHolder = Instance.new("Frame")
	barHolder.Name = "Progress"
	barHolder.BackgroundTransparency = 1
	barHolder.AnchorPoint = Vector2.new(1, 0)
	barHolder.Position = UDim2.new(1, 0, 0, y)
	barHolder.Size = UDim2.fromOffset(Hud.ZoneBarWidth + Hud.BossIcon / 2, Hud.BossIcon)
	barHolder.Parent = stack
	bar = UiKit.bar(barHolder, "Bar")
	bar.Frame.AnchorPoint = Vector2.new(0, 0.5)
	bar.Frame.Position = UDim2.fromScale(0, 0.5)
	bar.Frame.Size = UDim2.fromOffset(Hud.ZoneBarWidth, Hud.ZoneBarHeight)
	UiKit.corner(bar.Frame, 999)
	UiKit.corner(bar.Fill, 999)
	local face = Icons.bossFace(barHolder, "Boss")
	face.AnchorPoint = Vector2.new(1, 0.5)
	face.Position = UDim2.fromScale(1, 0.5)
	face.Size = UDim2.fromOffset(Hud.BossIcon, Hud.BossIcon)
	face.ZIndex = 5
	for _, child in face:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex += 5
		end
	end

	-- The small line under the bar.
	y += Hud.BossIcon + 4
	hintLabel = UiKit.smallText(stack, "Hint", "")
	hintLabel.AnchorPoint = Vector2.new(1, 0)
	hintLabel.Position = UDim2.new(1, 0, 0, y)
	hintLabel.Size = UDim2.fromOffset(Hud.StackWidth, Hud.ZoneHintText)
	hintLabel.TextXAlignment = Enum.TextXAlignment.Right

	showZone(nil, false)
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- The run's time: from when the server started the run until now (or until the forest was cleared).
local function updateTimer()
	local started = ReplicatedStorage:GetAttribute(RUN_STARTED_AT)
	if typeof(started) ~= "number" then
		timerLabel.Text = string.format(Text.RunTime, 0, 0)
		return
	end
	local ended = ReplicatedStorage:GetAttribute(RUN_ENDED_AT)
	local now = if typeof(ended) == "number" then ended else workspace:GetServerTimeNow()
	local seconds = math.max(0, math.floor(now - started))
	local hours = seconds // 3600
	timerLabel.Text = if hours > 0
		then string.format(Text.RunTimeLong, hours, (seconds // 60) % 60, seconds % 60)
		else string.format(Text.RunTime, seconds // 60, seconds % 60)
end

local function buildHelper()
	-- A part made by a LocalScript only exists for this player, so other players never see your line.
	marker = Instance.new("Part")
	marker.Name = "NearestTreeMarker"
	marker.Size = Vector3.new(0.2, 0.2, 0.2)
	marker.Transparency = 1
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false -- so clicks go through it to the tree
	marker.CanTouch = false

	local endPoint = Instance.new("Attachment")
	endPoint.Parent = marker

	beam = Instance.new("Beam")
	beam.Attachment1 = endPoint
	beam.Color = ColorSequence.new(GOLD)
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.2)
	beam.Width0 = 0.4
	beam.Width1 = 0.4
	beam.FaceCamera = true
	beam.Enabled = false
	beam.Parent = marker

	markerSign = Instance.new("BillboardGui")
	markerSign.Size = UDim2.fromOffset(70, 70)
	markerSign.StudsOffsetWorldSpace = Vector3.new(0, 26, 0) -- above even the tallest treetops
	markerSign.Enabled = false
	markerSign.Parent = marker

	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▼"
	arrow.TextColor3 = GOLD
	arrow.TextStrokeTransparency = 0.3
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextScaled = true
	arrow.Parent = markerSign

	marker.Parent = workspace
end

function ZoneController.init()
	buildGui()
	buildHelper()
end

function ZoneController.start()
	stateFolder = ReplicatedStorage:WaitForChild(Zones.StateFolderName)

	-- The run timer ticks a few times a second, so the seconds never skip.
	local sinceTimer = math.huge
	RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceTimer += deltaTime
		if sinceTimer >= 0.2 then
			sinceTimer = 0
			updateTimer()
		end
	end)

	-- A few times a second: check which zone we're in and update the box and the line.
	task.spawn(function()
		while true do
			update()
			task.wait(Config.NearestTree.Refresh)
		end
	end)
end

return ZoneController
