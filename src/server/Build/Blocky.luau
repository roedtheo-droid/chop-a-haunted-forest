--!strict
-- Helpers that build the blocky, cartoony look (see STYLE_GUIDE.md) out of plain parts:
-- trees, log cabins and log walls, gable roofs, wooden signs, striped pad edges and wood rings.
-- No art needed: everything is Parts, colours and a little SurfaceGui. Trees use the Blender
-- models instead once they're imported into Studio (see Build/Assets).
-- Used by ForestSpawner, SceneryManager, SawmillManager, ToolShed, ZoneManager, CampManager,
-- TreeManager, LogManager, BossManager and Edges. It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChopRules = require(ReplicatedStorage.Shared.ChopRules)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Assets = require(script.Parent.Assets)

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local PIXELS_PER_STUD = 25 -- how sharp SurfaceGui pictures on parts are
local LOG_LINES = 6 -- dark lines between the logs on each cabin wall
local SIGN_DEPTH = 0.4

local Blocky = {}

-- A plain anchored part. `parent` can be nil, to parent it yourself once it's set up.
function Blocky.part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Like Blocky.part, but it's the one-part Blender model `model` (a log, a stump, the boss's
-- trunk...) when that's imported. Setting a MeshPart's Size stretches its mesh to fill it, so
-- both versions are the same box, and the game can still resize it later (the boss's roots).
function Blocky.block(
	model: string,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance?
): BasePart
	local mesh = Assets.part(model)
	if not mesh then
		return Blocky.part(name, size, cframe, color, material, parent)
	end
	mesh.Name = name
	mesh.Size = size
	mesh.CFrame = cframe
	mesh.Color = color
	mesh.Material = material
	mesh.Parent = parent -- Assets.part already anchored it
	return mesh
end

-- A wedge. Its slope faces its front (-Z): the back is tall and the front touches the ground.
function Blocky.wedge(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.Color = color
	wedge.Material = material
	wedge.Anchored = true
	wedge.Parent = parent
	return wedge
end

-- A roundish flat patch on the ground at `center` (its Y is ignored), made of a cross and a
-- square turned 45 degrees, with its top at height `top`. You walk through it, and raycasts
-- looking for the ground go through it too. The three pieces sit a hair apart in height,
-- so where they overlap doesn't flicker.
function Blocky.patch(
	name: string,
	center: Vector3,
	radius: number,
	top: number,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): { Part }
	local thickness = 0.2
	local y = top - thickness / 2
	local parts = {
		Blocky.part(name, Vector3.new(radius * 2, thickness, radius * 1.2), CFrame.new(center.X, y, center.Z), color, material, parent),
		Blocky.part(name, Vector3.new(radius * 1.2, thickness, radius * 2), CFrame.new(center.X, y + 0.01, center.Z), color, material, parent),
		Blocky.part(
			name,
			Vector3.new(radius * 1.45, thickness, radius * 1.45),
			CFrame.new(center.X, y + 0.02, center.Z) * CFrame.Angles(0, math.pi / 4, 0),
			color,
			material,
			parent
		),
	}
	for _, part in parts do
		part.CanCollide = false
		part.CanQuery = false
	end
	return parts
end

-- A colour a bit lighter (amount above 0) or darker (amount below 0). 0.2 = 20%.
function Blocky.shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(WHITE, amount)
	end
	return color:Lerp(BLACK, -amount)
end

local function pick(colors: { Color3 }, random: Random): Color3
	return colors[random:NextInteger(1, #colors)]
end

-- White text with a thick black outline that fills its parent.
function Blocky.label(parent: Instance, text: string, font: Enum.Font, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or WHITE
	label.Font = font
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = Config.Style.TextStroke
	stroke.Color = BLACK
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- A SurfaceGui on one face of a part, to paint things on it. With `color`, the face is filled first.
function Blocky.face(part: BasePart, face: Enum.NormalId, color: Color3?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = `{face.Name}Face`
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 1 -- shaded by the sun like the part itself
	gui.Parent = part
	if color then
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = color
		fill.Parent = gui
	end
	return gui
end

-- A plain coloured rectangle on a SurfaceGui, placed with scale (0 to 1) numbers.
function Blocky.rect(parent: Instance, x: number, y: number, w: number, h: number, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.Parent = parent
	return frame
end
local rect = Blocky.rect

local FACES = {
	Enum.NormalId.Front,
	Enum.NormalId.Back,
	Enum.NormalId.Left,
	Enum.NormalId.Right,
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
}

-- Which face of `part` points most towards `direction`. (Asked, instead of assuming Back
-- is +Z, in case Studio turned a model's parts when it imported them.)
function Blocky.faceToward(part: BasePart, direction: Vector3): Enum.NormalId
	local best, bestDot = Enum.NormalId.Back, -math.huge
	for _, face in FACES do
		local dot = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)):Dot(direction)
		if dot > bestDot then
			best, bestDot = face, dot
		end
	end
	return best
end

-- Big outlined words on the side of a board (a sign from a Blender model) that faces
-- `toward`. White, or `color`.
function Blocky.boardText(board: BasePart, toward: Vector3, text: string, color: Color3?)
	local gui = Blocky.face(board, Blocky.faceToward(board, toward))
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
	Blocky.label(box, text, Config.Style.TitleFont, color)
end

-- Turn a part into an invisible collider: players still bump into it and walk on it, but
-- what they see is the Blender model built over it. (Used where the exact shape matters,
-- like a bridge's deck and ramps: a mesh's own collision shape is only roughly its shape.)
function Blocky.collider(part: BasePart)
	part.Transparency = 1
	part.CastShadow = false
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end
end

-- Put `skin` (a Blender model in `group`, see Assets.placed) over the rest of `group`: the
-- parts version of the same thing (a building, a stove...). Those parts turn invisible but
-- keep doing their job: solid ones still stop players, and lights and smoke on them still
-- work. `looks` colours the model's parts by name; only Solid ones stop players and the
-- camera (so it can't swing through a wall to the outside).
function Blocky.dress(group: Instance, skin: Model, looks: { [string]: Types.SkinLook })
	for _, part in group:GetDescendants() do
		if part:IsA("BasePart") and not part:IsDescendantOf(skin) then
			Blocky.collider(part)
			part.CanQuery = part.CanCollide -- invisible decorations don't catch clicks
		end
	end
	for _, part in skin:GetChildren() do
		if part:IsA("BasePart") then
			local look = looks[part.Name]
			if look then
				part.Color = look.Color
				part.Material = look.Material
			end
			local solid = look ~= nil and look.Solid == true
			part.CanCollide = solid
			part.CanQuery = solid
			part.CanTouch = false
		end
	end
end

-- Dark lines between the logs on some faces of a wall, so it looks like a log wall.
function Blocky.logLines(part: BasePart, faces: { Enum.NormalId })
	for _, face in faces do
		local gui = Blocky.face(part, face)
		for line = 1, LOG_LINES do
			rect(gui, 0, line / (LOG_LINES + 1), 1, 0.025, Config.Style.DarkWood)
		end
	end
end

-- The light inside of a tree with growth rings: for stump tops and the ends of logs.
function Blocky.rings(part: BasePart, face: Enum.NormalId)
	local gui = Blocky.face(part, face, Config.Style.InnerWood)
	for _, scale in { 0.75, 0.4 } do
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(scale, scale)
		ring.BackgroundTransparency = 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = ring
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Config.Style.Rings
		stroke.Parent = ring
		ring.Parent = gui
	end
end

-- Short dark marks on all four sides of a birch trunk, drawn with scale numbers.
local function addBirchMarks(trunk: BasePart, random: Random)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Blocky.face(trunk, face)
		for _ = 1, Config.Tree.BirchMarks do
			local width = random:NextNumber(0.3, 0.6)
			rect(gui, random:NextNumber(0, 1 - width), random:NextNumber(0.05, 0.95), width, 0.018, Config.Style.BirchMark)
		end
	end
end

-- One of `shapes` (names with how often each is picked), or nil if there are none.
local function pickShape(shapes: { [string]: number }?, random: Random): string?
	if not shapes then
		return nil
	end
	local total = 0
	for _, weight in shapes do
		total += weight
	end
	local roll = random:NextNumber() * total
	local last: string? = nil
	for name, weight in shapes do
		roll -= weight
		last = name
		if roll <= 0 then
			return name
		end
	end
	return last
end

-- A tree from the Blender model `shapeName` (see Build/Assets), or nil if it isn't imported.
-- It has the same parts as the parts tree below (Trunk, Root, Branch, Leaves, LeafBlock),
-- so chopping, mimics, stumps and falling work just the same.
local function meshTree(
	shapeName: string,
	base: Vector3,
	treeType: Types.TreeTypeConfig,
	random: Random,
	scale: number,
	barkColor: Color3,
	birch: boolean
): Model?
	local shape = Config.Models.Trees[shapeName]
	local model = if shape then Assets.model(shapeName) else nil
	if not (shape and model) then
		return nil
	end
	local trunk = model:FindFirstChild("Trunk")
	local leaves = model:FindFirstChild("Leaves")
	if not (trunk and trunk:IsA("BasePart") and leaves and leaves:IsA("BasePart")) then
		warn(`[Blocky] The "{shapeName}" model needs parts named Trunk and Leaves, so parts are used instead`)
		model:Destroy()
		return nil
	end
	-- A random quarter turn: the trunk stays square to the world, which the chop notch and
	-- a mimic's knot rely on.
	local turn = CFrame.Angles(0, random:NextInteger(0, 3) * math.pi / 2, 0)
	Assets.fit(model, trunk, shape.TrunkWidth * scale, base, turn)
	model.Name = "Tree"

	local leafColor = pick(shape.LeafColors or treeType.LeafColors, random)
	for _, part in model:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		elseif part.Name == "Trunk" then
			part.Color = barkColor
			part.Material = Enum.Material.Wood
		elseif part.Name == "Root" or part.Name == "Branch" then
			part.Color = if part.Name == "Root" then Blocky.shade(barkColor, -0.12) else barkColor
			part.Material = Enum.Material.Wood
			part.CanCollide = false
		elseif part.Name == "Leaves" then
			part.Color = leafColor
			part.Material = Config.Tree.LeafMaterial
		elseif part.Name == "LeafBlock" then
			part.Color = Blocky.shade(leafColor, random:NextNumber(-0.12, 0.12))
			part.Material = Config.Tree.LeafMaterial
			-- Unanchored but welded to the anchored Leaves, so it follows Leaves around.
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = leaves
			weld.Part1 = part
			weld.Parent = part
		end
	end
	if birch then
		addBirchMarks(trunk, random)
	end
	return model
end

-- A blocky tree with its pivot at `base` (the bottom of the trunk), not yet parented.
-- Parts: "Trunk" (a square block), "Root" wedges at its foot, maybe "Branch" blocks, and a
-- crown: the biggest leaf block is "Leaves", the others ("LeafBlock") are welded to it,
-- so moving Leaves by its CFrame (a mimic's "Sway" tell) moves the whole crown.
-- The trunk isn't turned, so its faces line up with the model's pivot (mimic eyes rely on that).
-- When the tree type has Blender models (Shapes) and they're imported, it's one of those instead.
function Blocky.tree(base: Vector3, treeType: Types.TreeTypeConfig, random: Random, extraScale: number?): Model
	local cfg = Config.Tree
	-- Every tree is a little bigger or smaller than the next, so they don't look copied.
	local scale = treeType.Scale * (extraScale or 1) * (1 + random:NextNumber(-cfg.SizeSpread, cfg.SizeSpread))
	local birch = random:NextNumber() < (treeType.BirchChance or 0)
	-- Birches are a bit taller and thinner.
	local height = cfg.TrunkHeight * scale * (if birch then 1.15 else 1)
	local width = cfg.TrunkWidth * scale * (if birch then 0.8 else 1)
	local barkColor = if birch and treeType.BirchColor then treeType.BirchColor else pick(treeType.TrunkColors, random)
	local origin = CFrame.new(base)

	local shapeName = pickShape(if birch then treeType.BirchShapes else treeType.Shapes, random)
	if shapeName then
		local model = meshTree(shapeName, base, treeType, random, scale, barkColor, birch)
		if model then
			return model
		end
	end

	local model = Instance.new("Model")
	model.Name = "Tree"

	local trunk = Blocky.part(
		"Trunk",
		Vector3.new(width, height, width),
		origin * CFrame.new(0, height / 2, 0),
		barkColor,
		Enum.Material.Wood,
		model
	)
	if birch then
		addBirchMarks(trunk, random)
	end

	-- Roots: wedges from the middle of the trunk that slope down to the ground outside it.
	local rootLength = width / 2 + cfg.RootLength * scale
	local rootHeight = cfg.RootHeight * scale
	local rootColor = Blocky.shade(barkColor, -0.12)
	for index = 1, cfg.RootCount do
		local turn = CFrame.Angles(0, (index - 1) / cfg.RootCount * math.pi * 2, 0)
		local root = Blocky.wedge(
			"Root",
			Vector3.new(width * 0.45, rootHeight, rootLength),
			origin * turn * CFrame.new(0, rootHeight / 2, -rootLength / 2),
			rootColor,
			Enum.Material.Wood,
			model
		)
		root.CanCollide = false
	end

	-- Bare branches for dead trees: blocks pointing out and up from inside the trunk.
	for _ = 1, treeType.Branches or 0 do
		local length = width / 2 + 3 * scale
		local thickness = width * 0.35
		local branch = Blocky.part(
			"Branch",
			Vector3.new(thickness, thickness, length),
			origin
				* CFrame.new(0, height * random:NextNumber(0.55, 0.8), 0)
				* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
				* CFrame.Angles(math.rad(35), 0, 0)
				* CFrame.new(0, 0, -length / 2),
			barkColor,
			Enum.Material.Wood,
			model
		)
		branch.CanCollide = false
	end

	if treeType.LeafBlocks > 0 then
		local leafColor = pick(treeType.LeafColors, random)
		local size = cfg.LeavesSize * scale * (if treeType.Branches then 0.55 elseif birch then 0.75 else 1)
		local center = base + Vector3.new(0, height + size * 0.15, 0)
		local leaves = Blocky.part(
			"Leaves",
			Vector3.one * size,
			CFrame.new(center) * CFrame.Angles(0, random:NextNumber(0, math.pi / 2), 0),
			leafColor,
			cfg.LeafMaterial,
			model
		)
		for _ = 2, treeType.LeafBlocks do
			local blockSize = size * random:NextNumber(0.55, 0.8)
			local offset = Vector3.new(
				random:NextNumber(-0.45, 0.45) * size,
				random:NextNumber(-0.25, 0.35) * size,
				random:NextNumber(-0.45, 0.45) * size
			)
			local block = Blocky.part(
				"LeafBlock",
				Vector3.one * blockSize,
				CFrame.new(center + offset)
					* CFrame.Angles(random:NextNumber(-0.1, 0.1), random:NextNumber(0, math.pi / 2), random:NextNumber(-0.1, 0.1)),
				Blocky.shade(leafColor, random:NextNumber(-0.12, 0.12)),
				cfg.LeafMaterial,
				model
			)
			-- Unanchored but welded to the anchored Leaves, so it follows Leaves around.
			block.Anchored = false
			block.CanCollide = false
			block.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = leaves
			weld.Part1 = block
			weld.Parent = block
		end
	end

	-- No PrimaryPart on purpose: with a PrimaryPart, Roblox ignores WorldPivot.
	model.WorldPivot = origin
	return model
end

-- One piece of a notched trunk: same colour and material as the trunk, never in the way.
-- A Blender trunk (a MeshPart) is cut into stretched bark blocks, so the pieces keep its bark.
local function trunkPiece(name: string, trunk: BasePart, tree: Model, wedge: boolean): BasePart
	local bark = if not wedge and trunk:IsA("MeshPart") then Assets.part(Config.Models.BarkBlock) else nil
	local piece: BasePart = bark or (if wedge then Instance.new("WedgePart") else Instance.new("Part"))
	piece.Name = name
	piece.Color = trunk.Color
	piece.Material = trunk.Material
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = tree
	return piece
end

local function getPiece(tree: Model, name: string): BasePart
	local piece = tree:FindFirstChild(name)
	assert(piece and piece:IsA("BasePart"), `notch piece {name} is missing`)
	return piece
end

-- Cut a V-shaped notch into a tree's trunk, `cut` deep (a part of the trunk's width, 0 to 1).
-- The first cut picks the side of the trunk that faces `outward`; later cuts deepen the same notch.
-- A part can't have a hole in it, so the first cut hides the real Trunk (it stays as the
-- tree's invisible body, which other code still uses) and draws the trunk again from five
-- pieces: a block below the notch, a block above it, a thinner block behind it, and two
-- wedges for the notch's light, freshly cut slopes.
-- Returns where the notch opens on the bark, facing out (for the chop effects).
-- Which side and how high come from Shared/ChopRules, so clients can work out the same spot.
function Blocky.notch(tree: Model, trunk: BasePart, outward: Vector3, cut: number): CFrame
	local cfg = Config.Tree
	local face = ChopRules.notchFace(tree, trunk, outward)
	if tree:GetAttribute("NotchFace") == nil then
		tree:SetAttribute("NotchFace", face)

		trunkPiece("TrunkBelow", trunk, tree, false)
		local above = trunkPiece("TrunkAbove", trunk, tree, false)
		local core = trunkPiece("TrunkCore", trunk, tree, false)
		Blocky.face(core, Enum.NormalId.Front, Config.Style.InnerWood)
		for _, name in { "NotchLower", "NotchUpper" } do
			local wedge = trunkPiece(name, trunk, tree, true)
			Blocky.face(wedge, Enum.NormalId.Top, Config.Style.InnerWood) -- a wedge's Top is its slope
		end
		-- Pictures on the trunk (birch marks) move to the big piece above the notch.
		for _, child in trunk:GetChildren() do
			if child:IsA("SurfaceGui") then
				child:Clone().Parent = above
				child.Enabled = false
			end
		end
		trunk.Transparency = 1
	end

	local width, height = trunk.Size.X, trunk.Size.Y
	local depth = width * math.clamp(cut, 0.05, 0.95)
	local opening = depth * cfg.NotchOpening
	-- The middle of the notch, measured from the trunk's centre.
	local middle = ChopRules.notchMiddle(trunk)

	-- The trunk's space turned so that -Z points out of the notched side.
	local space = trunk.CFrame * CFrame.lookAt(Vector3.zero, face)

	local belowHeight = middle - opening / 2 + height / 2
	local below = getPiece(tree, "TrunkBelow")
	below.Size = Vector3.new(width, belowHeight, width)
	below.CFrame = space * CFrame.new(0, -height / 2 + belowHeight / 2, 0)

	local aboveHeight = height / 2 - (middle + opening / 2)
	local above = getPiece(tree, "TrunkAbove")
	above.Size = Vector3.new(width, aboveHeight, width)
	above.CFrame = space * CFrame.new(0, height / 2 - aboveHeight / 2, 0)

	local core = getPiece(tree, "TrunkCore")
	core.Size = Vector3.new(width, opening, width - depth)
	core.CFrame = space * CFrame.new(0, middle, depth / 2)

	-- The lower wedge's slope faces up and out. The upper one is the same, upside down.
	local lower = getPiece(tree, "NotchLower")
	lower.Size = Vector3.new(width, opening / 2, depth)
	lower.CFrame = space * CFrame.new(0, middle - opening / 4, -width / 2 + depth / 2)
	local upper = getPiece(tree, "NotchUpper")
	upper.Size = lower.Size
	upper.CFrame = space * CFrame.new(0, middle + opening / 4, -width / 2 + depth / 2) * CFrame.Angles(0, 0, math.pi)

	return space * CFrame.new(0, middle, -width / 2)
end

-- A gable roof: two wedges meeting in a ridge that runs along X. `top` is the middle of
-- the walls' top.
function Blocky.roof(top: Vector3, width: number, depth: number, height: number, color: Color3, parent: Instance)
	local half = Vector3.new(width + 2, height, depth / 2 + 1)
	local offset = half.Z / 2
	-- Each wedge's front (the low side) points away from the ridge.
	Blocky.wedge("Roof", half, CFrame.new(top + Vector3.new(0, height / 2, -offset)), color, Enum.Material.WoodPlanks, parent)
	Blocky.wedge(
		"Roof",
		half,
		CFrame.new(top + Vector3.new(0, height / 2, offset)) * CFrame.Angles(0, math.pi, 0),
		color,
		Enum.Material.WoodPlanks,
		parent
	)
end

-- A log cabin standing on `ground`, its door and windows facing +Z (where players come from).
-- Returns the walls part.
function Blocky.cabin(name: string, ground: Vector3, size: Vector3, windows: number, parent: Instance): Part
	local style = Config.Style
	local walls = Blocky.part(
		name,
		size,
		CFrame.new(ground + Vector3.new(0, size.Y / 2, 0)),
		style.Wood,
		Enum.Material.WoodPlanks,
		parent
	)

	-- Dark lines between the logs on every wall.
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Blocky.face(walls, face)
		for line = 1, LOG_LINES do
			rect(gui, 0, line / (LOG_LINES + 1), 1, 0.025, style.DarkWood)
		end
		-- The +Z side (Back, in Roblox's names) gets a door and windows.
		if face == Enum.NormalId.Back then
			local door = rect(gui, 0.4, 0.35, 0.2, 0.65, Blocky.shade(style.DarkWood, -0.3))
			door.ZIndex = 2
			for index = 1, windows do
				local x = if index == 1 then 0.1 else 0.72
				local window = rect(gui, x, 0.35, 0.18, 0.28, style.Window)
				window.ZIndex = 2
				local frame = Instance.new("UIStroke")
				frame.Thickness = 5
				frame.Color = style.DarkWood
				frame.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				frame.Parent = window
			end
		end
	end

	-- Light log ends sticking out at the four corners.
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		local post = Blocky.part(
			"Corner",
			Vector3.new(1, size.Y, 1),
			CFrame.new(ground + Vector3.new(corner.X * size.X / 2, size.Y / 2, corner.Z * size.Z / 2)),
			Blocky.shade(style.Wood, 0.25),
			Enum.Material.Wood,
			parent
		)
		post.CanCollide = false
	end

	Blocky.roof(ground + Vector3.new(0, size.Y, 0), size.X, size.Z, size.X * 0.3, style.Roof, parent)
	return walls
end

-- A wooden sign board with big outlined text on both sides. `cframe` is its middle; its
-- faces point along the CFrame's Z axis.
function Blocky.sign(text: string, cframe: CFrame, width: number, height: number, textColor: Color3?, parent: Instance): Part
	local style = Config.Style
	local board =
		Blocky.part("Sign", Vector3.new(width, height, SIGN_DEPTH), cframe, style.Wood, Enum.Material.WoodPlanks, parent)
	board.CanCollide = false
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Blocky.face(board, face)
		local border = rect(gui, 0, 0, 1, 1, style.Wood)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 6
		stroke.Color = style.DarkWood
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = border
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.06, 0)
		padding.PaddingRight = UDim.new(0.06, 0)
		padding.PaddingTop = UDim.new(0.12, 0)
		padding.PaddingBottom = UDim.new(0.12, 0)
		padding.Parent = border
		Blocky.label(border, text, style.TitleFont, textColor)
	end
	return board
end

-- Yellow and black stripes around the edge of a flat pad (like a warning sign).
-- The stripes can't be touched, so they don't get in the way of the pad's Touched event.
function Blocky.hazardEdge(pad: BasePart, edgeWidth: number, parent: Instance)
	local style = Config.Style
	local size = pad.Size
	local height = 0.3
	local topY = size.Y / 2 + height / 2
	-- The front and back sides also cover the corners.
	local sides: { { Middle: Vector3, Length: number, Along: Vector3 } } = {
		{ Middle = Vector3.new(0, topY, size.Z / 2 + edgeWidth / 2), Length = size.X + edgeWidth * 2, Along = Vector3.xAxis },
		{ Middle = Vector3.new(0, topY, -size.Z / 2 - edgeWidth / 2), Length = size.X + edgeWidth * 2, Along = Vector3.xAxis },
		{ Middle = Vector3.new(size.X / 2 + edgeWidth / 2, topY, 0), Length = size.Z, Along = Vector3.zAxis },
		{ Middle = Vector3.new(-size.X / 2 - edgeWidth / 2, topY, 0), Length = size.Z, Along = Vector3.zAxis },
	}
	for _, side in sides do
		local middle, length, along = side.Middle, side.Length, side.Along
		local count = math.max(math.round(length / 1.5), 1)
		local stripe = length / count
		for index = 1, count do
			local offset = middle + along * ((index - 0.5) * stripe - length / 2)
			local blockSize = if along == Vector3.xAxis
				then Vector3.new(stripe, height, edgeWidth)
				else Vector3.new(edgeWidth, height, stripe)
			local block = Blocky.part(
				"Stripe",
				blockSize,
				pad.CFrame * CFrame.new(offset),
				if index % 2 == 0 then style.HazardBlack else style.HazardYellow,
				Enum.Material.SmoothPlastic,
				parent
			)
			block.CanCollide = false
			block.CanTouch = false
			block.CanQuery = false
		end
	end
end

return Blocky
