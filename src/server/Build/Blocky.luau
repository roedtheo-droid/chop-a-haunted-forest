--!strict
-- Helpers that build the blocky, cartoony look (see STYLE_GUIDE.md) out of plain parts:
-- trees, log cabins, gable roofs, wooden signs, striped pad edges and wood rings.
-- No art needed: everything is Parts, colours and a little SurfaceGui.
-- Used by ForestSpawner, SceneryManager, SawmillManager, ShopManager, ZoneManager,
-- TreeManager, LogManager and BossManager. It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local PIXELS_PER_STUD = 25 -- how sharp SurfaceGui pictures on parts are
local LOG_LINES = 6 -- dark lines between the logs on each cabin wall
local SIGN_DEPTH = 0.4

local Blocky = {}

-- A plain anchored part.
function Blocky.part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
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
local function rect(parent: Instance, x: number, y: number, w: number, h: number, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.Parent = parent
	return frame
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

-- Short dark marks on all four sides of a birch trunk. They're drawn with scale numbers,
-- so they shrink along with the trunk when it's chopped.
local function addBirchMarks(trunk: BasePart, random: Random)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Blocky.face(trunk, face)
		for _ = 1, Config.Tree.BirchMarks do
			local width = random:NextNumber(0.3, 0.6)
			rect(gui, random:NextNumber(0, 1 - width), random:NextNumber(0.05, 0.95), width, 0.018, Config.Style.BirchMark)
		end
	end
end

-- A blocky tree with its pivot at `base` (the bottom of the trunk), not yet parented.
-- Parts: "Trunk" (a square block), "Root" wedges at its foot, maybe "Branch" blocks, and a
-- crown: the biggest leaf block is "Leaves", the others ("LeafBlock") are welded to it,
-- so moving Leaves by its CFrame (a mimic's "Sway" tell) moves the whole crown.
-- The trunk isn't turned, so its faces line up with the model's pivot (mimic eyes rely on that).
function Blocky.tree(base: Vector3, treeType: Types.TreeTypeConfig, random: Random, extraScale: number?): Model
	local cfg = Config.Tree
	local scale = treeType.Scale * (extraScale or 1)
	local birch = random:NextNumber() < (treeType.BirchChance or 0)
	-- Birches are a bit taller and thinner.
	local height = cfg.TrunkHeight * scale * (if birch then 1.15 else 1)
	local width = cfg.TrunkWidth * scale * (if birch then 0.8 else 1)
	local barkColor = if birch and treeType.BirchColor then treeType.BirchColor else pick(treeType.TrunkColors, random)
	local origin = CFrame.new(base)

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
	-- They start in the middle, so they still touch the trunk when it gets thinner.
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
