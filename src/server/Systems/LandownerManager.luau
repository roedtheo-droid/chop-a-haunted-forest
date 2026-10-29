--!strict
-- Mr. Graves, the landowner who hired the party (see Config.Landowner). He stands in front of
-- his steel vault in the camp (see Build/Vault), with a "Talk" prompt that shows how many
-- trees are left in the WHOLE forest. The server keeps that number up to date from the
-- zones' "Left" counters (see ZoneManager).
--
-- He's built here from plain parts and stands still. His idle animation, the dialogue box
-- and the little bird are drawn on each player's own computer (see LandownerController).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Blocky = require(script.Parent.Parent.Build.Blocky)
local Vault = require(script.Parent.Parent.Build.Vault)

local SHOES = Color3.fromRGB(15, 15, 15)
local GLASSES = Color3.fromRGB(10, 10, 12)

local LandownerManager = {}

local prompt: ProximityPrompt

local function groundHeightAt(x: number, z: number): number
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0))
	return if result then result.Position.Y else 0
end

-- One piece of him, sized and placed for a 1x Mr. Graves with his feet at (0, 0, 0) and his
-- front towards -Z. `group` says how it moves in his idle (see LandownerController).
type Piece = { Name: string, Size: Vector3, At: Vector3, Color: Color3, Group: string, Turn: number? }

local function pieces(): { Piece }
	local cfg = Config.Landowner
	local suit, skin, hair = cfg.SuitColor, cfg.SkinColor, cfg.HairColor
	local list: { Piece } = {
		{ Name = "Torso", Size = Vector3.new(2.1, 2.4, 1.1), At = Vector3.new(0, 4.1, 0), Color = suit, Group = "Body" },
		{ Name = "Shirt", Size = Vector3.new(0.7, 1, 0.05), At = Vector3.new(0, 4.8, -0.56), Color = cfg.ShirtColor, Group = "Body" },
		{ Name = "Tie", Size = Vector3.new(0.26, 1.15, 0.06), At = Vector3.new(0, 4.62, -0.6), Color = cfg.TieColor, Group = "Body" },
		{ Name = "Head", Size = Vector3.new(1.4, 1.4, 1.4), At = Vector3.new(0, 6, 0), Color = skin, Group = "Head" },
		{ Name = "Hair", Size = Vector3.new(1.5, 0.4, 1.5), At = Vector3.new(0, 6.85, 0.02), Color = hair, Group = "Head" },
		{ Name = "Hair", Size = Vector3.new(1.5, 1, 0.3), At = Vector3.new(0, 6.35, 0.65), Color = hair, Group = "Head" },
		{ Name = "Glasses", Size = Vector3.new(0.25, 0.1, 0.1), At = Vector3.new(0, 6.22, -0.73), Color = GLASSES, Group = "Head" },
		{ Name = "Mouth", Size = Vector3.new(0.45, 0.1, 0.05), At = Vector3.new(0.1, 5.62, -0.71), Color = Color3.fromRGB(90, 40, 35), Group = "Head", Turn = 8 },
	}
	for _, side in { -1, 1 } do
		local arm = if side < 0 then "ArmL" else "ArmR"
		table.insert(list, { Name = "Shoe", Size = Vector3.new(0.9, 0.45, 1.3), At = Vector3.new(side * 0.5, 0.225, -0.15), Color = SHOES, Group = "Legs" })
		table.insert(list, { Name = "Leg", Size = Vector3.new(0.9, 2.45, 0.9), At = Vector3.new(side * 0.5, 1.675, 0), Color = suit, Group = "Legs" })
		table.insert(list, { Name = "Arm", Size = Vector3.new(0.75, 2.2, 0.85), At = Vector3.new(side * 1.45, 4.15, 0), Color = suit, Group = arm })
		table.insert(list, { Name = "Hand", Size = Vector3.new(0.65, 0.6, 0.7), At = Vector3.new(side * 1.45, 2.75, 0), Color = skin, Group = arm })
		table.insert(list, { Name = "Lens", Size = Vector3.new(0.55, 0.38, 0.1), At = Vector3.new(side * 0.33, 6.15, -0.72), Color = GLASSES, Group = "Head" })
		table.insert(list, { Name = "Glasses", Size = Vector3.new(0.08, 0.1, 0.8), At = Vector3.new(side * 0.72, 6.2, -0.35), Color = GLASSES, Group = "Head" })
	end
	return list
