--!strict
-- Where each zone is on the map, worked out from Config.Forest and Config.Zones.
-- Zones sit in a row: zone 1 is around spawn, zone 2 is behind it (towards -Z), and so on.
-- The server uses this to build walls and spawn trees; the client uses it for the HUD.

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

local allBounds: { Bounds } = {}
do
	local halfWidth = Config.Forest.Width / 2
	local nearZ = Config.Forest.StartZ
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

function Zones.count(): number
	return #allBounds
end

function Zones.getBounds(index: number): Bounds
	return allBounds[index]
end

-- Which zone is this position in? nil if it's outside every zone.
function Zones.indexAt(position: Vector3): number?
	for index, bounds in allBounds do
		if
			position.X >= bounds.MinX
			and position.X <= bounds.MaxX
			and position.Z >= bounds.MinZ
			and position.Z <= bounds.MaxZ
		then
			return index
		end
	end
	return nil
end

return table.freeze(Zones)
