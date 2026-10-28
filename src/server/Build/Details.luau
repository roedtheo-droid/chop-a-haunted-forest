--!strict
-- Little things scattered over each zone's ground (see Config.Details): grass tufts and
-- flowers in Pale Pines, ferns and glowing mushrooms in Fog Hollow, dead leaves and a few
-- bones in Graveyard Grove. Never on the path, the landmarks, a sawmill's spot, the boss's
-- clearing or right by the borders between zones.
-- They're the Blender models in blender/models/details.py once they're imported into Studio;
-- until then fewer of them, made of a few small parts each. Only for looks: you walk through
-- them, raycasts (clicks, the ground checks) go through them, and they cast no shadows.
-- LandmarkManager calls Details.build. It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boss = require(ReplicatedStorage.Shared.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Assets = require(script.Parent.Assets)
local Blocky = require(script.Parent.Blocky)

local GROUND = 0.05 -- the top of the zone floors (see ZoneManager)
local LIFT = 0.06 -- a hair up, so flat things (dead leaves) stay above the ground's colour patches
local TRIES = 10 -- spots to try for each one before giving up on it

local Details = {}

local folder: Folder
local random = Random.new(41) -- the same details every time

local function soft(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- Is (x, z) a good spot for a detail in zone `index`?
local function isFree(index: number, x: number, z: number): boolean
	local cfg = Config.Details
	local zone = Config.Zones[index]
	local bounds = Zones.getBounds(index)
	return x > bounds.MinX + cfg.EdgeGap
		and x < bounds.MaxX - cfg.EdgeGap
		and z > bounds.MinZ + cfg.BorderGap
		and z < bounds.MaxZ - cfg.BorderGap
		and Zones.distanceToPath(x, z) > cfg.PathGap
		and not Zones.isNearLandmark(x, z)
		and Vector2.new(x - zone.Sawmill.X, z - zone.Sawmill.Z).Magnitude > zone.ClearRadius
		and not Boss.isInClearing(Vector3.new(x, 0, z))
end

-- The Blender version: colour each part (Stem and Dot get the stem colour, the rest `color`).
local function meshDetail(detail: Types.DetailConfig, base: Vector3, size: number, color: Color3): boolean
	local model = Assets.model(detail.Model)
	if not model then
		return false
	end
	local reference = model:FindFirstChild(detail.Part)
	if not (reference and reference:IsA("BasePart")) then
		model:Destroy()
		return false
	end
	Assets.fit(model, reference, size, base, CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
	for _, part in model:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		elseif part.Name == "Dot" and detail.Glow then
			part:Destroy() -- glowing mushrooms have no white spots
			continue
		elseif part.Name == "Stem" or part.Name == "Dot" then
			part.Color = detail.StemColor or color
			part.Material = Enum.Material.SmoothPlastic
		else
			part.Color = color
			part.Material = if detail.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
		soft(part)
	end
	model.Name = detail.Model
	model.Parent = folder
	return true
end

-- The parts version: upright blades for grass and ferns, a stem with a bloom or a cap for
-- flowers and mushrooms, and a few flat bits for dead leaves and bones.
local function partsDetail(detail: Types.DetailConfig, base: Vector3, size: number, color: Color3)
	local material = if detail.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local function add(name: string, partSize: Vector3, cframe: CFrame, partColor: Color3, partMaterial: Enum.Material)
		soft(Blocky.part(name, partSize, cframe, partColor, partMaterial, folder))
	end
	local model = detail.Model
	if model == "Flowers" or model == "Mushrooms" then
		local height = size * 0.5
		local stem = detail.StemColor or color
		local middle = CFrame.new(base + Vector3.new(0, height / 2, 0))
		add("Stem", Vector3.new(0.2, height, 0.2), middle, stem, Enum.Material.SmoothPlastic)
		local top = if model == "Flowers" then Vector3.new(0.6, 0.5, 0.6) else Vector3.new(1, 0.45, 1) * size * 0.6
		add("Top", top, CFrame.new(base + Vector3.new(0, height + top.Y / 2, 0)), color, material)
	elseif model == "GrassTuft" or model == "Fern" then
		for index = 1, 3 do
			local height = size * random:NextNumber(0.4, 0.7)
			local lean = CFrame.Angles(random:NextNumber(-0.4, 0.4), index * 2.1, random:NextNumber(-0.4, 0.4))
			add("Blade", Vector3.new(0.2, height, 0.2), CFrame.new(base) * lean * CFrame.new(0, height / 2, 0), color, material)
		end
	else
		for _ = 1, 3 do
			local offset = Vector3.new(random:NextNumber(-size / 3, size / 3), 0.05, random:NextNumber(-size / 3, size / 3))
			local turn = CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
			add("Bit", Vector3.new(size * 0.25, 0.1, size * 0.15), CFrame.new(base + offset) * turn, color, material)
		end
	end
end

-- Scatter every detail of zone `index`.
local function scatter(index: number)
	local cfg = Config.Details
	local bounds = Zones.getBounds(index)
	for _, detail in cfg.Zones[index] or {} do
		local fromModels = Assets.has(detail.Model)
		local count = if fromModels then detail.Count else math.floor(detail.Count * cfg.FallbackShare)
		for _ = 1, count do
			for _ = 1, TRIES do
				local x = random:NextNumber(bounds.MinX, bounds.MaxX)
				local z = random:NextNumber(bounds.MinZ, bounds.MaxZ)
				if isFree(index, x, z) then
					local base = Vector3.new(x, GROUND + LIFT, z)
					local size = random:NextNumber(detail.Size[1], detail.Size[2])
					local color = Blocky.shade(detail.Colors[random:NextInteger(1, #detail.Colors)], random:NextNumber(-0.06, 0.06))
					if not (fromModels and meshDetail(detail, base, size, color)) then
						partsDetail(detail, base, size, color)
					end
					break
				end
			end
		end
	end
end

-- Build all the details into a folder called "Details" in `parent`.
function Details.build(parent: Instance)
	folder = Instance.new("Folder")
	folder.Name = "Details"
	for index = 1, Zones.count() do
		scatter(index)
	end
	folder.Parent = parent
end

return Details