end

-- Builds Mr. Graves standing on `base` (his feet), facing its -Z. Returns his torso.
local function buildNpc(parent: Instance, base: CFrame): BasePart
	local scale = Config.Landowner.Scale
	local model = Instance.new("Model")
	model.Name = "MrGraves"
	-- Stream him to players' computers as one piece, so his idle never sees half of him.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local torso: BasePart? = nil
	for _, info in pieces() do
		local cframe = base * CFrame.new(info.At * scale) * CFrame.Angles(0, 0, math.rad(info.Turn or 0))
		local material = if info.Color == Config.Landowner.SuitColor then Enum.Material.Fabric else Enum.Material.SmoothPlastic
		local part = Blocky.part(info.Name, info.Size * scale, cframe, info.Color, material, model)
		part:SetAttribute("Group", info.Group)
		if info.Name == "Hair" or info.Name == "Lens" or info.Name == "Shoe" then
			part.Reflectance = 0.2 -- slicked-back hair, shiny sunglasses and shoes
		end
		if info.Group == "Head" and info.Name ~= "Head" then
			part.CanCollide = false
		end
		if info.Name == "Torso" then
			torso = part
		end
	end

	-- The points his idle moves around, in his own space (feet at 0, 0, 0).
	model:SetAttribute("Hip", Vector3.new(0, 2.9, 0) * scale)
	model:SetAttribute("Neck", Vector3.new(0, 5.3, 0) * scale)
	model:SetAttribute("ShoulderL", Vector3.new(-1.45, 5.15, 0) * scale)
	model:SetAttribute("ShoulderR", Vector3.new(1.45, 5.15, 0) * scale)
	model.WorldPivot = base
	model.Parent = parent
	CollectionService:AddTag(model, Tags.Landowner)
	assert(torso, "Mr. Graves has no torso")
	return torso
end

-- How many trees are left in the whole forest: every zone's "Left" counter added up.
-- (The Elder Hollow counts as one of the last zone's trees.)
local function treesLeft(): number
	local total = 0
	local states = ReplicatedStorage:FindFirstChild(Zones.StateFolderName)
	if states then
		for _, state in states:GetChildren() do
			local left = state:GetAttribute("Left")
			if typeof(left) == "number" then
				total += left
			end
		end
	end
	return total
end

local function refreshPrompt()
	prompt.ObjectText = string.format(Config.Landowner.TreesLeftText, Format.number(treesLeft()))
end

function LandownerManager.init()
	local cfg = Config.Landowner
	local folder = Instance.new("Folder")
	folder.Name = "Landowner"

	local spot = cfg.VaultPosition
	local ground = Vector3.new(spot.X, groundHeightAt(spot.X, spot.Z), spot.Z)
	local base = CFrame.lookAt(ground, Vector3.new(cfg.FaceToward.X, ground.Y, cfg.FaceToward.Z))
	Vault.build(folder, base)

	local npcBase = base * CFrame.new(0, 0, -cfg.VaultSize.Z / 2 - cfg.NpcDistance)
	local torso = buildNpc(folder, npcBase)

	prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = cfg.PromptAction
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = cfg.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso
	CollectionService:AddTag(prompt, Tags.LandownerPrompt)

	folder.Parent = workspace
end

function LandownerManager.start()
	-- Every tree that falls changes one zone's "Left", so watch all of them.
	local states = ReplicatedStorage:WaitForChild(Zones.StateFolderName)
	for _, state in states:GetChildren() do
		state:GetAttributeChangedSignal("Left"):Connect(refreshPrompt)
	end
	refreshPrompt()
end

return LandownerManager
