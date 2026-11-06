--!strict
-- The zone sign at the top middle of the screen, hanging on two ropes under the clock plank
-- (see DayController; sizes and texts are in Config.Hud):
--   * the zone you're in ("Pale Pines") in big letters
--   * a bar with "45.0% cleared" and the Elder Hollow's face on its end
--   * a small line about what to do, and "ZONE 1/3"
-- In the camp it's a small sign with only "Lumber Camp".
-- When the zone is almost cleared, a glowing line points to the nearest tree that's left,
-- so nobody gets stuck hunting for the last tree.
-- It only DISPLAYS the progress the server shares in ReplicatedStorage.ZoneState.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boss = require(ReplicatedStorage.Shared.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Icons = require(script.Parent.Parent.Icons)
local UiKit = require(script.Parent.Parent.UiKit)

local GOLD = Config.Style.Gold
local Hud = Config.Hud
local Text = Hud.Text
local Timber = Config.TimberUi
local MARKER_HEIGHT = 3 -- the line ends this far up the trunk

local ZoneController = {}

local player = Players.LocalPlayer
local stateFolder: Instance
local sign: Frame
local zoneLabel: TextLabel
local countLabel: TextLabel
local barHolder: Frame
local bar: UiKit.Bar
local hintLabel: TextLabel
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
	sign.Visible = name ~= nil
	sign.Size = UDim2.fromOffset(Hud.SignWidth, if withProgress then Hud.SignHeight else Hud.CampSignHeight)
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

local function buildGui()
	local gui = UiKit.screen("Zone")
	local edge = Timber.NailInset + 10

	sign = UiKit.plank(gui, "Sign", 2)
	sign.AnchorPoint = Vector2.new(0.5, 0)
	sign.Position = UDim2.new(0.5, 0, 0, Hud.SignY)

	-- The ropes it hangs on, from behind the clock plank.
	local ropeLength = Hud.SignY - Hud.ClockY - Hud.ClockHeight + 14
	for _, x in { Hud.RopeInset, Hud.SignWidth - Hud.RopeInset } do
		UiKit.rope(sign, "Rope", UDim2.fromOffset(x, 8 - ropeLength), ropeLength)
	end

	zoneLabel = UiKit.text(sign, "Name", "", GOLD, Config.Style.TitleFont)
	zoneLabel.Position = UDim2.new(0, edge, 0, 10)
	zoneLabel.Size = UDim2.new(1, -2 * edge, 0, Hud.ZoneText)

	-- The "% cleared" bar, with the Elder Hollow's face sitting on its right end.
	barHolder = Instance.new("Frame")
	barHolder.Name = "Progress"
	barHolder.BackgroundTransparency = 1
	barHolder.Position = UDim2.new(0, edge, 0, Hud.ZoneText + 12)
	barHolder.Size = UDim2.new(1, -2 * edge, 0, Hud.ZoneBarHeight)
	barHolder.Parent = sign
	bar = UiKit.bar(barHolder, "Bar")
	bar.Frame.Size = UDim2.new(1, -Hud.BossIcon / 2, 1, 0)
	local face = Icons.bossFace(barHolder, "Boss")
	face.AnchorPoint = Vector2.new(1, 0.5)
	face.Position = UDim2.fromScale(1, 0.5)
	face.Size = UDim2.fromOffset(Hud.BossIcon, Hud.BossIcon)
	face.ZIndex = 2

	-- The small line under the bar, and "ZONE 1/3" at its end.
	local lineY = Hud.ZoneText + Hud.ZoneBarHeight + 18
	hintLabel = UiKit.smallText(sign, "Hint", "")
	hintLabel.Position = UDim2.new(0, edge, 0, lineY)
	hintLabel.Size = UDim2.new(1, -(2 * edge + Hud.ZoneCountWidth), 0, Hud.ZoneHintText)
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left

	countLabel = UiKit.smallText(sign, "Count", "", Config.Style.Cream)
	countLabel.AnchorPoint = Vector2.new(1, 0)
	countLabel.Position = UDim2.new(1, -edge, 0, lineY)
	countLabel.Size = UDim2.fromOffset(Hud.ZoneCountWidth, Hud.ZoneCountText)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right

	showZone(nil, false)
	gui.Parent = player:WaitForChild("PlayerGui")
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

	-- A few times a second: check which zone we're in and update the box and the line.
	task.spawn(function()
		while true do
			update()
			task.wait(Config.NearestTree.Refresh)
		end
	end)
end

return ZoneController
