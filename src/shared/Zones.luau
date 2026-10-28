--!strict
-- Where the camp and each zone are on the map, worked out from Config.Forest, Config.Camp
-- and Config.Zones. They sit in a row: first the camp (with spawn), then zone 1, then zone 2
-- (towards -Z), and so on. The server uses this to build walls and spawn trees; the client
-- uses it for the HUD.

local Config = require(script.Parent.Config)

export type Bounds = {
	MinX: number,
	MaxX: number,
	MinZ: number, -- the far edge (away from spawn)
	MaxZ: number, -- the near edge (towards spawn)
}

local Zones = {}

-- Name of the folder in ReplicatedStorage that holds each zone's live progress.
-- The server creates it (see Server/Systems/ZoneManager); the client only reads it.
Zones.StateFolderName = "ZoneState"

local halfWidth = Config.Forest.Width / 2
local campBounds: Bounds = {
	MinX = -halfWidth,
	MaxX = halfWidth,
	MinZ = Config.Forest.StartZ - Config.Camp.Length,
	MaxZ = Config.Forest.StartZ,
}

local allBounds: { Bounds } = {}
do
	local nearZ = campBounds.MinZ
	for _, zone in Config.Zones do
		table.insert(allBounds, {
			MinX = -halfWidth,
			MaxX = halfWidth,
			MinZ = nearZ - zone.Length,
			MaxZ = nearZ,
		})
		nearZ -= zone.Length
	end
end

local function isInside(position: Vector3, bounds: Bounds): boolean
	return position.X >= bounds.MinX
		and position.X <= bounds.MaxX
		and position.Z >= bounds.MinZ
		and position.Z <= bounds.MaxZ
end

function Zones.count(): number
	return #allBounds
end

function Zones.getBounds(index: number): Bounds
	return allBounds[index]
end

-- Which zone is this position in? nil if it's outside every zone (the camp isn't a zone).
function Zones.indexAt(position: Vector3): number?
	for index, bounds in allBounds do
		if isInside(position, bounds) then
			return index
		end
	end
	return nil
end

function Zones.getCampBounds(): Bounds
	return campBounds
end

function Zones.isInCamp(position: Vector3): boolean
	return isInside(position, campBounds)
end

-- The middle (Z) of the river that runs across the far end of the camp (see CampManager).
function Zones.getRiverZ(): number
	return campBounds.MinZ + Config.Camp.RiverGap + Config.Camp.RiverWidth / 2
end

-- Is this spot close to one of the zones' landmarks (Config.Landmarks)? No trees grow there.
function Zones.isNearLandmark(x: number, z: number): boolean
	for _, landmark in Config.Landmarks do
		local center = landmark.Position
		if Vector2.new(x - center.X, z - center.Z).Magnitude < landmark.ClearRadius then
			return true
		end
	end
	return false
end

-- The dirt path as a smooth curve: Config.Path.Points with Config.Path.Smoothness extra
-- points between each pair, on a curve that goes through every one of them (a Catmull-Rom
-- curve). So the path still crosses each gate at X = 0 and ends at the boss, but it bends
-- smoothly instead of in sharp corners. Worked out once, here.
local pathPoints: { Vector2 } = {}
do
	local points = Config.Path.Points
	local steps = math.max(Config.Path.Smoothness, 1)
	for index = 1, #points - 1 do
		-- The points before and after this piece shape the curve (the ends repeat themselves).
		local p0 = points[math.max(index - 1, 1)]
		local p1, p2 = points[index], points[index + 1]
		local p3 = points[math.min(index + 2, #points)]
		for step = 0, steps - 1 do
			local t = step / steps
			local t2, t3 = t * t, t * t * t
			table.insert(
				pathPoints,
				(p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
			)
		end
	end
	table.insert(pathPoints, points[#points])
	table.freeze(pathPoints)
end

-- The smooth path's points, from spawn to the boss (don't change the list).
function Zones.getPathPoints(): { Vector2 }
	return pathPoints
end

-- How far (x, z) is from the middle of the smooth dirt path, in studs.
function Zones.distanceToPath(x: number, z: number): number
	local point = Vector2.new(x, z)
	local points = pathPoints
	local best = math.huge
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local along = b - a
		-- How far along this piece of path the closest spot is, from 0 (at a) to 1 (at b).
		local length = along:Dot(along)
		local t = if length > 0 then math.clamp((point - a):Dot(along) / length, 0, 1) else 0
		best = math.min(best, (point - (a + along * t)).Magnitude)
	end
	return best
end

return table.freeze(Zones)
