--!strict
-- Swing rules that the server and the client both need, kept in ONE place so they agree.
-- The server uses them to decide if a swing counts and where the cut goes
-- (see Server/Systems/TreeManager and Server/Build/Blocky). The client uses the same rules
-- to show your hit right away, in the right spot, without waiting for the server
-- (see Client/Controllers/ChopController).
--
-- You aim at a tree, and the client sends the point on the trunk where your crosshair hit it.
-- The server never just believes that point: it checks it's really on that trunk and close to
-- your head, and keeps the cut between a lowest and highest height (Config.Cut).

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

-- Which side of the trunk the cut is on, in the trunk's own space (like (0, 0, -1)).
-- After the first hit that's the side the cut already has (the "CutFace" attribute);
-- before it, the side of the trunk that `point` (where you aimed) is on.
function ChopRules.cutFace(tree: Model, trunk: BasePart, point: Vector3): Vector3
	local stored = tree:GetAttribute("CutFace")
	if typeof(stored) == "Vector3" then
		return stored
	end
	local direction = trunk.CFrame:PointToObjectSpace(point)
	if math.abs(direction.X) > math.abs(direction.Z) then
		return Vector3.new(math.sign(direction.X), 0, 0)
	end
	return Vector3.new(0, 0, if direction.Z >= 0 then 1 else -1)
end

-- How high the middle of the cut is, in studs above the bottom of the trunk.
-- After the first hit it's where the cut already is (the "CutHeight" attribute); before it,
-- where you aimed, kept between Config.Cut.MinHeight and MaxHeight, and low enough that the
-- biggest cut still fits inside the trunk.
function ChopRules.cutHeight(tree: Model, trunk: BasePart, point: Vector3): number
	local stored = tree:GetAttribute("CutHeight")
	if typeof(stored) == "number" then
		return stored
	end
	local cfg = Config.Cut
	local height = trunk.Size.Y
	local aimed = trunk.CFrame:PointToObjectSpace(point).Y + height / 2
	local halfOpening = trunk.Size.X * cfg.OpeningMax / 2 + 0.2
	local lowest = math.max(cfg.MinHeight, halfOpening)
	local highest = math.min(cfg.MaxHeight, height * cfg.MaxHeightShare, height - halfOpening)
	return math.clamp(aimed, lowest, math.max(highest, lowest))
end

-- The trunk's space turned so that -Z points out of the cut side, with Y up.
function ChopRules.cutSpace(trunk: BasePart, face: Vector3): CFrame
	return trunk.CFrame * CFrame.lookAt(Vector3.zero, face)
end

-- Where the cut opens on the bark, facing out of the trunk.
function ChopRules.cutOpening(trunk: BasePart, face: Vector3, height: number): CFrame
	return ChopRules.cutSpace(trunk, face) * CFrame.new(0, height - trunk.Size.Y / 2, -trunk.Size.X / 2)
end

return table.freeze(ChopRules)
