--!strict
-- Soft patches of colour on the floors (see Config.Ground), so the camp and each zone aren't
-- one flat colour. Where two zones meet, each one's colour frays into the other, so the
-- ground doesn't change at a straight line.
-- The patches are the Blender "Patch" models (flat blobs) once they're imported, or roundish
-- patches made of parts. Only for looks: you walk through them, and raycasts looking for the
-- ground go through them too. ZoneManager calls Ground.build after it makes the floors.
-- It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Assets = require(script.Parent.Assets)
local Blocky = require(script.Parent.Blocky)

local FLOOR_TOP = 0.05 -- the top of the floors (see ZoneManager)
local THICKNESS = 0.06 -- the Blender patches are stretched this thin
local LAYERS = 5 -- patches sit at 5 slightly different heights, so overlapping ones don't flicker
local LAYER_STEP = 0.012 -- the highest one is still well under the path

local Ground = {}

local folder: Folder
local random = Random.new(23) -- the same patches every time
local made = 0 -- patches made so far (for their height layer)

local function addPatch(x: number, z: number, color: Color3, material: Enum.Material)
	local cfg = Config.Ground
	made += 1
	local size = random:NextNumber(cfg.PatchSize[1], cfg.PatchSize[2])
	local stretch = random:NextNumber(0.6, 1)
	local top = FLOOR_TOP + 0.01 + (made % LAYERS) * LAYER_STEP
	local name = Assets.pick(Config.Models.Patches, random)
	local part = if name then Assets.part(name) else nil
	if part then
		part.Name = "Patch"
		part.Size = Vector3.new(size, THICKNESS, size * stretch)
		part.CFrame = CFrame.new(x, top - THICKNESS / 2, z) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.Parent = folder
	else
		for _, piece in Blocky.patch("Patch", Vector3.new(x, 0, z), size / 2, top, color, material, folder) do
			piece.CastShadow = false
		end
	end
end

-- `amount` patches spread over `bounds`, each in one of `colors`.
local function scatter(bounds: Zones.Bounds, amount: number, colors: { Color3 }, material: Enum.Material)
	local margin = 6
	for _ = 1, amount do
		addPatch(
			random:NextNumber(bounds.MinX + margin, bounds.MaxX - margin),
			random:NextNumber(bounds.MinZ + margin, bounds.MaxZ - margin),
			colors[random:NextInteger(1, #colors)],
			material
		)
	end
end

-- Builds every patch into a "Ground" folder in `parent`.
function Ground.build(parent: Instance)
	local cfg = Config.Ground
	folder = Instance.new("Folder")
	folder.Name = "Ground"

	scatter(Zones.getCampBounds(), cfg.CampPatches, cfg.CampColors, Enum.Material.Grass)
	for index, zone in Config.Zones do
		scatter(Zones.getBounds(index), cfg.ZonePatches[index] or 0, cfg.ZoneColors[index] or { zone.GroundColor }, zone.GroundMaterial)
	end

	-- Where two zones meet: patches in the next zone's floor colour on this side of the border,
	-- and in this zone's floor colour on the other side.
	for index = 1, Zones.count() - 1 do
		local border = Zones.getBounds(index).MinZ -- this zone is on the +Z side of it
		local bounds = Zones.getBounds(index)
		local thisZone, nextZone = Config.Zones[index], Config.Zones[index + 1]
		for _ = 1, cfg.BlendPatches do
			local x = random:NextNumber(bounds.MinX + 6, bounds.MaxX - 6)
			addPatch(x, border + random:NextNumber(3, cfg.BlendDepth), nextZone.GroundColor, nextZone.GroundMaterial)
			x = random:NextNumber(bounds.MinX + 6, bounds.MaxX - 6)
			addPatch(x, border - random:NextNumber(3, cfg.BlendDepth), thisZone.GroundColor, thisZone.GroundMaterial)
		end
	end

	folder.Parent = parent
end

return Ground
