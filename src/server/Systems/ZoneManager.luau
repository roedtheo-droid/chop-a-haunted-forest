--!strict
-- Builds the zones (ground, walls, gates) and keeps track of how much of each zone is cleared.
--
-- Zone progress is shared by the whole server. It lives in ReplicatedStorage.ZoneState,
-- one folder per zone ("1", "2", ...) with attributes the client can read (but not change):
--   Total  how many trees the zone started with
--   Left   how many are still standing
--   Open   true when players may go in (zone 1 always; the next one once the one before is cleared)
-- When a zone's Left reaches 0, the gate to the next zone sinks into the ground.
--
-- The walls are invisible. What you see is built by Build/Edges: hedges along the outside,
-- and a ridge or an old wall with a gatehouse between zones. Each gate is an invisible
-- blocker (as tall as the walls, so nobody jumps over) and the door you see in front of it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Zones = require(ReplicatedStorage.Shared.Zones)
local EffectsManager = require(script.Parent.EffectsManager)
local Blocky = require(script.Parent.Parent.Build.Blocky)
local Edges = require(script.Parent.Parent.Build.Edges)
local Ground = require(script.Parent.Parent.Build.Ground)

local FLOOR_THICKNESS = 1
local FLOOR_TOP = 0.05 -- a hair above the baseplate, so the two surfaces don't flicker
local IRON = Color3.fromRGB(45, 45, 52)
local PLANKS = 8 -- planks across a wooden door
local BARS = 9 -- bars across an iron door

-- A gate: the invisible blocker you bump into, and the door you see.
type Gate = {
	Blocker: BasePart,
	Door: BasePart,
}

local ZoneManager = {}

local notifyRemote: RemoteEvent
local states: { Folder } = {}
local gates: { Gate } = {} -- gates[i] is the gate from zone i into zone i + 1
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
	part.Color = Config.Scenery.FenceColor
	part.Material = Enum.Material.WoodPlanks
	part.Anchored = true
	part.Parent = parent
	return part
end

