--!strict
-- Shows which zone you're in and how much of it is cleared, at the top of the screen:
-- "Zone 1: Pale Pines" with a bar that says "45% cleared".
-- When the zone is almost cleared, a glowing line points to the nearest tree that's left,
-- so nobody gets stuck hunting for the last tree.
-- It only DISPLAYS the progress the server shares in ReplicatedStorage.ZoneState.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Zones = require(ReplicatedStorage.Shared.Zones)
local UiKit = require(script.Parent.Parent.UiKit)

local GOLD = Config.Style.Gold
local MARKER_HEIGHT = 3 -- the line ends this far up the trunk

local ZoneController = {}

local player = Players.LocalPlayer
local stateFolder: Instance
local box: Frame
local titleLabel: TextLabel
local bar: UiKit.Bar
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

local function hideAll()
	box.Visible = false
	hideHelper()
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
	titleLabel.Text = `Zone {index}: {Config.Zones[index].Name}`
	UiKit.setBar(bar, cleared / total, if left == 0 then "100% cleared!" else `{percent}% cleared`)
	bar.Fill.BackgroundColor3 = if left == 0 then GOLD else Config.Style.Green
	box.Visible = true

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
	local gui = Instance.new("ScreenGui")
	gui.Name = "Zone"
	gui.ResetOnSpawn = false

	box = UiKit.box(gui, "Box")
	-- Top middle of the screen, above where messages appear.
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 12)
	box.Size = UDim2.fromOffset(260, 54)
	box.Visible = false

	titleLabel = UiKit.text(box, "Title", "")
	titleLabel.Position = UDim2.fromOffset(10, 4)
	titleLabel.Size = UDim2.new(1, -20, 0, 20)

	bar = UiKit.bar(box, "Bar")
	bar.Frame.Position = UDim2.fromOffset(10, 28)
	bar.Frame.Size = UDim2.new(1, -20, 0, 18)

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
