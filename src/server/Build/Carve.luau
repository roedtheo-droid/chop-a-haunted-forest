--!strict
-- Carving a tree's trunk, like in Chop a Forest (numbers in Config.Cut, shared rules in
-- Shared/ChopRules):
--   * Wherever a player hits a trunk, that part of it (a band of layers around the hit) turns
--     into small blocks: bark ones on the outside, pale wood in rings inside.
--   * Every hit knocks out the blocks closest to where the player aimed, so the same spot gets
--     a wider and deeper dent each time, and a hit somewhere else starts a new dent there.
--   * At 0 HP the tree breaks at its deepest dent: that layer pops out, everything below stays
--     as the stump (with its dents and a pale, ringed top), and the top falls.
-- A part can't have a hole in it, so the first hit hides the real Trunk (it stays as the
-- tree's invisible body, which other code still uses) and draws the trunk again: blocks in the
-- bands, and plain trunk pieces between them.
-- The server does the carving, so every player sees the same dents. It never changes the
-- damage: that's TreeManager's job. Used by TreeManager. It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChopRules = require(ReplicatedStorage.Shared.ChopRules)
local Config = require(ReplicatedStorage.Shared.Config)
local Assets = require(script.Parent.Assets)

-- A block that was knocked out: every player's computer throws a copy of it (see
-- Client/Controllers/ChopEffectsController).
export type Chunk = {
	Key: number,
	Position: Vector3,
	Color: Color3,
}

-- A plain piece of trunk between the bands, covering layers From to To.
type Solid = {
	Part: BasePart,
	From: number,
	To: number,
}

type State = {
	Trunk: BasePart,
	Grid: ChopRules.Grid,
	Folder: Folder, -- the blocks and pieces, inside the tree
	Blocks: { [number]: BasePart }, -- the blocks still there, by key
	Banded: { [number]: boolean }, -- the layers that are blocks
	Solids: { Solid },
	Knocked: { [number]: number }, -- how many blocks each layer has lost
	Random: Random,
}

local Carve = {}

-- Each carved tree's state. Weak keys: a tree that's removed is forgotten by itself.
local states: { [Model]: State } = setmetatable({} :: { [Model]: State }, { __mode = "k" })

-- A plain piece of trunk: same colour and material as the trunk, never in the way.
-- A Blender trunk (a MeshPart) is drawn with stretched bark blocks, so the pieces keep its bark.
local function trunkPiece(trunk: BasePart, parent: Instance): BasePart
	local bark = if trunk:IsA("MeshPart") then Assets.part(Config.Models.BarkBlock) else nil
	local piece: BasePart = bark or Instance.new("Part")
	piece.Name = "TrunkPiece"
	piece.Color = trunk.Color
	piece.Material = trunk.Material
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	-- Pictures on the trunk (birch marks) go on every piece.
	for _, child in trunk:GetChildren() do
		if child:IsA("SurfaceGui") then
			local copy = child:Clone()
			copy.Enabled = true
			copy.Parent = piece
		end
	end
	piece.Parent = parent
	return piece
end

