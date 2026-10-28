--!strict
-- What you see at the forest's edges (see Config.Edges). The walls that really stop you are
-- invisible (see Systems/ZoneManager); this stands in front of them, only for looks:
--   * a thick, uneven hedge along the outside walls, with boulders at its foot
--   * at each gate between two zones (Config.Gates.Looks): a gatehouse around the gate, and
--     along the rest of the border a rocky ridge with little trees on it, or a crumbling
--     stone wall with bare trees beside it
-- Everything is a Blender model (Config.Models) once it's imported into Studio, and plain
-- parts until then. Thin things (leaves, twigs, moss, lamps, iron bars) can be walked through
-- and raycasts go through them; rocks, walls and towers are solid.
-- ZoneManager calls Edges.build after it makes the walls. It's not a system, so it has no
-- init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Assets = require(script.Parent.Assets)
local Blocky = require(script.Parent.Blocky)
local Props = require(script.Parent.Props)

local GROUND = 0.05 -- the top of the floors (see ZoneManager)
local IRON = Color3.fromRGB(45, 45, 52)
local MOSS = Color3.fromRGB(95, 150, 60)
-- The parts gatehouses (without the models), the same shapes as the Blender ones.
local LOG_TOWER_HEIGHT = 20
local LOG_BEAMS = { 14.8, 18.9 } -- heights of the two beams across the gate
local STONE_PILLAR_HEIGHT = 17
local IRON_BAR = 14.4 -- height of the iron bar across the stone gatehouse
local IRON_ARCH = 19 -- ...and the top of its arch
local FACES = {
	Enum.NormalId.Front,
	Enum.NormalId.Back,
	Enum.NormalId.Left,
	Enum.NormalId.Right,
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
}

local Edges = {}

local folder: Folder
local random = Random.new(31) -- the same edges every time
local warned: { [string]: boolean } = {}