-- A wall nobody sees. The camera doesn't bump into see-through parts, so it never jumps
-- in front of one.
local function makeWall(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local wall = makePart(name, size, position, parent)
	wall.Transparency = 1
	wall.CastShadow = false
	return wall
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

-- Paint the door: wooden planks with two iron bands, or iron bars you can see through.
-- The side players walk up to (+Z, the Back face) gets a little plaque that says how to open it.
local function paintDoor(door: Part, look: Types.GateLookConfig, thisZone: string)
	local style = Config.Style
	if look.Door == "Iron" then
		door.Transparency = 1 -- only the bars painted on it show
	else
		door.Color = style.Wood
		door.Material = Enum.Material.WoodPlanks
	end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Blocky.face(door, face)
		if look.Door == "Iron" then
			for bar = 1, BARS do
				Blocky.rect(gui, bar / (BARS + 1) - 0.01, 0, 0.02, 1, IRON)
			end
			for _, y in { 0, 0.15, 0.82 } do
				Blocky.rect(gui, 0, y, 1, 0.035, IRON)
			end
		else
			for plank = 1, PLANKS - 1 do
				Blocky.rect(gui, plank / PLANKS - 0.004, 0, 0.008, 1, style.DarkWood)
			end
			Blocky.rect(gui, 0.495, 0, 0.01, 1, Blocky.shade(style.DarkWood, -0.3)) -- where the two halves meet
			for _, y in { 0.15, 0.8 } do
				Blocky.rect(gui, 0, y, 1, 0.05, IRON)
			end
		end
		if face == Enum.NormalId.Back then
			local plaque = Blocky.rect(gui, 0.3, 0.42, 0.4, 0.16, style.DarkWood)
			plaque.ZIndex = 2
			local text = Blocky.label(plaque, `Clear {thisZone}\nto open`, style.BodyFont)
			text.ZIndex = 3
		end
	end
end

local function buildGate(index: number, z: number, parent: Instance): Gate
	local cfg = Config.Gates
	local height = Config.Forest.WallHeight
	local looks = cfg.Looks
	local look = looks[math.min(index, #looks)]

	local blocker = makeWall(
		`Gate{index}`,
		Vector3.new(cfg.Width, height, Config.Forest.WallThickness),
		Vector3.new(0, height / 2, z),
		parent
	)
	local door = makePart(
		`Gate{index}Door`,
		Vector3.new(cfg.Width, cfg.DoorHeight, cfg.DoorDepth),
		Vector3.new(0, FLOOR_TOP + cfg.DoorHeight / 2, z),
		parent
	)
	-- The blocker does the stopping (and the "Clear every tree first" message).
	door.CanCollide = false
	door.CanQuery = false
	door.CanTouch = false
	paintDoor(door, look, Config.Zones[index].Name)
	return { Blocker = blocker, Door = door }
end

-- Walls all the way around the forest, plus a wall with a gate between each pair of zones.
local function buildWalls(parent: Instance)
	local cfg = Config.Forest
	local height = cfg.WallHeight
	local thick = cfg.WallThickness
	-- The walls go around the camp too (it's in front of zone 1).
	local camp = Zones.getCampBounds()
	local last = Zones.getBounds(Zones.count())
	local nearZ, farZ = camp.MaxZ, last.MinZ
	local halfWidth = cfg.Width / 2
	local length = nearZ - farZ
	local middleZ = (nearZ + farZ) / 2
	local y = height / 2

	-- Left, right, back (behind the camp) and far end.
	makeWall("LeftWall", Vector3.new(thick, height, length), Vector3.new(-halfWidth - thick / 2, y, middleZ), parent)
	makeWall("RightWall", Vector3.new(thick, height, length), Vector3.new(halfWidth + thick / 2, y, middleZ), parent)
	makeWall("BackWall", Vector3.new(cfg.Width + thick * 2, height, thick), Vector3.new(0, y, nearZ + thick / 2), parent)
	makeWall("FarWall", Vector3.new(cfg.Width + thick * 2, height, thick), Vector3.new(0, y, farZ - thick / 2), parent)

	-- Between zones: two wall pieces with the gate in the middle.
	local gateWidth = Config.Gates.Width
	local pieceWidth = (cfg.Width - gateWidth) / 2
	local pieceOffset = gateWidth / 2 + pieceWidth / 2
	for index = 1, Zones.count() - 1 do
		local z = Zones.getBounds(index).MinZ
		makeWall(`Divider{index}Left`, Vector3.new(pieceWidth, height, thick), Vector3.new(-pieceOffset, y, z), parent)
		makeWall(`Divider{index}Right`, Vector3.new(pieceWidth, height, thick), Vector3.new(pieceOffset, y, z), parent)
		gates[index] = buildGate(index, z, parent)
	end
end

-- Move a part `depth` studs down into the ground over Config.Gates.OpenTime.
local function sink(part: BasePart, depth: number): Tween
	local tween = TweenService:Create(
		part,
		TweenInfo.new(Config.Gates.OpenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = part.Position - Vector3.new(0, depth, 0) }
	)
	tween:Play()
	return tween
end

local function openGate(index: number)
	local gate = gates[index]
	if not gate then
		return
	end
	local blocker, door = gate.Blocker, gate.Door
	blocker.CanTouch = false
	-- A grinding rumble and dust where the door sinks into the ground.
	EffectsManager.playSound("GateOpen", door.Position)
	EffectsManager.burst("Dust", Vector3.new(door.Position.X, FLOOR_TOP, door.Position.Z))
	sink(blocker, blocker.Size.Y + 1).Completed:Connect(function()
		blocker.CanCollide = false
	end)
	sink(door, door.Size.Y + 1).Completed:Connect(function()
		door.Transparency = 1
		for _, child in door:GetChildren() do
			if child:IsA("SurfaceGui") then
				child.Enabled = false
			end
		end
	end)
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
	Ground.build(workspace) -- soft patches of colour on the floors
	Edges.build(workspace) -- the hedges, ridge, old wall and gatehouses in front of the walls
end

function ZoneManager.start()
	notifyRemote = Remotes.getEvent("Notify")

	for index, gate in gates do
		gate.Blocker.Touched:Connect(function(hit: BasePart)
			onGateTouched(index, hit)
		end)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		lastGateMessage[player] = nil
	end)
end

return ZoneManager