-- A block's colour: bark on the outside (a little lighter or darker each), rings of pale wood inside.
local function blockColor(state: State, x: number, z: number): Color3
	local cfg = Config.Cut
	local last = state.Grid.Across - 1
	local ring = math.min(x, z, last - x, last - z) -- 0 on the outside, 1 just inside...
	if ring == 0 then
		local shade = state.Random:NextNumber(-cfg.BarkShade, cfg.BarkShade)
		local bark = state.Trunk.Color
		return if shade >= 0 then bark:Lerp(Color3.new(1, 1, 1), shade) else bark:Lerp(Color3.new(0, 0, 0), -shade)
	end
	return cfg.InnerColors[(ring - 1) % #cfg.InnerColors + 1]
end

-- Draw the plain trunk again between the bands of blocks (after a new band was added).
local function rebuildSolids(state: State)
	for _, solid in state.Solids do
		solid.Part:Destroy()
	end
	table.clear(state.Solids)
	local trunk = state.Trunk
	local grid = state.Grid
	local layer = 0
	while layer < grid.Layers do
		if state.Banded[layer] then
			layer += 1
			continue
		end
		local from = layer
		while layer + 1 < grid.Layers and not state.Banded[layer + 1] do
			layer += 1
		end
		local count = layer - from + 1
		local piece = trunkPiece(trunk, state.Folder)
		piece.Size = Vector3.new(trunk.Size.X, count * grid.LayerHeight, trunk.Size.Z)
		piece.CFrame = trunk.CFrame * CFrame.new(0, -trunk.Size.Y / 2 + grid.LayerHeight * (from + count / 2), 0)
		table.insert(state.Solids, { Part = piece, From = from, To = layer })
		layer += 1
	end
end

-- Get a tree ready for carving: hide the real trunk and draw it as one plain piece.
local function getState(tree: Model, trunk: BasePart): State
	local existing = states[tree]
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Carved"
	folder.Parent = tree
	local state: State = {
		Trunk = trunk,
		Grid = ChopRules.grid(trunk),
		Folder = folder,
		Blocks = {},
		Banded = {},
		Solids = {},
		Knocked = {},
		Random = Random.new(),
	}
	states[tree] = state
	rebuildSolids(state)
	trunk.Transparency = 1
	trunk.CanQuery = false -- aiming now finds the blocks and pieces, so you can aim into a dent
	for _, child in trunk:GetChildren() do
		if child:IsA("SurfaceGui") then
			child.Enabled = false
		end
	end
	return state
end

-- Turn the layers around `layer` into blocks (the ones that aren't yet).
local function addBand(state: State, layer: number)
	local grid = state.Grid
	local trunk = state.Trunk
	local reach = Config.Cut.BandLayers
	local added = false
	for band = math.max(layer - reach, 0), math.min(layer + reach, grid.Layers - 1) do
		if state.Banded[band] then
			continue
		end
		state.Banded[band] = true
		added = true
		for x = 0, grid.Across - 1 do
			for z = 0, grid.Across - 1 do
				local key = ChopRules.blockKey(grid, band, x, z)
				local block = Instance.new("Part")
				block.Name = `Block{key}`
				block.Size = Vector3.new(grid.Size, grid.LayerHeight, grid.Size)
				block.CFrame = trunk.CFrame * CFrame.new(ChopRules.blockOffset(trunk, grid, band, x, z))
				block.Color = blockColor(state, x, z)
				block.Material = Enum.Material.Wood
				block.TopSurface = Enum.SurfaceType.Smooth
				block.BottomSurface = Enum.SurfaceType.Smooth
				block.Anchored = true
				block.CanCollide = false
				block.CanTouch = false
				block.Parent = state.Folder
				state.Blocks[key] = block
			end
		end
	end
	if added then
		rebuildSolids(state)
	end
end

local function knockOut(state: State, key: number, chunks: { Chunk })
	local block = state.Blocks[key]
	if not block then
		return
	end
	table.insert(chunks, { Key = key, Position = block.Position, Color = block.Color })
	block:Destroy()
	state.Blocks[key] = nil
	local layer = ChopRules.blockFromKey(state.Grid, key)
	state.Knocked[layer] = (state.Knocked[layer] or 0) + 1
end

-- A hit at `point` (where the player aimed) knocks `count` blocks out of the trunk.
-- Returns the blocks that were knocked out.
function Carve.hit(tree: Model, trunk: BasePart, point: Vector3, count: number): { Chunk }
	local state = getState(tree, trunk)
	addBand(state, ChopRules.layerAt(trunk, state.Grid, point))
	local blocks = {}
	for key, block in state.Blocks do
		table.insert(blocks, { Key = key, Position = block.Position })
	end
	local chunks: { Chunk } = {}
	for _, key in ChopRules.pickBlocks(blocks, point, count) do
		knockOut(state, key, chunks)
	end
	return chunks
end

-- A felled tree breaks at its deepest dent (the layer that lost the most blocks): the rest of
-- that layer pops out, and everything below it moves into a "Stump" model in `stumpParent`.
-- Returns the height it broke at (studs above the bottom of the trunk, the middle of that
-- layer: the falling top turns around there) and the blocks that popped out.
-- Returns nil if the tree was never carved.
function Carve.split(tree: Model, stumpParent: Instance): (number?, { Chunk })
	local state = states[tree]
	if not state then
		return nil, {}
	end
	local grid = state.Grid
	local split: number? = nil
	for layer, knocked in state.Knocked do
		local best = if split then state.Knocked[split] else 0
		if knocked > best or (knocked == best and split ~= nil and layer < split) then
			split = layer
		end
	end
	if not split then
		return nil, {}
	end

	local chunks: { Chunk } = {}
	for x = 0, grid.Across - 1 do
		for z = 0, grid.Across - 1 do
			knockOut(state, ChopRules.blockKey(grid, split, x, z), chunks)
		end
	end

	-- Everything below the break stays behind as the stump.
	local stump = Instance.new("Model")
	stump.Name = "Stump"
	for key, block in state.Blocks do
		if ChopRules.blockFromKey(grid, key) < split then
			block.Parent = stump
		end
	end
	for _, solid in state.Solids do
		if solid.To < split then
			solid.Part.Parent = stump
		end
	end
	if #stump:GetChildren() > 0 then
		stump.Parent = stumpParent
	else
		stump:Destroy()
	end
	states[tree] = nil
	return (split + 0.5) * grid.LayerHeight, chunks
end

return Carve
