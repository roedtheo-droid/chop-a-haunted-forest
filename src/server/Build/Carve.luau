--!strict
-- Carving a tree's trunk, like in Chop a Forest (numbers in Config.Cut):
--   * Every hit scoops a round hole out of the trunk where the player aimed. Holes overlap, so
--     hitting the same spot makes one smooth, rounded dent that gets wider and deeper, and a hit
--     somewhere else starts a new dent there. Bigger tools scoop bigger holes.
--   * The trunk is made of layers, like a real one: a thin skin of bark, pale wood inside it, a
--     darker ring deeper in and a pale heart. So a dent shows a dark bark rim, then pale wood,
--     then the ring as it gets deep.
--   * At 0 HP the trunk is cut clean through at its deepest dent: everything below stays as the
--     stump (with its dents and a ringed top), and the top falls.
-- The holes are cut with Roblox's solid modelling (GeometryService:SubtractAsync), which gives
-- real round holes. A part can't be cut while you look at it, so each cut makes a new part that
-- replaces the old one. The real Trunk stays as the tree's invisible body, which other code
-- still uses; the layers are drawn over it, in the tree's "Carved" folder.
-- The server does the carving, so every player sees the same dents. It never changes the
-- damage: that's TreeManager's job. Used by TreeManager. It's not a system, so it has no init()/start().

local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local FINISH_TIMEOUT = 3 -- seconds Carve.finish waits for carving that's still going on, at most

-- A hole waiting to be cut, in the trunk's own space (so it's right even if the tree moves).
type Hole = {
	Offset: Vector3,
	Radius: number,
}

type State = {
	Trunk: BasePart,
	Folder: Folder, -- the layers, inside the tree
	Layers: { BasePart }, -- bark, pale wood, ring, heart (a layer cut away completely is gone)
	Waiting: { Hole }, -- holes not cut yet
	Cut: { Hole }, -- holes already cut (to find the deepest dent)
	Busy: boolean, -- true while holes are being cut
	Random: Random,
}

local Carve = {}

-- Each carved tree's state. Weak keys: a tree that's removed is forgotten by itself.
local states: { [Model]: State } = setmetatable({} :: { [Model]: State }, { __mode = "k" })

local function plainPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Cut `cutters` out of `part`. Returns the new pieces, placed where `part` is NOW (the tree may
-- have moved while it was cutting, like an awake mimic), each a copy of `part` in every other
-- way. The old part is removed. Returns nil (and keeps the old part) if cutting failed.
-- The faces a cut leaves get the cutters' colour, so the cutters are first painted in the
-- part's "CutColor" (the colour of the wood just inside it: dark for the bark, pale or ring
-- colour for the layers inside).
local function cut(part: BasePart, cutters: { BasePart }, splitApart: boolean): { BasePart }?
	local before = part.CFrame
	local inside = part:GetAttribute("CutColor")
	if typeof(inside) == "Color3" then
		for _, cutter in cutters do
			cutter.Color = inside
		end
	end
	local ok, result = pcall(function()
		return GeometryService:SubtractAsync(part, cutters, {
			SplitApart = splitApart,
			CollisionFidelity = Enum.CollisionFidelity.Box, -- the layers never collide, so keep it cheap
		})
	end)
	if not ok or typeof(result) ~= "table" or not part.Parent then
		return nil
	end
	local pieces: { BasePart } = {}
	for _, piece in result :: { Instance } do
		if piece:IsA("BasePart") then
			piece.Name = part.Name
			piece.CFrame = part.CFrame * before:ToObjectSpace(piece.CFrame)
			piece.Anchored = true
			piece.CanCollide = false
			piece.CanTouch = false
			piece.CastShadow = part.CastShadow
			for name, value in part:GetAttributes() do
				piece:SetAttribute(name, value)
			end
			for _, child in part:GetChildren() do
				if child:IsA("SurfaceGui") then
					child.Parent = piece -- birch marks
				end
			end
			piece.Parent = part.Parent
			table.insert(pieces, piece)
		end
	end
	part:Destroy()
	return pieces
end

