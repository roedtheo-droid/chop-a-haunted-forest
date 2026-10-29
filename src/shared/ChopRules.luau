--!strict
-- Swing rules that the server and the client both need, kept in ONE place so they agree.
-- The server uses them to decide if a swing counts and which blocks a hit knocks out
-- (see Server/Systems/TreeManager and Server/Build/Carve). The client uses the same rules
-- to show your hit right away, in the right spot, without waiting for the server
-- (see Client/Controllers/ChopController).
--
-- You aim at a tree, and the client sends the point on the trunk where your crosshair hit it.
-- The server never just believes that point: it checks it's really on that trunk and close to
-- your head. The point only decides where the trunk gets carved, never the damage.

local Config = require(script.Parent.Config)

local ChopRules = {}

-- Can a player standing at `rootPosition` reach `target` with this tool?
-- Reach is measured flat (height doesn't count), from the player to the trunk's edge.
-- (Used for the Elder Hollow and its roots; trees use pointInReach below.)
function ChopRules.inReach(rootPosition: Vector3, target: Model, toolId: string): boolean
	local tool = Config.Tools[toolId]
	if not tool then
		return false
	end
	local base = target:GetPivot().Position
	local flatDistance = Vector2.new(rootPosition.X - base.X, rootPosition.Z - base.Z).Magnitude
	local width = target:GetAttribute("TrunkWidth")
	local halfWidth = if typeof(width) == "number" then width / 2 else 0
	return flatDistance <= tool.Reach + halfWidth
end

-- Is `point` a real point (not NaN or miles away)? The client could send anything.
function ChopRules.isRealPoint(point: unknown): boolean
	if typeof(point) ~= "Vector3" then
		return false
	end
	local p = point :: Vector3
	for _, value in { p.X, p.Y, p.Z } do
		if value ~= value or math.abs(value) > 1e6 then -- NaN is the only number that isn't equal to itself
			return false
		end
	end
	return true
end

-- Is `point` on the trunk: inside its box, or at most Config.Cut.PointMargin outside it?
function ChopRules.pointOnTrunk(trunk: BasePart, point: Vector3): boolean
	local margin = Config.Cut.PointMargin
	local offset = trunk.CFrame:PointToObjectSpace(point)
	local half = trunk.Size / 2
	return math.abs(offset.X) <= half.X + margin
		and math.abs(offset.Y) <= half.Y + margin
		and math.abs(offset.Z) <= half.Z + margin
end

-- Can a player whose head is at `headPosition` hit `point` with this tool?
function ChopRules.pointInReach(headPosition: Vector3, point: Vector3, toolId: string): boolean
	local tool = Config.Tools[toolId]
	if not tool then
		return false
	end
	return (headPosition - point).Magnitude <= tool.Reach + Config.Cut.HeadReachExtra
end

-- Which way the side of the trunk that `point` is on faces (out of the trunk, in the world).
-- The chips and the glow of a hit come out of that side.
function ChopRules.sideFacing(trunk: BasePart, point: Vector3): Vector3
	local offset = trunk.CFrame:PointToObjectSpace(point)
	local side = if math.abs(offset.X) > math.abs(offset.Z)
		then Vector3.new(math.sign(offset.X), 0, 0)
		else Vector3.new(0, 0, if offset.Z >= 0 then 1 else -1)
	return trunk.CFrame:VectorToWorldSpace(side)
end

---------------------------------------------------------------------------
-- Carving: where you hit a trunk, it turns into small blocks, and every hit knocks out the
-- blocks closest to where you aimed (see Server/Build/Carve). The client uses the same rules
-- to knock your blocks out the moment your swing lands.
---------------------------------------------------------------------------

-- How a trunk is split into blocks: Across blocks each way, in layers of about the same height.
export type Grid = {
	Across: number,
	Size: number, -- a block's width and depth
	Layers: number,
	LayerHeight: number,
}

function ChopRules.grid(trunk: BasePart): Grid
	local across = Config.Cut.Across
	local size = trunk.Size.X / across
	local layers = math.max(math.round(trunk.Size.Y / size), 1)
	return { Across = across, Size = size, Layers = layers, LayerHeight = trunk.Size.Y / layers }
end

-- Each block has a number (its "key") made from its layer (0 at the bottom) and its column
-- (0 to Across - 1 each way). Blocks are named "Block<key>".
function ChopRules.blockKey(grid: Grid, layer: number, x: number, z: number): number
	return (layer * grid.Across + x) * grid.Across + z
end

function ChopRules.blockFromKey(grid: Grid, key: number): (number, number, number)
	local z = key % grid.Across
	local rest = (key - z) // grid.Across
	local x = rest % grid.Across
	return (rest - x) // grid.Across, x, z
end

-- Where a block's middle is, in the trunk's own space.
function ChopRules.blockOffset(trunk: BasePart, grid: Grid, layer: number, x: number, z: number): Vector3
	local size = trunk.Size
	return Vector3.new(
		-size.X / 2 + grid.Size * (x + 0.5),
		-size.Y / 2 + grid.LayerHeight * (layer + 0.5),
		-size.Z / 2 + grid.Size * (z + 0.5)
	)
end

-- The layer a point on the trunk is in.
function ChopRules.layerAt(trunk: BasePart, grid: Grid, point: Vector3): number
	local height = trunk.CFrame:PointToObjectSpace(point).Y + trunk.Size.Y / 2
	return math.clamp(math.floor(height / grid.LayerHeight), 0, grid.Layers - 1)
end

-- How much damage a tool does for a player with this many Chop Damage upgrade levels.
-- (The server works this out itself; the client only uses it to guess how many blocks go.)
function ChopRules.damage(toolId: string, chopDamageLevel: number): number
	return Config.Tools[toolId].Damage * (1 + chopDamageLevel * Config.Upgrades.ChopDamage.PerLevel)
end

-- How many blocks a hit knocks out. A tree loses Config.Cut.BlocksPerTree blocks on its way
-- from full HP to 0, so bigger tools knock out more per hit.
function ChopRules.blocksPerHit(damage: number, maxHp: number): number
	local cfg = Config.Cut
	return math.clamp(math.round(cfg.BlocksPerTree * damage / math.max(maxHp, 1)), 1, cfg.MaxBlocksPerHit)
end

-- The `count` blocks closest to `point` (where you aimed), so the same spot gets a wider and
-- deeper dent with every hit. `blocks` are the blocks still there. Returns their keys.
function ChopRules.pickBlocks(blocks: { { Key: number, Position: Vector3 } }, point: Vector3, count: number): { number }
	local sorted = table.clone(blocks)
	local distance: { [number]: number } = {}
	for _, block in sorted do
		distance[block.Key] = (block.Position - point).Magnitude
	end
	table.sort(sorted, function(a, b)
		local da, db = distance[a.Key], distance[b.Key]
		if math.abs(da - db) > 1e-4 then
			return da < db
		end
		return a.Key < b.Key -- the same choice on every computer
	end)
	local keys = {}
	for index = 1, math.min(count, #sorted) do
		table.insert(keys, sorted[index].Key)
	end
	return keys
end

return table.freeze(ChopRules)
