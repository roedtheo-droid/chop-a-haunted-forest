--!strict
-- Draws carved trunks on this computer (rules in Shared/Carving, numbers in Config.Cut).
-- The server decides where each hit bites a hole and keeps the list on the tree (the "Holes"
-- attribute). This cuts the holes here, from that same list, so every player sees the same dents
-- and nothing heavy goes over the network:
--   * The first hole hides the real trunk (only on this screen) and draws it again as layers:
--     bark, pale wood, a darker ring and a pale heart. Each is a hollow tube around the next one,
--     so where a hole cuts through two layers, their cut faces don't fight over who's in front.
--   * Every hole is cut out of every layer with Roblox's solid modelling
--     (GeometryService:SubtractAsync). A part can't be cut while you look at it, so each cut
--     makes a new part that replaces the old one.
--   * When the tree falls it breaks at its deepest dent (breakTree): the bottom of each layer
--     becomes the stump, and the top falls with the tree.
--   * Stumps from trees we didn't carve (because we joined later) are drawn from the server's
--     "Stump" model, which has the holes and the height it broke at.
-- Only for looks: the server decides every hit.

local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Carving = require(ReplicatedStorage.Shared.Carving)
local Config = require(ReplicatedStorage.Shared.Config)

local WAIT_LIMIT = 2 -- seconds breakTree waits for holes that are still being cut, or for the stump

type State = {
	Tree: Model,
	Trunk: BasePart,
	Folder: Folder, -- our layers, inside the tree (only on this computer)
	Layers: { BasePart }, -- bark, pale wood, ring, heart (a layer cut away completely is gone)
	Done: number, -- how many of the tree's holes are cut
	Busy: boolean, -- true while cutting
	Broken: boolean, -- true once breakTree has broken it
}

local CarveController = {}

