--!strict
-- Swing rules that the server and the client both need, kept in ONE place so they agree.
-- The server uses them to decide if a swing counts and where a hit carves the trunk
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

return table.freeze(ChopRules)