-- Cut every waiting hole out of every layer, until none are left (more can arrive meanwhile:
-- they're cut together in the next round).
local function cutWaiting(state: State)
	state.Busy = true
	while #state.Waiting > 0 and state.Trunk.Parent do
		local holes = state.Waiting
		state.Waiting = {}
		local balls: { BasePart } = {}
		for _, hole in holes do
			local ball = plainPart(
				"Hole",
				Vector3.one * hole.Radius * 2,
				state.Trunk.CFrame * CFrame.new(hole.Offset),
				Color3.new(1, 1, 1),
				Enum.Material.Wood
			)
			ball.Shape = Enum.PartType.Ball
			table.insert(balls, ball)
		end
		local layers: { BasePart } = {}
		for _, layer in state.Layers do
			local pieces = cut(layer, balls, false)
			if not pieces then
				table.insert(layers, layer) -- couldn't cut it: keep it as it was
			elseif pieces[1] then
				table.insert(layers, pieces[1])
			end
			-- (no pieces: the holes took the whole layer, so it's gone)
		end
		state.Layers = layers
		for _, ball in balls do
			ball:Destroy()
		end
		table.move(holes, 1, #holes, #state.Cut + 1, state.Cut)
	end
	state.Busy = false
end

-- Get a tree ready for carving: hide the real trunk and draw it as layers. Each layer is a
-- hollow tube around the next one (so where a hole cuts through two layers, their cut faces
-- don't fight over who's in front), except the heart. Yields while it cuts the tubes.
local function getState(tree: Model, trunk: BasePart): State
	local existing = states[tree]
	if existing then
		return existing
	end
	local cfg = Config.Cut
	local folder = Instance.new("Folder")
	folder.Name = "Carved"
	folder.Parent = tree
	local state: State = {
		Trunk = trunk,
		Folder = folder,
		Layers = {},
		Waiting = {},
		Cut = {},
		Busy = true, -- until the layers are ready
		Random = Random.new(),
	}
	states[tree] = state

	local width, height = trunk.Size.X, trunk.Size.Y
	local widths = {
		width,
		width * (1 - cfg.BarkThickness * 2),
		width * cfg.RingWidth,
		width * cfg.HeartWidth,
	}
	local colors = { trunk.Color, cfg.InnerColors[1], cfg.InnerColors[2], cfg.InnerColors[1] }
	-- The colour of each layer's cut faces: the bark's are a darker bark (the dark rim around a
	-- dent), the others are the colour of that layer's wood.
	local cutColors = { trunk.Color:Lerp(Color3.new(0, 0, 0), cfg.RimShade), colors[2], colors[3], colors[4] }
	for index, layerWidth in widths do
		local layer = plainPart(
			`Layer{index}`,
			Vector3.new(layerWidth, height, layerWidth),
			trunk.CFrame,
			colors[index],
			Enum.Material.Wood
		)
		layer:SetAttribute("CutColor", cutColors[index])
		layer.Parent = folder
		local inner = widths[index + 1]
		if inner then
			-- Hollow it out (the hole is a bit taller, so the tube is open at both ends).
			local core = plainPart("Core", Vector3.new(inner, height + 1, inner), trunk.CFrame, colors[index], Enum.Material.Wood)
			local tube = cut(layer, { core }, false)
			core:Destroy()
			if tube and tube[1] then
				layer = tube[1]
			end
		end
		table.insert(state.Layers, layer)
	end
	-- Pictures on the trunk (birch marks) go on the bark.
	for _, child in trunk:GetChildren() do
		if child:IsA("SurfaceGui") then
			local copy = child:Clone()
			copy.Enabled = true
			copy.Parent = state.Layers[1]
			child.Enabled = false
		end
	end
	trunk.Transparency = 1
	state.Busy = false
	-- Hits that came in while the layers were being made are cut now.
	if #state.Waiting > 0 then
		task.spawn(cutWaiting, state)
	end
	return state
end

-- A hit at `point` (where the player aimed) scoops a round hole out of the trunk. `share` is
-- how much of the tree's HP the hit took (0.1 = a tenth): bigger hits scoop bigger holes.
-- The hole is cut in the background (it takes a moment), so this returns right away.
function Carve.hit(tree: Model, trunk: BasePart, point: Vector3, share: number)
	local cfg = Config.Cut
	local state = getState(tree, trunk)
	local scale = math.clamp((share * cfg.HitsPerTree) ^ (1 / 3), cfg.MinHoleScale, cfg.MaxHoleScale)
	local radius = trunk.Size.X * cfg.HoleSize * scale
	-- Aiming always finds the outside of the trunk (its invisible box), so we work out how deep
	-- to dig ourselves. `out` points from the middle of the trunk out to where you hit (flat).
	local offset = trunk.CFrame:PointToObjectSpace(point)
	local out = Vector3.new(offset.X, 0, offset.Z)
	out = if out.Magnitude > 0.01 then out.Unit else Vector3.zAxis
	-- A new dent: the hole's middle sits a little outside the bark, so it scoops a shallow bowl.
	local center = offset + out * radius * cfg.HoleOut
	-- Hitting a dent again digs it deeper: the deepest hole already on this line goes a step further in.
	local deepest: Hole? = nil
	for _, list in { state.Cut, state.Waiting } do
		for _, hole in list do
			local apart = hole.Offset - offset
			local sideways = (apart - out * apart:Dot(out)).Magnitude -- how far off the line in from where you hit
			if sideways < math.max(hole.Radius, radius) and (not deepest or hole.Offset:Dot(out) < deepest.Offset:Dot(out)) then
				deepest = hole
			end
		end
	end
	if deepest then
		local inward = deepest.Offset - out * radius * cfg.DigStep
		-- Never further in than almost through to the other side.
		local limit = -trunk.Size.X / 2 * cfg.MaxDepth
		center = inward - out * math.min(inward:Dot(out) - limit, 0)
	end
	local jitter = radius * cfg.HoleJitter
	local wobble = Vector3.new(
		state.Random:NextNumber(-jitter, jitter),
		state.Random:NextNumber(-jitter, jitter),
		state.Random:NextNumber(-jitter, jitter)
	)
	table.insert(state.Waiting, { Offset = center + wobble, Radius = radius })
	if not state.Busy then
		task.spawn(cutWaiting, state)
	end
end

-- Wait until every hole in this tree is cut (at most a few seconds). Call it before the tree
-- falls, so the falling tree's parts don't change under it.
function Carve.finish(tree: Model)
	local state = states[tree]
	local started = os.clock()
	while state and (state.Busy or #state.Waiting > 0) and os.clock() - started < FINISH_TIMEOUT do
		task.wait()
	end
end

-- Where the trunk was dug into the most: the height (studs above the bottom of the trunk)
-- with the most hole around it.
local function deepestHeight(state: State): number
	local trunk = state.Trunk
	local band = trunk.Size.X * 0.25 -- holes this close in height count as the same dent
	local amount: { [number]: number } = {}
	local best, bestAmount = nil :: number?, 0
	for _, hole in state.Cut do
		local slot = math.floor((hole.Offset.Y + trunk.Size.Y / 2) / band)
		amount[slot] = (amount[slot] or 0) + hole.Radius ^ 3
		if amount[slot] > bestAmount then
			best, bestAmount = slot, amount[slot]
		end
	end
	local height = if best then (best + 0.5) * band else trunk.Size.Y * 0.2
	return math.clamp(height, 0.3, trunk.Size.Y * 0.8)
end

-- A felled tree breaks at its deepest dent: every layer is cut in two there (a copy of it loses
-- everything above the break and becomes part of a "Stump" model in `stumpParent`; the layer
-- itself loses everything below and stays in the tree). Returns the height it broke at (studs
-- above the bottom of the trunk; the falling top turns around there), or nil if the tree was
-- never carved. Yields while it cuts (call Carve.finish first).
function Carve.split(tree: Model, stumpParent: Instance): number?
	local state = states[tree]
	if not state then
		return nil
	end
	local trunk = state.Trunk
	local height = deepestHeight(state)
	local gap = Config.Cut.SplitGap
	local breakY = height - trunk.Size.Y / 2 -- in the trunk's own space
	local bigSize = Vector3.new(trunk.Size.X * 3, trunk.Size.Y * 2, trunk.Size.Z * 3)
	local above = plainPart("Above", bigSize, trunk.CFrame * CFrame.new(0, breakY + gap / 2 + trunk.Size.Y, 0), Color3.new(1, 1, 1), Enum.Material.Wood)
	local below = plainPart("Below", bigSize, trunk.CFrame * CFrame.new(0, breakY - gap / 2 - trunk.Size.Y, 0), Color3.new(1, 1, 1), Enum.Material.Wood)
	local stump = Instance.new("Model")
	stump.Name = "Stump"
	for _, layer in state.Layers do
		local bottom = layer:Clone()
		bottom.Parent = layer.Parent
		local pieces = cut(bottom, { above }, false)
		if pieces and pieces[1] then
			pieces[1].Parent = stump
		end
		cut(layer, { below }, false)
	end
	above:Destroy()
	below:Destroy()
	if #stump:GetChildren() > 0 then
		stump.Parent = stumpParent
	else
		stump:Destroy()
	end
	states[tree] = nil
	return height
end

return Carve
