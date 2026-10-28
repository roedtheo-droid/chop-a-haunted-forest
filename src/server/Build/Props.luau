--!strict
-- Small props made of blocky parts (see STYLE_GUIDE.md): rocks, mushrooms, berry bushes,
-- fallen logs, campfires, lamp posts, fences, pumpkins, gravestones, reeds and lily pads.
-- Every prop stands on flat ground: `base` is a spot on the ground (its Y is ignored).
-- Rocks use the Blender rock models once they're imported into Studio (see Build/Assets).
-- Used by CampProps, Landmarks and LandmarkManager. Only for looks: nothing can be chopped.
-- It's not a system, so it has no init()/start().

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Assets = require(script.Parent.Assets)
local Blocky = require(script.Parent.Blocky)

local GROUND = 0.05 -- the top of the camp's grass and the zone floors

local STONE = Color3.fromRGB(143, 150, 163)
local MOSS = Color3.fromRGB(95, 150, 60)
local FIRE_COLOR = Color3.fromRGB(255, 138, 60)
local CREAM = Color3.fromRGB(240, 228, 205)
local MUSHROOM_RED = Color3.fromRGB(215, 55, 45)
local GLOW_GREEN = Color3.fromRGB(140, 255, 120)
local LEAF = Color3.fromRGB(70, 140, 55)
local BERRY = Color3.fromRGB(205, 40, 55)
local PUMPKIN = Color3.fromRGB(240, 130, 30)
local PUMPKIN_GLOW = Color3.fromRGB(255, 200, 80)
local GRAVE_STONE = Color3.fromRGB(125, 125, 138)
local DIRT = Color3.fromRGB(85, 62, 45)
local DARK_METAL = Color3.fromRGB(45, 45, 52)
local REED = Color3.fromRGB(120, 140, 70)
local CATTAIL = Color3.fromRGB(110, 70, 40)
local LILY = Color3.fromRGB(80, 160, 70)
local LILY_FLOWER = Color3.fromRGB(240, 150, 200)
local YELLOW = Color3.fromRGB(255, 215, 70)

local Props = {}