-- Each carved tree's state. Weak keys: a tree that's removed is forgotten by itself.
local states: { [Model]: State } = setmetatable({} :: { [Model]: State }, { __mode = "k" })
-- Stumps that already have their carved pieces (broken here, or drawn from the server's data).
local drawnStumps: { [Model]: boolean } = setmetatable({} :: { [Model]: boolean }, { __mode = "k" })
local stumpsFolder: Instance

local function plainPart(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Wood
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false -- clicks go through to the tree's invisible trunk
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Cut `cutters` out of `part` and return the new part (nil if nothing is left, or the old part
-- if cutting failed). It's placed where `part` is NOW (the tree may have moved meanwhile, like an
-- awake mimic) and is a copy of it in every other way. The faces a cut leaves get the cutters'
-- colour, so they're painted in the part's "CutColor" first.
local function cut(part: BasePart, cutters: { BasePart }): BasePart?
	local before = part.CFrame
	local inside = part:GetAttribute("CutColor")
	if typeof(inside) == "Color3" then
		for _, cutter in cutters do
			cutter.Color = inside
		end
	end
	local ok, result = pcall(function()
		return GeometryService:SubtractAsync(part, cutters, {
			SplitApart = false,
			CollisionFidelity = Enum.CollisionFidelity.Box, -- never collides, so keep it cheap
		})
	end)
	if not ok or typeof(result) ~= "table" then
		return part
	end
	if not part.Parent then
		return nil -- the tree was removed while we were cutting
	end
	local piece = (result :: { Instance })[1]
	if not (piece and piece:IsA("BasePart")) then
		part:Destroy()
		return nil
	end
	piece.Name = part.Name
	piece.CFrame = part.CFrame * before:ToObjectSpace(piece.CFrame)
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	for name, value in part:GetAttributes() do
		piece:SetAttribute(name, value)
	end
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceGui") then
			child.Parent = piece -- birch marks
		end
	end
	piece.Parent = part.Parent
	part:Destroy()
	return piece
end

-- Draw a trunk (`size`, at `cframe`) as layers in `parent`. `marks` holds pictures for the bark
-- (birch marks). Yields while it cuts the tubes.
local function buildLayers(parent: Instance, cframe: CFrame, size: Vector3, barkColor: Color3, marks: Instance): { BasePart }
	local specs = Carving.layers(size.X, barkColor)
	local layers: { BasePart } = {}
	for index, spec in specs do
		local layer: BasePart = plainPart(`Layer{index}`, Vector3.new(spec.Width, size.Y, spec.Width), cframe, spec.Color)
		layer:SetAttribute("CutColor", spec.CutColor)
		layer.Parent = parent
		local inner = specs[index + 1]
		if inner then
			-- Hollow it out (the hole is a bit taller, so the tube is open at both ends).
			local core = plainPart("Core", Vector3.new(inner.Width, size.Y + 1, inner.Width), cframe, spec.Color)
			layer = cut(layer, { core }) or layer
			core:Destroy()
		end
		table.insert(layers, layer)
	end
	for _, child in marks:GetChildren() do
		if child:IsA("SurfaceGui") then
			local copy = child:Clone()
			copy.Enabled = true
			copy.Parent = layers[1]
		end
	end
	return layers
end

-- Cut `holes` out of every layer of a trunk at `cframe`. Returns the layers that are left.
local function cutHoles(layers: { BasePart }, cframe: CFrame, holes: { Carving.Hole }): { BasePart }
	local cutters: { BasePart } = {}
	for _, hole in holes do
		for _, bit in Carving.bits(hole) do
			local cutter = plainPart("Hole", bit.Size, cframe * bit.Place, Color3.new(1, 1, 1))
			if bit.Round then
				cutter.Shape = Enum.PartType.Ball
			end
			table.insert(cutters, cutter)
		end
	end
	local left: { BasePart } = {}
	for _, layer in layers do
		local piece = cut(layer, cutters)
		if piece then
			table.insert(left, piece)
		end
	end
	for _, cutter in cutters do
		cutter:Destroy()
	end
	return left
end

-- Cut the layers of a trunk (`size`, at `cframe`) in two at `height` (studs above its bottom):
-- returns the parts above and below (a copy of each layer becomes the bottom one).
local function splitLayers(layers: { BasePart }, cframe: CFrame, size: Vector3, height: number): ({ BasePart }, { BasePart })
	local gap = Config.Cut.SplitGap
	local breakY = height - size.Y / 2 -- in the trunk's own space
	local bigSize = Vector3.new(size.X * 3, size.Y * 2, size.Z * 3)
	local above = plainPart("Above", bigSize, cframe * CFrame.new(0, breakY + gap / 2 + size.Y, 0), Color3.new(1, 1, 1))
	local below = plainPart("Below", bigSize, cframe * CFrame.new(0, breakY - gap / 2 - size.Y, 0), Color3.new(1, 1, 1))
	local tops: { BasePart } = {}
	local bottoms: { BasePart } = {}
	for _, layer in layers do
		local copy = layer:Clone()
		copy.Parent = layer.Parent
		local bottom = cut(copy, { above })
		if bottom then
			table.insert(bottoms, bottom)
		end
		local top = cut(layer, { below })
		if top then
			table.insert(tops, top)
		end
	end
	above:Destroy()
	below:Destroy()
	return tops, bottoms
end

local function getState(tree: Model, trunk: BasePart): State
	local existing = states[tree]
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "CarvedHere"
	folder.Parent = tree
	local state: State = {
		Tree = tree,
		Trunk = trunk,
		Folder = folder,
		Layers = {},
		Done = 0,
		Busy = false,
		Broken = false,
	}
	states[tree] = state
	return state
end

-- Cut the tree's holes that aren't cut yet (more can arrive meanwhile: they're cut next round).
local function update(state: State)
	if state.Busy or state.Broken then
		return
	end
	state.Busy = true
	while state.Tree.Parent and not state.Broken do
		local text = state.Tree:GetAttribute("Holes")
		local holes = Carving.decode(if typeof(text) == "string" then text else "")
		if #holes <= state.Done then
			break
		end
		local trunk = state.Trunk
		if #state.Layers == 0 and state.Done == 0 then
			state.Layers = buildLayers(state.Folder, trunk.CFrame, trunk.Size, trunk.Color, trunk)
			-- Hide the real trunk and its pictures on this screen: the layers are drawn instead.
			trunk.LocalTransparencyModifier = 1
			for _, child in trunk:GetChildren() do
				if child:IsA("SurfaceGui") then
					child.Enabled = false
				end
			end
		end
		local new = table.move(holes, state.Done + 1, #holes, 1, {})
		state.Done = #holes
		state.Layers = cutHoles(state.Layers, trunk.CFrame, new)
	end
	state.Busy = false
end

local function watchTree(tree: Instance)
	if not tree:IsA("Model") then
		return
	end
	local function changed()
		local trunk = tree:FindFirstChild("Trunk")
		if trunk and trunk:IsA("BasePart") and tree:GetAttribute("Holes") then
			task.spawn(update, getState(tree, trunk))
		end
	end
	tree:GetAttributeChangedSignal("Holes"):Connect(changed)
	changed()
end

-- The server's "Stump" model for `tree` (it's made just before the tree starts to fall).
local function findStump(tree: Model): Model?
	local started = os.clock()
	while os.clock() - started < WAIT_LIMIT do
		for _, stump in stumpsFolder:GetChildren() do
			local link = stump:FindFirstChild("Tree")
			if stump:IsA("Model") and link and link:IsA("ObjectValue") and link.Value == tree then
				return stump
			end
		end
		task.wait()
	end
	return nil
end

-- A felled tree breaks at its deepest dent (`height`, studs above the bottom of the trunk):
-- each layer is cut in two, the bottoms become the stump (inside the server's Stump model, so
-- they go when it goes) and the tops stay in the tree and fall with it. Yields until it's done:
-- call it before the fall starts.
function CarveController.breakTree(tree: Model, height: number)
	local state = states[tree]
	if not state then
		return
	end
	local started = os.clock()
	while state.Busy and os.clock() - started < WAIT_LIMIT do
		task.wait()
	end
	if state.Broken or #state.Layers == 0 then
		return
	end
	state.Broken = true
	local trunk = state.Trunk
	local tops, bottoms = splitLayers(state.Layers, trunk.CFrame, trunk.Size, height)
	state.Layers = tops
	local stump = findStump(tree)
	if stump and drawnStumps[stump] then
		for _, bottom in bottoms do
			bottom:Destroy() -- already drawn from the server's data
		end
		return
	end
	local model = Instance.new("Model")
	model.Name = "CarvedHere"
	for _, bottom in bottoms do
		bottom.Parent = model
	end
	model.Parent = stump or state.Folder
	if stump then
		drawnStumps[stump] = true
	end
end

-- A stump from the server: draw it from its data, unless we're breaking the tree ourselves.
local function onStumpAdded(stump: Instance)
	if not (stump:IsA("Model") and stump.Name == "Stump") then
		return
	end
	local body = stump:WaitForChild("Body", 5)
	if not (body and body:IsA("BasePart")) then
		return
	end
	local link = stump:FindFirstChild("Tree")
	local tree = if link and link:IsA("ObjectValue") then link.Value else nil
	local state = if tree and tree:IsA("Model") then states[tree] else nil
	if state and (#state.Layers > 0 or state.Busy) then
		return -- breakTree puts our own carved bottom in it
	end
	local text = body:GetAttribute("Holes")
	local height = body:GetAttribute("BreakHeight")
	local bark = body:GetAttribute("BarkColor")
	if typeof(text) ~= "string" or typeof(height) ~= "number" or typeof(bark) ~= "Color3" or drawnStumps[stump] then
		return
	end
	drawnStumps[stump] = true
	local model = Instance.new("Model")
	model.Name = "CarvedHere"
	model.Parent = stump
	local layers = buildLayers(model, body.CFrame, body.Size, bark, body)
	layers = cutHoles(layers, body.CFrame, Carving.decode(text))
	local tops = splitLayers(layers, body.CFrame, body.Size, height)
	for _, top in tops do
		top:Destroy() -- only the bottom is the stump
	end
end

function CarveController.init() end

function CarveController.start()
	local trees = workspace:WaitForChild("Trees")
	trees.ChildAdded:Connect(watchTree)
	for _, tree in trees:GetChildren() do
		watchTree(tree)
	end
	stumpsFolder = workspace:WaitForChild("Stumps")
	stumpsFolder.ChildAdded:Connect(function(stump)
		task.spawn(onStumpAdded, stump)
	end)
	for _, stump in stumpsFolder:GetChildren() do
		task.spawn(onStumpAdded, stump)
	end
end

return CarveController
