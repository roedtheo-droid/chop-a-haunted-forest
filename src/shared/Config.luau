--!strict
-- Every tunable number in the game lives here.
-- Change values here to balance the game without touching any logic.

local Config = {
	-- Multiplayer
	-- Note: the real player limit is set in Studio (Game Settings > Places).
	-- This value is used by code that needs to know the party size.
	MaxPlayers = 4,

	-- Debug
	-- When true, the server and client print startup info to the Output window.
	DebugPrints = true,
}

return table.freeze(Config)
