--!strict
-- Where the Elder Hollow (the final boss) lives, shared by the server and the client.
-- The numbers are in Config.Boss.

local Config = require(script.Parent.Config)
local Zones = require(script.Parent.Zones)

local Boss = {}

-- Name of the folder in ReplicatedStorage with the boss's live state, as attributes:
--   State  "Asleep", "Awake" or "Defeated"
--   HP     all its roots' HP added up
--   MaxHP
-- The server creates it (see Server/Systems/BossManager); the client only reads it.
Boss.StateFolderName = "BossState"

-- The boss stands in the last zone.
Boss.ZoneId = Zones.count()

-- Is this spot in the clearing around the boss? (No trees grow there.)
function Boss.isInClearing(position: Vector3): boolean
	local center = Config.Boss.Position
	return Vector2.new(position.X - center.X, position.Z - center.Z).Magnitude < Config.Boss.ClearRadius
end

return table.freeze(Boss)