-- Players walk through it, and raycasts (clicks, the ground checks) go through it.
local function soft(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
end

local function between(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

-- A copy of one of the Blender `models` (picked at random) and its part named `reference`,
-- or nil if none is imported yet (then the caller builds parts instead).
local function pickModel(models: { string }, reference: string): (Model?, BasePart?)
	local name = Assets.pick(models, random)
	local model = if name then Assets.model(name) else nil
	if not (name and model) then
		return nil, nil
	end
	local part = model:FindFirstChild(reference)
	if part and part:IsA("BasePart") then
		return model, part
	end
	if not warned[name] then
		warned[name] = true
		warn(`[Edges] The "{name}" model needs a part named {reference}, so parts are used instead`)
	end
	model:Destroy()
	return nil, nil
end

-- A tree that's only scenery: it isn't tagged, so it can't be chopped and doesn't count for
-- "% cleared". Players walk through it, unless `solid` (then they bump into its trunk).
local function sceneryTree(name: string, base: Vector3, treeType: Types.TreeTypeConfig, scale: number, solid: boolean)
	local tree = Blocky.tree(base, treeType, random, scale)
	tree.Name = name
	for _, part in tree:GetDescendants() do
		if part:IsA("BasePart") and not (solid and part.Name == "Trunk") then
			soft(part)
		end
	end
	tree.Parent = folder
end

-- Which area's hedge colour (and twigs) a spot along the walls gets: 1 next to the camp and
-- zone 1, then each zone's own number. Past the far wall it's the last zone.
local function areaAt(z: number): number
	return Zones.indexAt(Vector3.new(0, 0, z)) or (if z > Zones.getBounds(1).MinZ then 1 else Zones.count())
end

-- One piece of hedge standing at `base`, turned `angle` (0 = running along X).
local function hedge(base: Vector3, angle: number, area: number)
	local cfg = Config.Edges
	local color = Blocky.shade(cfg.HedgeColors[math.min(area, #cfg.HedgeColors)], random:NextNumber(-0.06, 0.04))
	local twigs = area >= cfg.TwigZone
	-- Flipped half the time and turned a hair, so the pieces don't repeat.
	local flip = if random:NextNumber() < 0.5 then 0 else math.pi
	local turn = CFrame.Angles(0, angle + flip + random:NextNumber(-0.05, 0.05), 0)

	local model, leaves = pickModel(Config.Models.Hedges, "Hedge")
	if model and leaves then
		-- A bit longer than the spacing, so the pieces overlap and there are no holes.
		Assets.fit(model, leaves, cfg.HedgeLength * random:NextNumber(1.05, 1.15), base, turn)
		for _, part in model:GetChildren() do
			if not part:IsA("BasePart") then
				continue
			elseif part.Name == "Twig" and not twigs then
				part:Destroy()
				continue
			elseif part.Name == "Twig" then
				part.Color = cfg.TwigColor
				part.Material = Enum.Material.Wood
			else
				part.Color = color
				part.Material = Config.Tree.LeafMaterial
			end
			soft(part)
		end
		model.Name = "Hedge"
		model.Parent = folder
		return
	end

	-- Parts: a long low block with two taller ones on it.
	local frame = CFrame.new(base) * turn
	local length = cfg.HedgeLength + 1
	local low = cfg.HedgeHeight[1]
	local pieces = {
		Blocky.part(
			"Hedge",
			Vector3.new(length, low, 4),
			frame * CFrame.new(0, low / 2, 0),
			color,
			Config.Tree.LeafMaterial,
			folder
		),
	}
	for _ = 1, 2 do
		local height = random:NextNumber(low + 1, cfg.HedgeHeight[2])
		local width = random:NextNumber(3.5, 5)
		local x = random:NextNumber(-length / 2 + width / 2, length / 2 - width / 2)
		table.insert(
			pieces,
			Blocky.part(
				"Hedge",
				Vector3.new(width, height, 3.6),
				frame * CFrame.new(x, height / 2, random:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, random:NextNumber(-0.2, 0.2), 0),
				Blocky.shade(color, random:NextNumber(-0.08, 0.06)),
				Config.Tree.LeafMaterial,
				folder
			)
		)
	end
	if twigs then
		for _ = 1, 3 do
			local twig = random:NextNumber(2.5, 4)
			table.insert(
				pieces,
				Blocky.part(
					"Twig",
					Vector3.new(0.25, twig, 0.25),
					frame
						* CFrame.new(random:NextNumber(-length / 2, length / 2), low + 1, 0)
						* CFrame.Angles(random:NextNumber(-0.6, 0.6), 0, random:NextNumber(-0.4, 0.4))
						* CFrame.new(0, twig / 2, 0),
					cfg.TwigColor,
					Enum.Material.Wood,
					folder
				)
			)
		end
	end
	for _, piece in pieces do
		soft(piece)
	end
end

-- A boulder at the hedge's foot, `inward` (a unit vector) pointing into the forest.
local function boulder(edge: Vector3, inward: Vector3)
	local size = between(Config.Edges.BoulderSize)
	local spot = edge + inward * (1 + size * 0.6)
	Props.rock(folder, spot, size, random:NextNumber() < 0.5, random)
end

-- The hedge along all four outside walls, with boulders at its foot.
local function buildHedges()
	local cfg = Config.Edges
	local length = cfg.HedgeLength
	local halfWidth = Config.Forest.Width / 2
	local nearZ = Zones.getCampBounds().MaxZ
	local farZ = Zones.getBounds(Zones.count()).MinZ
	local x = halfWidth + cfg.HedgeOffset

	-- Left and right
	local z = nearZ - length / 2
	while z + length / 2 > farZ do
		for _, side in { -1, 1 } do
			hedge(Vector3.new(side * x, GROUND, z), math.pi / 2, areaAt(z))
		end
		z -= length
	end
	-- Behind the camp, and the far end
	local along = -halfWidth + length / 2
	while along - length / 2 < halfWidth do
		hedge(Vector3.new(along, GROUND, nearZ + cfg.HedgeOffset), 0, 1)
		hedge(Vector3.new(along, GROUND, farZ - cfg.HedgeOffset), 0, Zones.count())
		along += length
	end

	-- Boulders, but not in the river.
	local riverZ = Zones.getRiverZ()
	local riverHalf = Config.Camp.RiverWidth / 2 + 4
	z = nearZ - cfg.BoulderEvery / 2
	while z > farZ do
		for _, side in { -1, 1 } do
			local spot = z + random:NextNumber(-4, 4)
			if math.abs(spot - riverZ) > riverHalf then
				boulder(Vector3.new(side * halfWidth, GROUND, spot), Vector3.new(-side, 0, 0))
			end
		end
		z -= cfg.BoulderEvery
	end
	along = -halfWidth + cfg.BoulderEvery / 2
	while along < halfWidth do
		boulder(Vector3.new(along + random:NextNumber(-4, 4), GROUND, nearZ), Vector3.new(0, 0, -1))
		boulder(Vector3.new(along + random:NextNumber(-4, 4), GROUND, farZ), Vector3.new(0, 0, 1))
		along += cfg.BoulderEvery
	end
end

-- Which face of `part` points most towards `direction`. (We ask, instead of assuming Back
-- is +Z, in case Studio turned a model's parts when it imported them.)
local function faceToward(part: BasePart, direction: Vector3): Enum.NormalId
	local best, bestDot = Enum.NormalId.Back, -math.huge
	for _, face in FACES do
		local dot = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)):Dot(direction)
		if dot > bestDot then
			best, bestDot = face, dot
		end
	end
	return best
end

-- Big gold words on the side of a gatehouse's sign that faces `toward`.
local function signText(sign: BasePart, toward: Vector3, text: string)
	local gui = Blocky.face(sign, faceToward(sign, toward))
	local box = Instance.new("Frame")
	box.Name = "Words"
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundTransparency = 1
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.Parent = box
	box.Parent = gui
	Blocky.label(box, text, Config.Style.TitleFont, Config.Style.Gold)
end

-- One light for all of a gatehouse's lanterns, at `position` in the middle of the gate.
local function lampLight(anchor: BasePart, position: Vector3, look: Types.GateLookConfig)
	local cfg = Config.Edges
	local attachment = Instance.new("Attachment")
	attachment.Name = "LampLight"
	attachment.Parent = anchor
	attachment.WorldPosition = position
	local light = Instance.new("PointLight")
	light.Color = look.LampColor
	light.Range = cfg.LampRange
	light.Brightness = cfg.LampBrightness
	light.Parent = attachment
	if look.Flicker then
		Props.flicker(light)
	end
end

-- The Blender gatehouse, standing around the gate at `z`. false if it isn't imported.
-- Its towers are the part named like the gatehouse ("Log" or "Stone"): exactly
-- Config.Edges.GatehouseWidth wide, with the gate's opening in the middle.
local function meshGatehouse(look: Types.GateLookConfig, z: number, thisZone: string, nextZone: string): boolean
	local cfg = Config.Edges
	local style = Config.Style
	local model, towers = pickModel({ Config.Models.Gatehouses[look.Gatehouse] }, look.Gatehouse)
	if not (model and towers) then
		return false
	end
	Assets.fit(model, towers, cfg.GatehouseWidth, Vector3.new(0, GROUND, z), CFrame.identity)

	local lamp: BasePart? = nil
	for _, part in model:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local name = part.Name
		if name == "Log" then
			part.Color = style.Wood
			part.Material = Enum.Material.Wood
		elseif name == "Stone" then
			part.Color = cfg.StoneWallColor
			part.Material = Enum.Material.Slate
		elseif name == "Roof" then
			part.Color = style.Roof
			part.Material = Enum.Material.WoodPlanks
		elseif name == "Sign" then
			part.Color = Blocky.shade(style.Wood, 0.1)
			part.Material = Enum.Material.WoodPlanks
			-- Walking up to the gate you read the next zone's name; coming back, this zone's.
			signText(part, Vector3.zAxis, nextZone)
			signText(part, -Vector3.zAxis, thisZone)
		elseif name == "Lamp" then
			part.Color = look.LampColor
			part.Material = Enum.Material.Neon
			lamp = part
		elseif name == "Iron" then
			part.Color = IRON
			part.Material = Enum.Material.Metal
		end
		-- Invisible boxes do the bumping (below): each mesh is one piece with a hole for the
		-- gate, and Roblox's collision shape for a mesh like that might close the hole.
		soft(part)
	end
	model.Name = "Gatehouse"
	model.Parent = folder

	local tower = (cfg.GatehouseWidth - Config.Gates.Width) / 2
	for _, side in { -1, 1 } do
		local collider = Blocky.part(
			"TowerCollider",
			Vector3.new(tower, towers.Size.Y, tower),
			CFrame.new(side * (Config.Gates.Width / 2 + tower / 2), GROUND + towers.Size.Y / 2, z),
			IRON,
			Enum.Material.SmoothPlastic,
			folder
		)
		collider.Transparency = 1
		collider.CastShadow = false
	end
	if lamp then
		lampLight(lamp, Vector3.new(0, lamp.Position.Y, z), look)
	end
	return true
end

-- The parts gatehouse: log towers with roofs and two beams, or stone pillars with an iron arch.
local function partsGatehouse(look: Types.GateLookConfig, z: number, thisZone: string, nextZone: string)
	local cfg = Config.Edges
	local style = Config.Style
	local gate = Config.Gates.Width
	local tower = (cfg.GatehouseWidth - gate) / 2
	local log = look.Gatehouse == "Log"
	local stone = cfg.StoneWallColor
	local lampY = GROUND + cfg.LampHeight
	local function at(x: number, y: number): CFrame
		return CFrame.new(x, GROUND + y, z)
	end

	local anchor: BasePart? = nil
	for _, side in { -1, 1 } do
		local x = side * (gate / 2 + tower / 2)
		local face: number -- how far the tower's face is from the middle (for the lanterns)
		if log then
			local body = Blocky.part(
				"Log",
				Vector3.new(tower, LOG_TOWER_HEIGHT, tower),
				at(x, LOG_TOWER_HEIGHT / 2),
				style.Wood,
				Enum.Material.WoodPlanks,
				folder
			)
			Blocky.logLines(body, { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right })
			Blocky.roof(Vector3.new(x, GROUND + LOG_TOWER_HEIGHT, z), tower, tower, 4, style.Roof, folder)
			face = tower / 2
		else
			local body = STONE_PILLAR_HEIGHT - 2.4
			local slate = Enum.Material.Slate
			Blocky.part("Stone", Vector3.new(tower, 1.4, tower), at(x, 0.7), stone, slate, folder)
			Blocky.part("Stone", Vector3.new(tower - 1.4, body, tower - 1.4), at(x, 1.4 + body / 2), stone, slate, folder)
			Blocky.part("Stone", Vector3.new(tower, 1, tower), at(x, STONE_PILLAR_HEIGHT - 0.5), stone, slate, folder)
			Blocky.part(
				"Stone",
				Vector3.new(3, 2, 3),
				at(x, STONE_PILLAR_HEIGHT + 1) * CFrame.Angles(0, math.pi / 4, 0),
				Blocky.shade(stone, 0.08),
				Enum.Material.Slate,
				folder
			)
			face = (tower - 1.4) / 2
		end
		-- A lantern on each face of the tower, on a little arm.
		for _, out in { -1, 1 } do
			local lx = side * (gate / 2 + 1.3)
			local lantern = Blocky.part(
				"Lamp",
				Vector3.new(0.9, 1.2, 0.9),
				CFrame.new(lx, lampY, z + out * (face + 0.8)),
				look.LampColor,
				Enum.Material.Neon,
				folder
			)
			local arm = Blocky.part(
				"Iron",
				Vector3.new(0.25, 0.25, 1.05),
				CFrame.new(lx, lampY + 1.15, z + out * (face + 0.45)),
				IRON,
				Enum.Material.Metal,
				folder
			)
			soft(lantern)
			soft(arm)
			anchor = anchor or lantern
		end
	end

	local sign: Part
	if log then
		for _, y in LOG_BEAMS do
			Blocky.part("Log", Vector3.new(gate + 2, 1.3, 1.3), at(0, y), style.Wood, Enum.Material.Wood, folder)
		end
		sign = Blocky.part(
			"Sign",
			Vector3.new(14, 2.8, 1.7),
			at(0, (LOG_BEAMS[1] + LOG_BEAMS[2]) / 2),
			style.Wood,
			Enum.Material.WoodPlanks,
			folder
		)
	else
		-- A straight bar, an arch over it (two slanted bars and a flat top) and bars between them.
		local bars = {
			Blocky.part("Iron", Vector3.new(gate + 0.4, 0.35, 0.35), at(0, IRON_BAR), IRON, Enum.Material.Metal, folder),
			Blocky.part("Iron", Vector3.new(gate / 2, 0.35, 0.35), at(0, IRON_ARCH), IRON, Enum.Material.Metal, folder),
		}
		local rise = IRON_ARCH - IRON_BAR
		local run = gate / 4
		for _, side in { -1, 1 } do
			table.insert(
				bars,
				Blocky.part(
					"Iron",
					Vector3.new(math.sqrt(rise * rise + run * run) + 0.3, 0.35, 0.35),
					at(side * gate * 3 / 8, (IRON_BAR + IRON_ARCH) / 2) * CFrame.Angles(0, 0, -side * math.atan2(rise, run)),
					IRON,
					Enum.Material.Metal,
					folder
				)
			)
		end
		for bar = -2, 2 do
			local middle = at(bar * 2, (IRON_BAR + IRON_ARCH) / 2)
			table.insert(bars, Blocky.part("Iron", Vector3.new(0.22, rise, 0.22), middle, IRON, Enum.Material.Metal, folder))
		end
		for _, bar in bars do
			soft(bar)
		end
		sign = Blocky.part("Sign", Vector3.new(10, 2.2, 0.4), at(0, 16.1), style.Wood, Enum.Material.WoodPlanks, folder)
	end
	soft(sign)
	signText(sign, Vector3.zAxis, nextZone)
	signText(sign, -Vector3.zAxis, thisZone)
	if anchor then
		lampLight(anchor, Vector3.new(0, lampY, z), look)
	end
end

local function buildGatehouse(index: number, look: Types.GateLookConfig, z: number)
	local thisZone = Config.Zones[index].Name
	local nextZone = Config.Zones[index + 1].Name
	if not meshGatehouse(look, z, thisZone, nextZone) then
		partsGatehouse(look, z, thisZone, nextZone)
	end
end

-- The ridge rock models, or the small rock models (made big) if those aren't imported.
local function ridgeModels(): { string }
	for _, name in Config.Models.RidgeRocks do
		if Assets.has(name) then
			return Config.Models.RidgeRocks
		end
	end
	return Config.Models.Rocks
end

-- A row of big rocks along the border at `z`, on both sides of the gatehouse, some with a
-- little tree of the zone before the gate on top.
local function buildRidge(index: number, z: number)
	local cfg = Config.Edges
	local treeType = Config.TreeTypes[Config.Zones[index].TreeType]
	local models = ridgeModels()
	for _, side in { -1, 1 } do
		local x = cfg.GatehouseWidth / 2
		while x < Config.Forest.Width / 2 do
			local size = between(cfg.RidgeRockSize)
			-- The first rock leans on the gatehouse's tower; the rest overlap each other.
			local spot = Vector3.new(side * (x + size * 0.5), 0, z + random:NextNumber(-1.5, 1.5))
			local rock = Props.rock(folder, spot, size, true, random, cfg.RidgeColor, models)
			if random:NextNumber() < cfg.RidgeTreeChance then
				-- Sunk in a little, so it doesn't stand on the rock's edge in the air.
				local top = rock.Position.Y + rock.Size.Y / 2 - 1
				sceneryTree("RidgeTree", Vector3.new(rock.Position.X, top, rock.Position.Z), treeType, cfg.RidgeTreeScale, false)
			end
			x += cfg.RidgeSpacing
		end
	end
end

-- One piece of the old stone wall, standing at `base` along X.
local function stoneWallPiece(base: Vector3)
	local cfg = Config.Edges
	local color = Blocky.shade(cfg.StoneWallColor, random:NextNumber(-0.06, 0.04))
	local flip = if random:NextNumber() < 0.5 then 0 else math.pi
	local turn = CFrame.Angles(0, flip + random:NextNumber(-0.05, 0.05), 0)

	local model, stones = pickModel(Config.Models.StoneWalls, "Stone")
	if model and stones then
		-- A bit longer than the spacing, so the pieces overlap.
		Assets.fit(model, stones, cfg.StoneWallLength * random:NextNumber(1.02, 1.1), base, turn)
		for _, part in model:GetChildren() do
			if not part:IsA("BasePart") then
				continue
			elseif part.Name == "Moss" then
				part.Color = MOSS
				part.Material = Enum.Material.Grass
				soft(part)
			else
				part.Color = color
				part.Material = Enum.Material.Slate
			end
		end
		model.Name = "StoneWall"
		model.Parent = folder
		return
	end

	-- Parts: stone blocks of uneven heights.
	local frame = CFrame.new(base) * turn
	local x = -cfg.StoneWallLength / 2
	while x < cfg.StoneWallLength / 2 - 0.5 do
		local width = math.min(random:NextNumber(1.8, 2.8), cfg.StoneWallLength / 2 - x)
		local height = between(cfg.StoneWallHeight)
		Blocky.part(
			"Stone",
			Vector3.new(width - 0.1, height, 1.8),
			frame * CFrame.new(x + width / 2, height / 2, random:NextNumber(-0.1, 0.1)),
			Blocky.shade(color, random:NextNumber(-0.06, 0.06)),
			Enum.Material.Slate,
			folder
		)
		x += width
	end
end

-- A crumbling stone wall along the border at `z` on both sides of the gatehouse, with a few
-- pieces fallen down into rubble, and bare trees of the zone after the gate beside it.
local function buildStoneWall(index: number, z: number)
	local cfg = Config.Edges
	local start = cfg.GatehouseWidth / 2
	local count = math.ceil((Config.Forest.Width / 2 - start) / cfg.StoneWallLength)
	for _, side in { -1, 1 } do
		-- Which pieces have fallen down (never the one next to the gatehouse).
		local fallen: { [number]: boolean } = {}
		for _ = 1, cfg.StoneWallGaps do
			fallen[random:NextInteger(2, count)] = true
		end
		for piece = 1, count do
			local x = side * (start + (piece - 0.5) * cfg.StoneWallLength)
			local base = Vector3.new(x, GROUND, z + random:NextNumber(-0.3, 0.3))
			if fallen[piece] then
				for _ = 1, 3 do
					local spot = base + Vector3.new(random:NextNumber(-3, 3), 0, random:NextNumber(-1.2, 1.2))
					Props.rock(folder, spot, random:NextNumber(1.2, 2.2), random:NextNumber() < 0.4, random, cfg.StoneWallColor)
				end
			else
				stoneWallPiece(base)
			end
		end
	end

	local treeType = Config.TreeTypes[Config.Zones[index + 1].TreeType]
	for tree = 1, cfg.DeadTrees do
		local side = if tree % 2 == 0 then 1 else -1
		local x = side * random:NextNumber(start + 6, Config.Forest.Width / 2 - 10)
		local away = if random:NextNumber() < 0.5 then 1 else -1 -- which side of the wall
		local base = Vector3.new(x, GROUND, z + away * random:NextNumber(3.5, 5))
		sceneryTree("WallTree", base, treeType, cfg.DeadTreeScale, true)
	end
end

-- Build all the edges into a folder called "Edges" in `parent`.
function Edges.build(parent: Instance)
	folder = Instance.new("Folder")
	folder.Name = "Edges"
	buildHedges()
	local looks = Config.Gates.Looks
	for index = 1, Zones.count() - 1 do
		local look = looks[math.min(index, #looks)]
		local z = Zones.getBounds(index).MinZ
		buildGatehouse(index, look, z)
		if look.Border == "Ridge" then
			buildRidge(index, z)
		else
			buildStoneWall(index, z)
		end
	end
	folder.Parent = parent
end

return Edges
