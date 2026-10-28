--!strict
-- Builds the big things in each zone (see the map design and Config.Landmarks):
--   Zone 1  a lake with a sandy beach, a dock and a rowboat; a lumberjack camp; a flower meadow
--   Zone 2  two swamps with reeds and lily pads; an old windmill ruin with broken sails
--   Zone 3  a graveyard behind an iron fence; a stone crypt glowing orange inside;
--           a ring of tall stones and glowing roots around the boss
-- The tents, dock, rowboat, windmill, graveyard fence, crypt and ring stones are Blender
-- models once they're imported into Studio (Config.Models.Landmarks); until then, parts.
-- Everything is only for looks. LandmarkManager calls Landmarks.build.
-- It's not a system, so it has no init()/start().

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Assets = require(script.Parent.Assets)
local Blocky = require(script.Parent.Blocky)
local Props = require(script.Parent.Props)

local GROUND = 0.05 -- the top of the zone floors (see ZoneManager)
local WATER_TOP = 0.3 -- the same height as the river: you wade through it

local DARK_STONE = Color3.fromRGB(88, 84, 98)
local SAND = Color3.fromRGB(235, 215, 160)
local LAKE = Color3.fromRGB(90, 169, 230)
local MUD = Color3.fromRGB(85, 72, 50)
local SWAMP_WATER = Color3.fromRGB(72, 98, 70)
local MEADOW_GRASS = Color3.fromRGB(130, 200, 85)
local DIRT = Color3.fromRGB(95, 72, 52)
local IRON = Color3.fromRGB(40, 40, 46)
local TENT_COLORS = { Color3.fromRGB(225, 200, 140), Color3.fromRGB(95, 135, 85) }
local FLOWERS = { Color3.fromRGB(216, 90, 70), Color3.fromRGB(232, 141, 184), Color3.fromRGB(255, 215, 70), Color3.fromRGB(150, 120, 230), Color3.fromRGB(250, 250, 250) }
local GLOW_ORANGE = Color3.fromRGB(255, 130, 45)
local ROOT_GLOW = Color3.fromRGB(255, 80, 40)
local LAMP_ORANGE = Color3.fromRGB(255, 150, 60)

local MODELS = Config.Models.Landmarks

local Landmarks = {}

local folder: Instance
local random: Random

