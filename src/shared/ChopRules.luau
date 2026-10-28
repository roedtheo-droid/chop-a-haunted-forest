--!strict
-- Swing rules that the server and the client both need, kept in ONE place so they agree.
-- The server uses them to decide if a swing counts and where the notch goes
-- (see Server/Systems/TreeManager and Server/Build/Blocky). The client uses the same rules
-- to show your hit right away, in the right spot, without waiting for the server
-- (see Client/Controllers/ChopController).

local Config = require(script.Parent.Config)

local ChopRules = {}

-- Can a player standing at `rootPosition` reach `target` with this tool?
-- Reach is measured flat (height doesn't count), from the player to the trunk's edge.
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

-- Which side of the trunk the notch is on, in the trunk's own space (like (0, 0, -1)).
-- After the first hit that's the side the notch already has (the "NotchFace" attribute);
-- before it, the side closest to `outward` (a direction from the trunk towards the swinger).
function ChopRules.notchFace(tree: Model, trunk: BasePart, outward: Vector3): Vector3
	local stored = tree:GetAttribute("NotchFace")
	if typeof(stored) == "Vector3" then
		return stored
	end
	local direction = trunk.CFrame:VectorToObjectSpace(outward)
	if math.abs(direction.X) > math.abs(direction.Z) then
		return Vector3.new(math.sign(direction.X), 0, 0)
	end
	return Vector3.new(0, 0, if direction.Z >= 0 then 1 else -1)
end

-- How high the middle of the notch is, measured from the trunk's centre (so it's below 0).
function ChopRules.notchMiddle(trunk: BasePart): number
	local cfg = Config.Tree
	local width, height = trunk.Size.X, trunk.Size.Y
	local maxOpening = width * cfg.NotchMaxDepth * cfg.NotchOpening
	return -height / 2 + math.min(math.max(cfg.NotchHeight, maxOpening / 2 + 0.3), height * 0.4)
end

-- Where the notch opens on the bark, facing out of the trunk.
function ChopRules.notchOpening(trunk: BasePart, face: Vector3): CFrame
	local space = trunk.CFrame * CFrame.lookAt(Vector3.zero, face)
	return space * CFrame.new(0, ChopRules.notchMiddle(trunk), -trunk.Size.X / 2)
end

return table.freeze(ChopRules)
