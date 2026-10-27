--!strict
-- Builds the zones (ground, walls, gates) and keeps track of how much of each zone is cleared.
--
-- Zone progress is shared by the whole server. It lives in ReplicatedStorage.ZoneState,
-- one folder per zone ("1", "2", ...) with attributes the client can read (but not change):
--   Total  how many trees the zone started with
--   Left   how many are still standing
--   Open   true when players may go in (zone 1 always; the next one once the one before is cleared)
-- When a zone's Left reaches 0, the gate to the next zone sinks into the ground.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Zones = require(ReplicatedStorage.Shared.Zones)

local WALL_COLOR = Color3.fromRGB(45, 40, 38)
local GATE_COLOR = Color3.fromRGB(30, 30, 34)
local FLOOR_THICKNESS = 1
local FLOOR_TOP = 0.05 -- a hair above the baseplate, so the two surfaces don't flicker

local ZoneManager = {}

local notifyRemote: RemoteEvent
local states: { Folder } = {}
local gates: { BasePart } = {} -- gates[i] is the gate from zone i into zone i + 1
local lastGateMessage: { [Player]: number } = {}

local function getNumber(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function makePart(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = WALL_COLOR
	part.Material = Enum.Material.WoodPlanks
	part.Anchored = true
	part.Parent = parent
	return part
end

local function makeSignText(parent: Instance, text: string)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = parent
end

-- One flat floor per zone, so each zone has its own ground colour.
local function buildFloors(parent: Instance)
	for index, zone in Config.Zones do
		local bounds = Zones.getBounds(index)
		local floor = makePart(
			`{zone.Name} Floor`,
			Vector3.new(bounds.MaxX - bounds.MinX, FLOOR_THICKNESS, bounds.MaxZ - bounds.MinZ),
			Vector3.new(
				(bounds.MinX + bounds.MaxX) / 2,
				FLOOR_TOP - FLOOR_THICKNESS / 2,
				(bounds.MinZ + bounds.MaxZ) / 2
			),
			parent
		)
		floor.Color = zone.GroundColor
		floor.Material = zone.GroundMaterial
	end
end

local function buildGate(index: number, z: number, parent: Instance): BasePart
	local cfg = Config.Forest
	local height = cfg.WallHeight
	local gate =
		makePart(`Gate{index}`, Vector3.new(Config.Gates.Width, height, cfg.WallThickness), Vector3.new(0, height / 2, z), parent)
	gate.Color = GATE_COLOR
	gate.Material = Enum.Material.Metal

	-- A sign on both sides of the gate.
	local thisZone = Config.Zones[index].Name
	local nextZone = Config.Zones[index + 1].Name
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sign = Instance.new("SurfaceGui")
		sign.Face = face
		sign.Parent = gate
		makeSignText(sign, `{nextZone}\nClear {thisZone} to open`)
	end
	return gate
end

-- Walls all the way around the forest, plus a wall with a gate between each pair of zones.
local function buildWalls(parent: Instance)
	local cfg = Config.Forest
	local height = cfg.WallHeight
	local thick = cfg.WallThickness
	local first = Zones.getBounds(1)
	local last = Zones.getBounds(Zones.count())
	local nearZ, farZ = first.MaxZ, last.MinZ
	local halfWidth = cfg.Width / 2
	local length = nearZ - farZ
	local middleZ = (nearZ + farZ) / 2
	local y = height / 2

	-- Left, right, back (behind spawn) and far end.
	makePart("LeftWall", Vector3.new(thick, height, length), Vector3.new(-halfWidth - thick / 2, y, middleZ), parent)
	makePart("RightWall", Vector3.new(thick, height, length), Vector3.new(halfWidth + thick / 2, y, middleZ), parent)
	makePart("BackWall", Vector3.new(cfg.Width + thick * 2, height, thick), Vector3.new(0, y, nearZ + thick / 2), parent)
	makePart("FarWall", Vector3.new(cfg.Width + thick * 2, height, thick), Vector3.new(0, y, farZ - thick / 2), parent)

	-- Between zones: two wall pieces with the gate in the middle.
	local gateWidth = Config.Gates.Width
	local pieceWidth = (cfg.Width - gateWidth) / 2
	local pieceOffset = gateWidth / 2 + pieceWidth / 2
	for index = 1, Zones.count() - 1 do
		local z = Zones.getBounds(index).MinZ
		makePart(`Divider{index}Left`, Vector3.new(pieceWidth, height, thick), Vector3.new(-pieceOffset, y, z), parent)
		makePart(`Divider{index}Right`, Vector3.new(pieceWidth, height, thick), Vector3.new(pieceOffset, y, z), parent)
		gates[index] = buildGate(index, z, parent)
	end
end

local function openGate(index: number)
	local gate = gates[index]
	if not gate then
		return
	end
	gate.CanTouch = false
	local tween = TweenService:Create(
		gate,
		TweenInfo.new(Config.Gates.OpenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = gate.Position - Vector3.new(0, Config.Forest.WallHeight + 1, 0) }
	)
	tween.Completed:Connect(function()
		gate.CanCollide = false
		gate.Transparency = 1
	end)
	tween:Play()
end

local function onGateTouched(index: number, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = if character then Players:GetPlayerFromCharacter(character) else nil
	if not player then
		return
	end
	-- Don't repeat the message every frame while the player leans on the gate.
	local now = os.clock()
	local last = lastGateMessage[player]
	if last and now - last < Config.Gates.MessageCooldown then
		return
	end
	lastGateMessage[player] = now

	local left = getNumber(states[index], "Left")
	notifyRemote:FireClient(player, `Clear every tree in {Config.Zones[index].Name} first ({left} left)`)
end

-- Is this zone open to players? Used by TreeManager so nobody can chop past a closed gate.
function ZoneManager.isOpen(index: number): boolean
	local state = states[index]
	return state ~= nil and state:GetAttribute("Open") == true
end

-- ForestSpawner calls this for every tree it spawns.
function ZoneManager.addTree(index: number)
	local state = states[index]
	state:SetAttribute("Total", getNumber(state, "Total") + 1)
	state:SetAttribute("Left", getNumber(state, "Left") + 1)
end

-- TreeManager calls this once when a tree in the zone falls.
function ZoneManager.treeCleared(index: number)
	local state = states[index]
	if not state then
		return
	end
	local left = math.max(getNumber(state, "Left") - 1, 0)
	state:SetAttribute("Left", left)
	if left > 0 then
		return
	end

	-- The whole zone is cleared! Open the gate to the next zone (if there is one).
	local name = Config.Zones[index].Name
	local nextState = states[index + 1]
	if nextState then
		nextState:SetAttribute("Open", true)
		openGate(index)
		notifyRemote:FireAllClients(`{name} is cleared! The gate to {Config.Zones[index + 1].Name} is open.`)
	else
		notifyRemote:FireAllClients(`{name} is cleared! The whole forest is clear!`)
	end
end

function ZoneManager.init()
	-- Live progress for the client.
	local stateFolder = Instance.new("Folder")
	stateFolder.Name = Zones.StateFolderName
	for index = 1, Zones.count() do
		local state = Instance.new("Folder")
		state.Name = tostring(index)
		state:SetAttribute("Total", 0)
		state:SetAttribute("Left", 0)
		state:SetAttribute("Open", index == 1)
		state.Parent = stateFolder
		states[index] = state
	end
	stateFolder.Parent = ReplicatedStorage

	-- The ground, walls and gates. Built in init() so the other systems
	-- (trees, sawmills, Tool Shed) find the right ground height when they set up.
	local model = Instance.new("Model")
	model.Name = "Zones"
	buildFloors(model)
	buildWalls(model)
	model.Parent = workspace
end

function ZoneManager.start()
	notifyRemote = Remotes.getEvent("Notify")

	for index, gate in gates do
		gate.Touched:Connect(function(hit: BasePart)
			onGateTouched(index, hit)
		end)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		lastGateMessage[player] = nil
	end)
end

return ZoneManager