local function piece(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return Blocky.part(name, size, cframe, color, material, folder)
end

local function decor(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = piece(name, size, cframe, color, material)
	part.CanCollide = false
	return part
end

-- A spot on the ground, `height` studs up.
local function at(position: Vector3, height: number): CFrame
	return CFrame.new(position.X, GROUND + height, position.Z)
end

-- A random spot inside a circle on the ground.
local function spotInCircle(center: Vector3, radius: number): Vector3
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(random:NextNumber()) * radius -- the square root spreads them evenly
	return center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

-- A spot on the edge of a circle, at a random angle.
local function spotOnCircle(center: Vector3, radius: number): Vector3
	local angle = random:NextNumber(0, math.pi * 2)
	return center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

-- A roundish flat patch, `top` studs above the ground (see Blocky.patch).
local function patch(name: string, center: Vector3, radius: number, top: number, color: Color3, material: Enum.Material): { Part }
	return Blocky.patch(name, center, radius, GROUND + top, color, material, folder)
end

-- Water in a roundish pool, with a ring of sand or mud around it.
local function pool(center: Vector3, radius: number, water: Color3, edge: Color3, edgeMaterial: Enum.Material)
	patch("Shore", center, radius + 4, 0.15, edge, edgeMaterial)
	for _, part in patch("Water", center, radius, WATER_TOP, water, Enum.Material.SmoothPlastic) do
		part.Transparency = 0.15
		part.Reflectance = 0.1
	end
end

-- A small rowboat lying along X, floating on the water.
local function buildRowboat(center: Vector3)
	local hull = Blocky.shade(Config.Style.Wood, 0.05)
	local trim = Color3.fromRGB(200, 70, 50)
	local frame = at(center, WATER_TOP) * CFrame.Angles(0, random:NextNumber(-0.2, 0.2), 0)
	local boat = Assets.prop(folder, MODELS.Rowboat, 1, frame * CFrame.new(0, -0.15, 0))
	if boat then
		Assets.paint(boat, "Hull", hull, Enum.Material.WoodPlanks, false)
		Assets.paint(boat, "Trim", trim, Enum.Material.SmoothPlastic, false)
		Assets.paint(boat, "Seat", Blocky.shade(hull, 0.1), Enum.Material.Wood, false)
		Assets.paint(boat, "Oar", Config.Style.InnerWood, Enum.Material.Wood, false)
		return
	end
	decor("BoatFloor", Vector3.new(6, 0.3, 2.6), frame, hull, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		decor("BoatSide", Vector3.new(5.4, 1, 0.3), frame * CFrame.new(-0.3, 0.5, side * 1.3), hull, Enum.Material.WoodPlanks)
		decor("BoatTrim", Vector3.new(5.4, 0.2, 0.4), frame * CFrame.new(-0.3, 1.05, side * 1.3), trim, Enum.Material.SmoothPlastic)
		-- The front narrows to a point.
		decor("BoatBow", Vector3.new(1.9, 1, 0.3), frame * CFrame.new(3.1, 0.5, side * 0.75) * CFrame.Angles(0, side * math.rad(35), 0), hull, Enum.Material.WoodPlanks)
	end
	decor("BoatBack", Vector3.new(0.3, 1, 2.6), frame * CFrame.new(-3, 0.5, 0), hull, Enum.Material.WoodPlanks)
	for _, x in { -1.2, 1 } do
		decor("BoatSeat", Vector3.new(0.6, 0.2, 2.4), frame * CFrame.new(x, 0.75, 0), Blocky.shade(hull, 0.1), Enum.Material.Wood)
	end
	for _, side in { -1, 1 } do
		decor("Oar", Vector3.new(4, 0.2, 0.3), frame * CFrame.new(0, 1, side * 0.6) * CFrame.Angles(0, side * 0.15, 0), Config.Style.InnerWood, Enum.Material.Wood)
	end
end

-- Zone 1: a lake with a sandy beach, a dock you can walk out on and a rowboat.
local function buildLake()
	local landmark = Config.Landmarks.Lake
	local center = landmark.Position
	local radius = landmark.ClearRadius - 14
	pool(center, radius, LAKE, SAND, Enum.Material.Sand)

	-- The dock starts on the beach on the side towards the path (+X) and goes out over the water.
	local deckTop = 1
	local fromX, toX = center.X + radius + 3, center.X + radius - 13
	local length = fromX - toX
	local middleX = (fromX + toX) / 2
	local deck = piece("Dock", Vector3.new(length, 0.4, 4), at(Vector3.new(middleX, 0, center.Z), deckTop - 0.2), Config.Style.Wood, Enum.Material.WoodPlanks)
	local step = piece("DockStep", Vector3.new(1.4, 0.5, 4), at(Vector3.new(fromX + 0.7, 0, center.Z), 0.25), Config.Style.Wood, Enum.Material.WoodPlanks)
	local dockModel = Assets.prop(folder, MODELS.Dock, 1, at(Vector3.new(middleX, 0, center.Z), deckTop - 0.4))
	if dockModel then
		Assets.paint(dockModel, "Deck", Config.Style.Wood, Enum.Material.WoodPlanks, false)
		Assets.paint(dockModel, "Step", Config.Style.Wood, Enum.Material.WoodPlanks, false)
		Assets.paint(dockModel, "Post", Config.Style.DarkWood, Enum.Material.Wood, false)
		-- You still walk on the plain deck and step: they're the exact shape, so they stay as
		-- invisible floors under the model.
		Blocky.collider(deck)
		Blocky.collider(step)
	else
		for offset = 0, length, 4 do
			for _, side in { -1, 1 } do
				decor("DockPost", Vector3.new(0.6, 1.8, 0.6), at(Vector3.new(fromX - offset, 0, center.Z + side * 2), 0.6), Config.Style.DarkWood, Enum.Material.Wood)
			end
		end
		for _, side in { -1, 1 } do
			decor("Bollard", Vector3.new(0.6, 1, 0.6), at(Vector3.new(toX + 0.5, 0, center.Z + side * 1.6), deckTop + 0.5), Config.Style.DarkWood, Enum.Material.Wood)
		end
	end
	buildRowboat(Vector3.new(toX + 3, 0, center.Z + 4.2))

	-- Rocks on the beach and lily pads on the water.
	for _ = 1, 4 do
		Props.rock(folder, spotOnCircle(center, radius + 2.5), random:NextNumber(1.6, 2.6), true, random)
	end
	for _ = 1, 5 do
		Props.lilyPad(folder, spotInCircle(center - Vector3.new(6, 0, 0), radius * 0.6), WATER_TOP, false, random)
	end
end

-- A canvas tent with its door facing -X.
local function buildTent(center: Vector3, color: Color3)
	local tent = Assets.prop(folder, MODELS.Tent, 1, at(center, 0))
	if tent then
		Assets.paint(tent, "Canvas", color, Enum.Material.Fabric, true)
		Assets.paint(tent, "Door", Color3.fromRGB(45, 35, 30), Enum.Material.Fabric, false)
		Assets.paint(tent, "Wood", Config.Style.DarkWood, Enum.Material.Wood, false)
		Assets.paint(tent, "Rope", Color3.fromRGB(205, 175, 120), Enum.Material.Fabric, false)
		return
	end
	local width, height, length = 6, 4, 7
	local slant = math.sqrt((width / 2) ^ 2 + height ^ 2)
	local angle = math.atan2(width / 2, height)
	local frame = at(center, 0)
	for _, side in { -1, 1 } do
		-- Each side leans in, so the two meet in a ridge along the top.
		piece(
			"Tent",
			Vector3.new(length, slant, 0.3),
			frame * CFrame.new(0, height / 2, side * width / 4) * CFrame.Angles(-side * angle, 0, 0),
			Blocky.shade(color, if side == 1 then 0 else -0.08),
			Enum.Material.Fabric
		)
	end
	piece("TentBack", Vector3.new(0.3, height * 0.7, width * 0.45), frame * CFrame.new(length / 2 - 0.2, height * 0.35, 0), Blocky.shade(color, -0.12), Enum.Material.Fabric)
	decor("TentDoor", Vector3.new(0.1, 2.6, 1.6), frame * CFrame.new(-length / 2 + 0.6, 1.3, 0), Color3.fromRGB(45, 35, 30), Enum.Material.Fabric)
	decor("TentRidge", Vector3.new(length + 0.8, 0.25, 0.25), frame * CFrame.new(0, height + 0.05, 0), Config.Style.DarkWood, Enum.Material.Wood)
	for _, x in { -1, 1 } do
		decor("TentPole", Vector3.new(0.25, height + 0.6, 0.25), frame * CFrame.new(x * (length / 2 + 0.3), (height + 0.6) / 2, 0), Config.Style.DarkWood, Enum.Material.Wood)
	end
end

-- Zone 1: a lumberjack camp with two tents, a campfire, a stump with an axe and a wood pile.
local function buildTentCamp()
	local center = Config.Landmarks.TentCamp.Position
	Props.campfire(folder, center, true)
	buildTent(center + Vector3.new(12, 0, -6), TENT_COLORS[1])
	buildTent(center + Vector3.new(12, 0, 7), TENT_COLORS[2])

	local stump = center + Vector3.new(-7, 0, -8)
	local block = piece("Stump", Vector3.new(2.2, 1.2, 2.2), at(stump, 0.6), Config.Style.Wood, Enum.Material.Wood)
	Blocky.rings(block, Enum.NormalId.Top)
	local handle = decor("AxeHandle", Vector3.new(0.3, 2.6, 0.3), at(stump, 2.3) * CFrame.new(0.2, 0, 0) * CFrame.Angles(0, 0, math.rad(-20)), Config.Style.InnerWood, Enum.Material.Wood)
	decor("AxeHead", Vector3.new(0.3, 1, 1.2), handle.CFrame * CFrame.new(0, -1.1, 0), Config.Style.Metal, Enum.Material.Metal)

	-- A pile of chopped logs, ends facing the fire.
	for row, count in { 3, 2 } do
		for index = 1, count do
			local x = (index - (count + 1) / 2) * 1.5
			local log = decor("PileLog", Vector3.new(1.4, 1.4, 4), at(center + Vector3.new(-2 + x, 0, 11), 0.7 + (row - 1) * 1.25), Config.Style.Wood, Enum.Material.Wood)
			Blocky.rings(log, Enum.NormalId.Front)
		end
	end
	piece("Crate", Vector3.new(2.2, 2.2, 2.2), at(center + Vector3.new(6, 0, 11), 1.1), Color3.fromRGB(200, 145, 90), Enum.Material.WoodPlanks)
end

-- Zone 1: a bright patch of grass full of flowers.
local function buildMeadow()
	local landmark = Config.Landmarks.Meadow
	local center = landmark.Position
	local radius = landmark.ClearRadius - 4
	patch("Meadow", center, radius, 0.1, MEADOW_GRASS, Enum.Material.Grass)
	for _ = 1, 70 do
		Props.flower(folder, spotInCircle(center, radius * 0.85), FLOWERS[random:NextInteger(1, #FLOWERS)], random)
	end
	for _ = 1, 3 do
		Props.rock(folder, spotInCircle(center, radius * 0.8), random:NextNumber(1.6, 2.4), true, random)
	end
	Props.fallenLog(folder, center + Vector3.new(4, 0, 6), 1.2, true, random)
end

-- Zone 2: murky water ringed with mud, reeds, lily pads (one with a pink flower), a dead
-- stump and a mossy rock with glowing mushrooms.
local function buildSwamp(landmark: { Position: Vector3, ClearRadius: number })
	local center = landmark.Position
	local radius = landmark.ClearRadius - 7
	pool(center, radius, SWAMP_WATER, MUD, Enum.Material.Mud)
	for _ = 1, 8 do
		Props.reeds(folder, spotOnCircle(center, radius + random:NextNumber(-1, 1.5)), random)
	end
	for index = 1, 7 do
		Props.lilyPad(folder, spotInCircle(center, radius * 0.7), WATER_TOP, index == 1, random)
	end
	local stump = spotInCircle(center, radius * 0.5)
	local block = decor("DeadStump", Vector3.new(1.8, 2.6, 1.8), at(stump, 1.3) * CFrame.Angles(0, random:NextNumber(0, 1), 0.08), Color3.fromRGB(70, 60, 52), Enum.Material.Wood)
	Blocky.rings(block, Enum.NormalId.Top)
	local rock = Props.rock(folder, spotOnCircle(center, radius + 3), 2.4, true, random, Color3.fromRGB(120, 132, 125))
	Props.mushrooms(folder, rock.CFrame * CFrame.new(0, rock.Size.Y / 2, 0), true, random)
end

-- Zone 2: an old stone windmill. Two of its sails are broken off (one lies on the ground)
-- and the rest turn very slowly, creaking in the wind.
local function buildWindmill()
	local center = Config.Landmarks.Windmill.Position
	local mossy = Color3.fromRGB(125, 135, 125)
	local wood = Blocky.shade(Config.Style.Wood, -0.3)
	local sailColor = Color3.fromRGB(205, 195, 170)
	local dark = Color3.fromRGB(30, 25, 22)

	local tower = Assets.prop(folder, MODELS.WindmillTower, 1, at(center, 0))
	if tower then
		Assets.paint(tower, "Tower", mossy, Enum.Material.Slate, true)
		Assets.paint(tower, "Moss", Color3.fromRGB(95, 150, 60), Enum.Material.Grass, false)
		Assets.paint(tower, "Roof", Blocky.shade(Config.Style.Roof, -0.25), Enum.Material.WoodPlanks, false)
		Assets.paint(tower, "Dark", dark, Enum.Material.SmoothPlastic, false)
		-- The broken-off sail lying on the ground.
		Assets.paint(tower, "Spar", wood, Enum.Material.Wood, false)
		Assets.paint(tower, "Sail", Blocky.shade(sailColor, -0.06), Enum.Material.Fabric, false)
	else
		local levels = { { Size = 10, Height = 8 }, { Size = 8.5, Height = 7 }, { Size = 7, Height = 5 } }
		local y = 0
		for index, level in levels do
			local block = piece("Tower", Vector3.new(level.Size, level.Height, level.Size), at(center, y + level.Height / 2), Blocky.shade(mossy, -index * 0.04), Enum.Material.Slate)
			decor("Moss", Vector3.new(level.Size * 0.5, 0.2, level.Size * 0.4), block.CFrame * CFrame.new(level.Size * 0.15, level.Height / 2 + 0.05, -level.Size * 0.2), Color3.fromRGB(95, 150, 60), Enum.Material.Grass)
			y += level.Height
		end
		-- A broken wooden cap, slipping off the top.
		decor("BrokenRoof", Vector3.new(8, 1, 8), at(center, y + 0.3) * CFrame.new(0.8, 0, 0) * CFrame.Angles(0, 0.3, math.rad(14)), Blocky.shade(Config.Style.Roof, -0.25), Enum.Material.WoodPlanks)
		-- The door and windows face the path (-X).
		decor("Door", Vector3.new(0.1, 4.6, 3), at(center, 2.3) * CFrame.new(-5.05, 0, 0), dark, Enum.Material.SmoothPlastic)
		decor("Window", Vector3.new(0.1, 1.6, 1.2), at(center, 11) * CFrame.new(-4.3, 0, 1.6), dark, Enum.Material.SmoothPlastic)
		decor("Window", Vector3.new(0.1, 1.4, 1.1), at(center, 19) * CFrame.new(-3.55, 0, -1.2), dark, Enum.Material.SmoothPlastic)
		-- The broken-off sail on the ground.
		local fallen = center + Vector3.new(-9, 0, 6)
		decor("Spar", Vector3.new(0.4, 0.5, 8), at(fallen, 0.25) * CFrame.Angles(0, 0.7, 0), wood, Enum.Material.Wood)
		decor("Sail", Vector3.new(2.2, 0.15, 6), at(fallen, 0.55) * CFrame.Angles(0, 0.7, 0) * CFrame.new(1.3, 0, 0) * CFrame.Angles(0, 0, 0.12), Color3.fromRGB(190, 180, 155), Enum.Material.Fabric)
	end

	-- The sails turn around X on a hub sticking out of the front. Every player's computer
	-- turns them around the model's pivot (see Client/SpinnerController), so the pivot is the hub.
	local hubFrame = at(center, 17) * CFrame.new(-4.4, 0, 0)
	local meshSails = Assets.prop(folder, MODELS.WindmillSails, 1, hubFrame * CFrame.new(0, -MODELS.WindmillSails.Width / 2, 0))
	local sails: Model
	local hub: BasePart
	if meshSails then
		sails = meshSails
		Assets.paint(sails, "Hub", Config.Style.DarkWood, Enum.Material.Wood, false)
		Assets.paint(sails, "Spar", wood, Enum.Material.Wood, false)
		Assets.paint(sails, "Sail", sailColor, Enum.Material.Fabric, false)
		-- An invisible axle in the middle of the hub, its X along the way the sails turn.
		hub = Blocky.part("Axle", Vector3.one * 0.5, hubFrame, dark, Enum.Material.SmoothPlastic, sails)
		hub.Transparency = 1
		hub.CanCollide = false
		hub.CanQuery = false
	else
		sails = Instance.new("Model")
		hub = Blocky.part("Hub", Vector3.new(1.6, 1.6, 1.6), hubFrame, Config.Style.DarkWood, Enum.Material.Wood, sails)
		hub.Shape = Enum.PartType.Cylinder
		for index, length in { 8, 3.5, 8, 3 } do
			local arm = hubFrame * CFrame.Angles(index * math.pi / 2 + 0.4, 0, 0)
			Blocky.part("Spar", Vector3.new(0.4, length, 0.5), arm * CFrame.new(-0.3, length / 2 + 0.6, 0), wood, Enum.Material.Wood, sails)
			if length > 5 then
				Blocky.part("Sail", Vector3.new(0.15, length * 0.8, 2.2), arm * CFrame.new(-0.3, length / 2 + 1.2, 1.3), sailColor, Enum.Material.Fabric, sails)
			end
		end
		for _, part in sails:GetChildren() do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end
	sails.Name = "WindmillSails"
	sails.PrimaryPart = hub
	sails:SetAttribute("SpinSpeed", Config.Props.WindmillSpin)
	CollectionService:AddTag(sails, Tags.Spinner)
	sails.Parent = folder

	-- Rubble around the tower, and broken fences.
	for _ = 1, 6 do
		Props.rock(folder, spotOnCircle(center, random:NextNumber(7, 10)), random:NextNumber(1, 1.8), random:NextNumber() < 0.5, random, mossy)
	end
	Props.fence(folder, center + Vector3.new(-12, 0, -10), center + Vector3.new(-12, 0, 2), true, random)
	Props.fence(folder, center + Vector3.new(4, 0, 12), center + Vector3.new(-8, 0, 12), true, random)
end

-- One side of the graveyard's iron fence, from `from` to `to`, leaving out `gap` studs in
-- the middle for a gate (0 for none).
local function ironFence(from: Vector3, to: Vector3, gap: number)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	local frame = CFrame.lookAt(Vector3.new(from.X, GROUND, from.Z), Vector3.new(to.X, GROUND, to.Z))
	local gapStart, gapEnd = (length - gap) / 2, (length + gap) / 2
	local fence = MODELS.IronFence
	local useModel = Assets.has(fence.Model)
	local function addRun(startAt: number, endAt: number)
		local runLength = endAt - startAt
		if runLength <= 0 then
			return
		end
		if useModel then
			-- Sections of the Blender fence, stretched a little so they fit the run exactly,
			-- and one more at the end that keeps only its post.
			local count = math.max(1, math.round(runLength / fence.Width))
			local section = runLength / count
			for index = 0, count do
				local middle = startAt + (index + 0.5) * section
				-- The section runs along its X: a quarter turn lines that up with the fence.
				local spot = frame * CFrame.new(0, 0, -middle) * CFrame.Angles(0, math.pi / 2, 0)
				local model = Assets.prop(folder, fence, section / fence.Width, spot)
				if model then
					Assets.paint(model, "Post", IRON, Enum.Material.Metal, true)
					Assets.paint(model, "Iron", IRON, Enum.Material.Metal, true)
					if index == count then
						Assets.remove(model, "Iron")
					end
				end
			end
			return
		end
		for _, y in { 0.8, 3.4 } do
			decor("FenceRail", Vector3.new(0.2, 0.2, runLength), frame * CFrame.new(0, y, -(startAt + endAt) / 2), IRON, Enum.Material.Metal)
		end
		for offset = startAt, endAt, 1.5 do
			local bar = if math.abs((offset - startAt) % 6) < 0.01 then Vector3.new(0.4, 4.4, 0.4) else Vector3.new(0.18, 3.8, 0.18)
			piece("FenceBar", bar, frame * CFrame.new(0, bar.Y / 2, -offset), IRON, Enum.Material.Metal)
		end
	end
	if gap > 0 then
		addRun(0, gapStart)
		addRun(gapEnd, length)
	else
		addRun(0, length)
	end
end

-- Zone 3: a graveyard with an iron fence. The gate faces the path (-X) and stands open.
local function buildGraveyard()
	local landmark = Config.Landmarks.Graveyard
	local center = landmark.Position
	local halfX, halfZ = 22, 17
	local gateWidth = 6
	local corners = {
		center + Vector3.new(-halfX, 0, -halfZ),
		center + Vector3.new(halfX, 0, -halfZ),
		center + Vector3.new(halfX, 0, halfZ),
		center + Vector3.new(-halfX, 0, halfZ),
	}
	ironFence(corners[1], corners[2], 0)
	ironFence(corners[2], corners[3], 0)
	ironFence(corners[3], corners[4], 0)
	ironFence(corners[4], corners[1], gateWidth)

	-- Stone pillars by the gate, and the two halves of the gate swung open.
	for _, side in { -1, 1 } do
		local pillar = center + Vector3.new(-halfX, 0, side * (gateWidth / 2 + 0.7))
		piece("GatePillar", Vector3.new(1.4, 5, 1.4), at(pillar, 2.5), DARK_STONE, Enum.Material.Slate)
		decor("GatePillarCap", Vector3.new(1.8, 0.5, 1.8), at(pillar, 5.25), Blocky.shade(DARK_STONE, 0.1), Enum.Material.Slate)
		local hinge = at(center + Vector3.new(-halfX, 0, side * gateWidth / 2), 0) * CFrame.Angles(0, side * math.rad(-110), 0)
		for offset = 0.3, gateWidth / 2, 0.75 do
			decor("GateBar", Vector3.new(0.18, 3.8, 0.18), hinge * CFrame.new(0, 1.9, -side * offset), IRON, Enum.Material.Metal)
		end
		for _, y in { 0.8, 3.4 } do
			decor("GateRail", Vector3.new(0.2, 0.2, gateWidth / 2), hinge * CFrame.new(0, y, -side * gateWidth / 4), IRON, Enum.Material.Metal)
		end
	end

	-- A dirt path from the gate down the middle.
	local aisle = decor("Aisle", Vector3.new(halfX * 2 - 2, 0.1, 4), at(center, 0.07), DIRT, Enum.Material.Ground)
	aisle.CanQuery = false

	-- Rows of gravestones on both sides of the path, all facing the gate.
	local toGate = Vector3.new(-1, 0, 0)
	for _, z in { -13, -6, 6, 13 } do
		for column = 0, 4 do
			local spot = center + Vector3.new(-12 + column * 7.5 + random:NextNumber(-0.8, 0.8), 0, z + random:NextNumber(-0.6, 0.6))
			Props.gravestone(folder, spot, toGate, random:NextInteger(1, 3), random)
		end
	end
	-- A dead tree in the back corner, pumpkins and a crooked lamp by the gate.
	local deadTree = Blocky.tree(center + Vector3.new(halfX - 4, 0, halfZ - 4), Config.TreeTypes[Config.Zones[3].TreeType], random, 1.2)
	deadTree.Name = "DeadTree"
	deadTree.Parent = folder
	for index, offset in { Vector3.new(-17, 0, 9), Vector3.new(-15, 0, -10), Vector3.new(16, 0, -3) } do
		Props.pumpkin(folder, center + offset, toGate, index == 1, random)
	end
	Props.flicker(Props.lampPost(folder, center + Vector3.new(-halfX + 3, 0, gateWidth / 2 + 3), Vector3.new(0, 0, -1), LAMP_ORANGE, true, random))
end

-- The parts crypt (without the model), facing along `frame`'s front.
local function buildPartsCrypt(frame: CFrame, ground: Vector3)
	local width, height, depth = 10, 8, 12
	local body = piece("Crypt", Vector3.new(width, height, depth), frame * CFrame.new(0, height / 2, 0), DARK_STONE, Enum.Material.Slate)
	Blocky.logLines(body, { Enum.NormalId.Left, Enum.NormalId.Right }) -- lines between the stone blocks
	-- The roof's ridge runs along the world's X, so the gable faces the path.
	Blocky.roof(ground + Vector3.new(0, height, 0), depth, width, 4, Blocky.shade(DARK_STONE, -0.2), folder)

	local front = -depth / 2
	local glow = decor("DoorGlow", Vector3.new(3, 4.6, 0.1), frame * CFrame.new(0, 2.5, front - 0.05), GLOW_ORANGE, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = GLOW_ORANGE
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = glow
	Props.flicker(light)
	for index = 1, 4 do
		decor("DoorBar", Vector3.new(0.2, 4.6, 0.2), frame * CFrame.new(-1.5 + index * 0.6, 2.5, front - 0.2), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
	end
	for _, side in { -1, 1 } do
		piece("Pillar", Vector3.new(1.2, 7, 1.2), frame * CFrame.new(side * 2.6, 3.5, front - 0.6), Blocky.shade(DARK_STONE, 0.12), Enum.Material.Slate)
	end
	decor("Lintel", Vector3.new(7, 1, 1.6), frame * CFrame.new(0, 7.4, front - 0.6), Blocky.shade(DARK_STONE, 0.12), Enum.Material.Slate)
	for step = 1, 2 do
		piece("Step", Vector3.new(6, 0.4, 1.4), frame * CFrame.new(0, 0.2 + (2 - step) * 0.2, front - 0.6 - step * 1.2), Blocky.shade(DARK_STONE, 0.05), Enum.Material.Slate)
	end
end

-- Zone 3: a stone crypt facing the path (+X), with an orange glow behind bars in its door.
local function buildCrypt()
	local center = Config.Landmarks.Crypt.Position
	local ground = Vector3.new(center.X, GROUND, center.Z)
	-- Its front (-Z) faces +X, so its sides (X) run along the world's Z.
	local frame = CFrame.lookAt(ground, ground + Vector3.new(1, 0, 0))
	local crypt = Assets.prop(folder, MODELS.Crypt, 1, frame)
	if crypt then
		Assets.paint(crypt, "Stone", DARK_STONE, Enum.Material.Slate, true)
		Assets.paint(crypt, "Front", Blocky.shade(DARK_STONE, 0.12), Enum.Material.Slate, true)
		Assets.paint(crypt, "Roof", Blocky.shade(DARK_STONE, -0.2), Enum.Material.Slate, true)
		Assets.paint(crypt, "Iron", Color3.fromRGB(30, 30, 34), Enum.Material.Metal, false)
		local glow = Assets.paint(crypt, "Glow", GLOW_ORANGE, Enum.Material.Neon, false)
		if glow then
			local light = Instance.new("PointLight")
			light.Color = GLOW_ORANGE
			light.Range = 16
			light.Brightness = 1.2
			light.Parent = glow
			Props.flicker(light)
		end
	else
		buildPartsCrypt(frame, ground)
	end
	for _ = 1, 3 do
		Props.rock(folder, spotOnCircle(center, random:NextNumber(9, 11)), random:NextNumber(1, 1.6), true, random, DARK_STONE)
	end
	Props.pumpkin(folder, center + Vector3.new(8, 0, 5.5), Vector3.new(1, 0, 0), true, random)
end

-- Zone 3: tall stones in a ring around the boss's clearing, with glowing roots in the
-- ground between them. There's a gap where the path comes in.
local function buildBossRing()
	local cfg = Config.Props
	local center = Config.Boss.Position
	local points = Config.Path.Points
	local pathEnd = points[#points]
	local entrance = math.atan2(pathEnd.Y - center.Z, pathEnd.X - center.X)
	for index = 1, cfg.BossStones do
		local angle = entrance + index * 2 * math.pi / (cfg.BossStones + 1) -- skipping one spot: the entrance
		local spot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * cfg.BossStoneRadius
		local stones = Config.Models.BossStones
		local choice = stones[random:NextInteger(1, #stones)]
		local tilt = CFrame.Angles(random:NextNumber(-0.08, 0.08), 0, random:NextNumber(-0.08, 0.08))
		-- Sunk in a little and facing the boss, like the parts version below.
		local frame = CFrame.lookAt(Vector3.new(spot.X, GROUND - 0.3, spot.Z), Vector3.new(center.X, GROUND - 0.3, center.Z)) * tilt
		local model = Assets.prop(folder, choice, random:NextNumber(2.4, 3.2) / choice.Width, frame)
		if model then
			local color = Blocky.shade(DARK_STONE, random:NextNumber(-0.1, 0.05))
			Assets.paint(model, "Stone", color, Enum.Material.Slate, true)
			Assets.paint(model, "Chunk", color, Enum.Material.Slate, true)
			if random:NextNumber() < 0.5 then
				Assets.paint(model, "Moss", Color3.fromRGB(80, 110, 60), Enum.Material.Grass, false)
			else
				Assets.remove(model, "Moss")
			end
			continue
		end
		local height = random:NextNumber(7, 11)
		local stone = piece(
			"RingStone",
			Vector3.new(random:NextNumber(2.4, 3.2), height, random:NextNumber(1.6, 2.2)),
			CFrame.lookAt(Vector3.new(spot.X, GROUND + height / 2 - 0.3, spot.Z), Vector3.new(center.X, GROUND + height / 2, center.Z))
				* CFrame.Angles(random:NextNumber(-0.08, 0.08), 0, random:NextNumber(-0.08, 0.08)),
			Blocky.shade(DARK_STONE, random:NextNumber(-0.1, 0.05)),
			Enum.Material.Slate
		)
		if random:NextNumber() < 0.5 then
			decor("Moss", Vector3.new(stone.Size.X * 0.8, 0.2, stone.Size.Z * 0.8), stone.CFrame * CFrame.new(0, height / 2 + 0.05, 0), Color3.fromRGB(80, 110, 60), Enum.Material.Grass)
		end
	end
	-- Roots: two glowing pieces each, bending a little, reaching out from the boss.
	for index = 1, 10 do
		local angle = index * 2 * math.pi / 10 + random:NextNumber(-0.2, 0.2)
		local bend = random:NextNumber(-0.35, 0.35)
		local startDistance = random:NextNumber(16, 20)
		local length = random:NextNumber(6, 8)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local first = center + direction * (startDistance + length / 2)
		local root = decor("GlowRoot", Vector3.new(0.5, 0.12, length), CFrame.lookAt(Vector3.new(first.X, GROUND + 0.04, first.Z), Vector3.new(center.X, GROUND + 0.04, center.Z)), ROOT_GLOW, Enum.Material.Neon)
		root.CanQuery = false
		local tip = root.CFrame * CFrame.new(0, 0, length / 2) * CFrame.Angles(0, bend, 0) * CFrame.new(0, 0.01, length * 0.35)
		local second = decor("GlowRoot", Vector3.new(0.35, 0.12, length * 0.7), tip, ROOT_GLOW, Enum.Material.Neon)
		second.CanQuery = false
	end
end

-- Builds every landmark into `parent`. `randomness` decides the little differences
-- (where the rocks go, how the gravestones lean...).
function Landmarks.build(parent: Instance, randomness: Random)
	folder = parent
	random = randomness
	buildLake()
	buildTentCamp()
	buildMeadow()
	buildSwamp(Config.Landmarks.Swamp)
	buildSwamp(Config.Landmarks.SmallSwamp)
	buildWindmill()
	buildGraveyard()
	buildCrypt()
	buildBossRing()
end

return Landmarks