-- A part that players bump into.
local function piece(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return Blocky.part(name, size, cframe, color, material, parent)
end

-- Like piece(), but players walk through it.
local function decor(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = piece(parent, name, size, cframe, color, material)
	part.CanCollide = false
	return part
end

-- A spot `height` studs above the ground at `base`.
local function above(base: Vector3, height: number): CFrame
	return CFrame.new(base.X, GROUND + height, base.Z)
end

-- On the ground at `base`, with its front (-Z) facing `direction`.
local function facing(base: Vector3, direction: Vector3): CFrame
	local spot = Vector3.new(base.X, GROUND, base.Z)
	return CFrame.lookAt(spot, spot + Vector3.new(direction.X, 0, direction.Z))
end

local function addLight(part: BasePart, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = part
	return light
end

-- A rock from one of the Blender rock models (Config.Models.Rocks), or nil if none is
-- imported yet. Returns the stone part.
local function meshRock(parent: Instance, base: Vector3, size: number, mossy: boolean, random: Random, stone: Color3): BasePart?
	local names: { string } = {}
	for _, name in Config.Models.Rocks do
		if Assets.has(name) then
			table.insert(names, name)
		end
	end
	if #names == 0 then
		return nil
	end
	local model = Assets.model(names[random:NextInteger(1, #names)])
	if not model then
		return nil
	end
	local rock = model:FindFirstChild("Rock")
	if not (rock and rock:IsA("BasePart")) then
		model:Destroy()
		return nil
	end
	-- The model includes a smaller stone beside the big one, so it's a bit wider than `size`.
	-- It sinks a little into the ground, so it doesn't look like it's balancing on a corner.
	local spot = Vector3.new(base.X, GROUND - size * 0.1, base.Z)
	Assets.fit(model, rock, size * 1.3, spot, CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
	rock.Color = Blocky.shade(stone, random:NextNumber(-0.08, 0.05))
	rock.Material = Enum.Material.Slate
	local moss = model:FindFirstChild("Moss")
	if moss and moss:IsA("BasePart") then
		if mossy then
			moss.Color = MOSS
			moss.Material = Enum.Material.Grass
			moss.CanCollide = false
		else
			moss:Destroy()
		end
	end
	for _, part in model:GetChildren() do
		part.Parent = parent
	end
	model:Destroy()
	return rock
end

-- A grey rock with a smaller one leaning on it, and maybe moss on top. Returns the big one.
function Props.rock(parent: Instance, base: Vector3, size: number, mossy: boolean, random: Random, color: Color3?): BasePart
	local stone = color or STONE
	local fromModel = meshRock(parent, base, size, mossy, random, stone)
	if fromModel then
		return fromModel
	end
	local turn = CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
	local main = piece(
		parent,
		"Rock",
		Vector3.new(size, size * 0.7, size * 0.85),
		above(base, size * 0.3) * turn * CFrame.Angles(random:NextNumber(-0.15, 0.15), 0, random:NextNumber(-0.15, 0.15)),
		Blocky.shade(stone, random:NextNumber(-0.08, 0.05)),
		Enum.Material.Slate
	)
	local small = size * 0.5
	decor(
		parent,
		"Rock",
		Vector3.new(small, small * 0.8, small),
		above(base, small * 0.35) * turn * CFrame.new(size * 0.55, 0, size * 0.2) * CFrame.Angles(0, 0.6, 0.2),
		Blocky.shade(stone, -0.1),
		Enum.Material.Slate
	)
	if mossy then
		decor(parent, "Moss", Vector3.new(size * 0.85, 0.2, size * 0.7), main.CFrame * CFrame.new(0, size * 0.35 + 0.05, 0), MOSS, Enum.Material.Grass)
	end
	return main
end

-- One mushroom standing on `bottom`. Red with white dots, or glowing green. Returns its cap.
function Props.mushroom(parent: Instance, bottom: CFrame, scale: number, glow: boolean): Part
	local stemHeight = 0.7 * scale
	decor(parent, "MushroomStem", Vector3.new(0.35 * scale, stemHeight, 0.35 * scale), bottom * CFrame.new(0, stemHeight / 2, 0), CREAM, Enum.Material.SmoothPlastic)
	local cap = decor(
		parent,
		"MushroomCap",
		Vector3.new(1, 0.45, 1) * scale,
		bottom * CFrame.new(0, stemHeight + 0.2 * scale, 0),
		if glow then GLOW_GREEN else MUSHROOM_RED,
		if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	)
	if not glow then
		for _, spot in { Vector3.new(0.25, 0.23, 0.2), Vector3.new(-0.2, 0.23, -0.25) } do
			decor(parent, "MushroomDot", Vector3.new(0.22, 0.05, 0.22) * scale, cap.CFrame * CFrame.new(spot * scale), CREAM, Enum.Material.SmoothPlastic)
		end
	end
	return cap
end

-- A few mushrooms together around `bottom`. Glowing ones give off a faint green light.
function Props.mushrooms(parent: Instance, bottom: CFrame, glow: boolean, random: Random)
	local caps: { Part } = {}
	for index = 1, 3 do
		local angle = index * 2.1 + random:NextNumber(0, 0.6)
		local spot = bottom * CFrame.new(math.cos(angle) * 0.6, 0, math.sin(angle) * 0.6)
		table.insert(caps, Props.mushroom(parent, spot, random:NextNumber(0.7, 1.2), glow))
	end
	if glow then
		addLight(caps[1], GLOW_GREEN, 9, 0.8)
	end
end

-- A round green bush with red berries.
function Props.berryBush(parent: Instance, base: Vector3, random: Random)
	local turn = above(base, 0) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
	local blocks = {
		decor(parent, "Bush", Vector3.new(2.6, 2, 2.4), turn * CFrame.new(0, 1, 0), Blocky.shade(LEAF, random:NextNumber(-0.05, 0.05)), Enum.Material.Grass),
		decor(parent, "Bush", Vector3.new(1.8, 1.6, 1.8), turn * CFrame.new(1.2, 0.8, 0.5), Blocky.shade(LEAF, 0.1), Enum.Material.Grass),
		decor(parent, "Bush", Vector3.new(1.6, 1.4, 1.6), turn * CFrame.new(-1.1, 0.7, -0.4), Blocky.shade(LEAF, -0.08), Enum.Material.Grass),
	}
	for _ = 1, 7 do
		local block = blocks[random:NextInteger(1, #blocks)]
		local half = block.Size / 2
		-- On the top or one of the sides of a block, sticking out a little.
		local spot = Vector3.new(random:NextNumber(-half.X, half.X) * 0.8, half.Y, random:NextNumber(-half.Z, half.Z) * 0.8)
		if random:NextNumber() < 0.5 then
			spot = Vector3.new(half.X * (if random:NextNumber() < 0.5 then 1 else -1), random:NextNumber(-half.Y, half.Y) * 0.6, spot.Z)
		end
		decor(parent, "Berry", Vector3.new(0.4, 0.4, 0.4), block.CFrame * CFrame.new(spot), BERRY, Enum.Material.SmoothPlastic)
	end
end

-- An old tree trunk lying on the ground (turned by `angle` around Y), with moss on it.
-- A birch one is white with dark marks.
function Props.fallenLog(parent: Instance, base: Vector3, angle: number, birch: boolean, random: Random)
	local bark = if birch then (Config.TreeTypes.Birch.BirchColor or CREAM) else Config.Style.Wood
	local length = random:NextNumber(6, 9)
	local log = piece(parent, "FallenLog", Vector3.new(1.8, 1.8, length), above(base, 0.85) * CFrame.Angles(0, angle, 0), bark, Enum.Material.Wood)
	Blocky.rings(log, Enum.NormalId.Front)
	Blocky.rings(log, Enum.NormalId.Back)
	if birch then
		for _ = 1, 6 do
			local z = random:NextNumber(-length / 2 + 0.5, length / 2 - 0.5)
			local side = random:NextInteger(1, 3)
			local spot = if side == 1
				then CFrame.new(random:NextNumber(-0.4, 0.4), 0.92, z)
				else CFrame.new((if side == 2 then 1 else -1) * 0.92, random:NextNumber(-0.4, 0.4), z)
			local size = if side == 1 then Vector3.new(0.7, 0.05, 0.18) else Vector3.new(0.05, 0.7, 0.18)
			decor(parent, "BirchMark", size, log.CFrame * spot, Config.Style.BirchMark, Enum.Material.SmoothPlastic)
		end
	end
	decor(parent, "Moss", Vector3.new(1.4, 0.2, length * 0.4), log.CFrame * CFrame.new(0, 0.95, random:NextNumber(-1, 1)), MOSS, Enum.Material.Grass)
end

-- A campfire in a ring of stones, with logs leaning together over the fire. With `seats`,
-- three logs lie around it to sit on.
function Props.campfire(parent: Instance, base: Vector3, seats: boolean)
	local center = Vector3.new(base.X, GROUND, base.Z)
	for index = 1, 8 do
		local angle = index * math.pi / 4
		piece(
			parent,
			"FireStone",
			Vector3.new(1.3, 0.9, 1.3),
			CFrame.new(center + Vector3.new(math.cos(angle) * 2.4, 0.45, math.sin(angle) * 2.4)) * CFrame.Angles(0, angle, 0),
			Blocky.shade(STONE, (index % 2) * 0.1),
			Enum.Material.Slate
		)
	end
	for index = 1, 3 do
		local log = decor(
			parent,
			"FireLog",
			Vector3.new(0.7, 0.7, 3),
			CFrame.new(center + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, index * 2 * math.pi / 3, 0) * CFrame.new(0, 0, 0.8) * CFrame.Angles(math.rad(35), 0, 0),
			Config.Style.Wood,
			Enum.Material.Wood
		)
		Blocky.rings(log, Enum.NormalId.Back)
	end
	local flame = decor(parent, "Flame", Vector3.new(1.2, 1.4, 1.2), CFrame.new(center + Vector3.new(0, 0.9, 0)), FIRE_COLOR, Enum.Material.Neon)
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Parent = flame
	addLight(flame, FIRE_COLOR, 20, 1.5)

	if seats then
		for index = 1, 3 do
			local angle = index * 2 * math.pi / 3 + math.pi / 6
			local spot = center + Vector3.new(math.cos(angle) * 6.5, 0.8, math.sin(angle) * 6.5)
			local seat = piece(parent, "SeatLog", Vector3.new(5, 1.6, 1.6), CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z)), Config.Style.Wood, Enum.Material.Wood)
			Blocky.rings(seat, Enum.NormalId.Left)
			Blocky.rings(seat, Enum.NormalId.Right)
		end
	end
end

-- A lamp post with its lantern hanging towards `direction`. A crooked one leans a little.
-- Returns the lantern's light.
function Props.lampPost(parent: Instance, base: Vector3, direction: Vector3, color: Color3, crooked: boolean, random: Random): PointLight
	local lean = if crooked then CFrame.Angles(random:NextNumber(-0.15, 0.15), 0, random:NextNumber(-0.15, 0.15)) else CFrame.identity
	local frame = facing(base, direction) * lean
	local wood = if crooked then Blocky.shade(Config.Style.DarkWood, -0.35) else Config.Style.DarkWood
	piece(parent, "LampPost", Vector3.new(0.6, 9, 0.6), frame * CFrame.new(0, 4.5, 0), wood, Enum.Material.Wood)
	decor(parent, "LampArm", Vector3.new(0.4, 0.4, 2.2), frame * CFrame.new(0, 8.6, -0.9), wood, Enum.Material.Wood)
	decor(parent, "LampCap", Vector3.new(1.2, 0.3, 1.2), frame * CFrame.new(0, 8.1, -1.8), DARK_METAL, Enum.Material.Metal)
	local lantern = decor(parent, "Lantern", Vector3.new(0.9, 1.1, 0.9), frame * CFrame.new(0, 7.4, -1.8), color, Enum.Material.Neon)
	return addLight(lantern, color, 18, 1)
end

-- A wooden fence from `from` to `to`. A broken one has leaning posts and missing rails.
function Props.fence(parent: Instance, from: Vector3, to: Vector3, broken: boolean, random: Random)
	local color = Blocky.shade(Config.Scenery.FenceColor, -0.1)
	local frame = facing(from, to - from)
	local length = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Magnitude
	local spacing = 3
	local posts = math.max(1, math.floor(length / spacing))
	for index = 0, posts do
		local lean = if broken then CFrame.Angles(random:NextNumber(-0.3, 0.3), 0, random:NextNumber(-0.25, 0.25)) else CFrame.identity
		local height = if broken and random:NextNumber() < 0.3 then 1.8 else 3
		decor(parent, "FencePost", Vector3.new(0.5, height, 0.5), frame * CFrame.new(0, 0, -index * spacing) * lean * CFrame.new(0, height / 2, 0), color, Enum.Material.Wood)
		if index < posts then
			for _, y in { 1.1, 2.2 } do
				if not broken or random:NextNumber() > 0.35 then
					local tilt = if broken then CFrame.Angles(random:NextNumber(-0.2, 0.2), 0, random:NextNumber(-0.25, 0.25)) else CFrame.identity
					decor(
						parent,
						"FenceRail",
						Vector3.new(0.25, 0.4, spacing + 0.3),
						frame * CFrame.new(0, y, -(index + 0.5) * spacing) * tilt,
						Blocky.shade(color, 0.1),
						Enum.Material.WoodPlanks
					)
				end
			end
		end
	end
end

-- A pumpkin facing `direction`. A lit one has a glowing face.
function Props.pumpkin(parent: Instance, base: Vector3, direction: Vector3, lit: boolean, random: Random)
	local scale = random:NextNumber(0.8, 1.3)
	local frame = facing(base, direction) * CFrame.Angles(0, random:NextNumber(-0.4, 0.4), 0)
	local body = piece(parent, "Pumpkin", Vector3.new(2.2, 1.7, 2.2) * scale, frame * CFrame.new(0, 0.85 * scale, 0), PUMPKIN, Enum.Material.SmoothPlastic)
	local rib = Blocky.shade(PUMPKIN, -0.15)
	decor(parent, "PumpkinRib", Vector3.new(2.3, 1.5, 0.4) * scale, body.CFrame, rib, Enum.Material.SmoothPlastic)
	decor(parent, "PumpkinRib", Vector3.new(0.4, 1.5, 2.3) * scale, body.CFrame, rib, Enum.Material.SmoothPlastic)
	decor(parent, "PumpkinStem", Vector3.new(0.35, 0.6, 0.35) * scale, body.CFrame * CFrame.new(0, 1.05 * scale, 0), Color3.fromRGB(90, 110, 50), Enum.Material.Wood)
	if lit then
		-- The face goes on the front rib, which sticks out past the body.
		local front = decor(parent, "PumpkinFace", Vector3.new(1.6, 1.2, 0.05) * scale, body.CFrame * CFrame.new(0, 0, -1.16 * scale), PUMPKIN, Enum.Material.SmoothPlastic)
		front.Transparency = 1
		local gui = Blocky.face(front, Enum.NormalId.Front)
		gui.LightInfluence = 0 -- it glows: the sun doesn't darken it
		local function hole(x: number, y: number, w: number, h: number, rotation: number)
			local frameUi = Instance.new("Frame")
			frameUi.AnchorPoint = Vector2.new(0.5, 0.5)
			frameUi.Position = UDim2.fromScale(x, y)
			frameUi.Size = UDim2.fromScale(w, h)
			frameUi.Rotation = rotation
			frameUi.BorderSizePixel = 0
			frameUi.BackgroundColor3 = PUMPKIN_GLOW
			frameUi.Parent = gui
		end
		hole(0.27, 0.3, 0.2, 0.26, 45)
		hole(0.73, 0.3, 0.2, 0.26, 45)
		hole(0.5, 0.72, 0.6, 0.18, 0)
		addLight(front, PUMPKIN_GLOW, 10, 0.8)
	end
end

-- A gravestone facing `direction`, with a mound of earth in front. Three kinds:
-- 1 a slab with a round top, 2 a cross, 3 a short pillar.
function Props.gravestone(parent: Instance, base: Vector3, direction: Vector3, kind: number, random: Random)
	local frame = facing(base, direction)
	local lean = CFrame.Angles(random:NextNumber(-0.12, 0.12), 0, random:NextNumber(-0.12, 0.12))
	local stone = Blocky.shade(GRAVE_STONE, random:NextNumber(-0.1, 0.05))
	piece(parent, "GraveBase", Vector3.new(2.6, 0.4, 1.2), frame * CFrame.new(0, 0.2, 0), Blocky.shade(stone, -0.1), Enum.Material.Slate)
	local top = frame * CFrame.new(0, 0.4, 0) * lean
	if kind == 1 then
		piece(parent, "Gravestone", Vector3.new(2, 2.4, 0.6), top * CFrame.new(0, 1.2, 0), stone, Enum.Material.Slate)
		local round = decor(parent, "Gravestone", Vector3.new(0.6, 2, 2), top * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, math.pi / 2, 0), stone, Enum.Material.Slate)
		round.Shape = Enum.PartType.Cylinder -- its round sides face front and back
	elseif kind == 2 then
		piece(parent, "Gravestone", Vector3.new(0.6, 3.6, 0.6), top * CFrame.new(0, 1.8, 0), stone, Enum.Material.Slate)
		decor(parent, "Gravestone", Vector3.new(2.2, 0.6, 0.6), top * CFrame.new(0, 2.6, 0), stone, Enum.Material.Slate)
	else
		piece(parent, "Gravestone", Vector3.new(1.1, 3.4, 1.1), top * CFrame.new(0, 1.7, 0), stone, Enum.Material.Slate)
		decor(parent, "Gravestone", Vector3.new(1.4, 0.4, 1.4), top * CFrame.new(0, 3.5, 0), Blocky.shade(stone, 0.08), Enum.Material.Slate)
	end
	if random:NextNumber() < 0.4 then
		decor(parent, "Moss", Vector3.new(1.2, 0.15, 0.7), top * CFrame.new(random:NextNumber(-0.4, 0.4), 0.1, 0), MOSS, Enum.Material.Grass)
	end
	decor(parent, "GraveMound", Vector3.new(2, 0.4, 3.6), frame * CFrame.new(0, 0.2, -2.4), DIRT, Enum.Material.Ground)
end

-- A clump of reeds, some with brown cattails on top.
function Props.reeds(parent: Instance, base: Vector3, random: Random)
	for index = 1, 6 do
		local height = random:NextNumber(2.5, 4)
		local spot = Vector3.new(base.X + random:NextNumber(-1.2, 1.2), 0, base.Z + random:NextNumber(-1.2, 1.2))
		local stalk = decor(
			parent,
			"Reed",
			Vector3.new(0.18, height, 0.18),
			above(spot, height / 2) * CFrame.Angles(random:NextNumber(-0.12, 0.12), 0, random:NextNumber(-0.12, 0.12)),
			Blocky.shade(REED, random:NextNumber(-0.1, 0.1)),
			Enum.Material.Grass
		)
		if index % 2 == 0 then
			decor(parent, "Cattail", Vector3.new(0.35, 0.8, 0.35), stalk.CFrame * CFrame.new(0, height / 2 - 0.5, 0), CATTAIL, Enum.Material.Fabric)
		end
	end
end

-- A lily pad floating on water whose top is `waterTop` studs above the ground.
-- Sometimes with a pink flower on it.
function Props.lilyPad(parent: Instance, base: Vector3, waterTop: number, flower: boolean, random: Random)
	local pad = decor(
		parent,
		"LilyPad",
		Vector3.new(0.08, 1.8, 1.8) * random:NextNumber(0.8, 1.2),
		above(base, waterTop + 0.03) * CFrame.Angles(0, 0, math.pi / 2), -- a cylinder lying flat
		LILY,
		Enum.Material.SmoothPlastic
	)
	pad.CanQuery = false
	if flower then
		decor(parent, "LilyFlower", Vector3.new(0.6, 0.4, 0.6), above(base, waterTop + 0.25), LILY_FLOWER, Enum.Material.SmoothPlastic)
		decor(parent, "LilyFlower", Vector3.new(0.25, 0.2, 0.25), above(base, waterTop + 0.5), YELLOW, Enum.Material.SmoothPlastic)
	end
end

-- A flower on a stem, for meadows and flower beds.
function Props.flower(parent: Instance, base: Vector3, color: Color3, random: Random)
	local height = random:NextNumber(0.7, 1.2)
	decor(parent, "Stem", Vector3.new(0.2, height, 0.2), above(base, height / 2), Color3.fromRGB(60, 140, 50), Enum.Material.SmoothPlastic)
	decor(parent, "Bloom", Vector3.new(0.6, 0.6, 0.6), above(base, height + 0.2) * CFrame.Angles(0, random:NextNumber(0, 1), 0), color, Enum.Material.SmoothPlastic)
end

-- Tag a light so every player's computer makes it flicker a little (see AmbientController).
function Props.flicker(light: PointLight)
	CollectionService:AddTag(light, Tags.Flicker)
end

return Props
