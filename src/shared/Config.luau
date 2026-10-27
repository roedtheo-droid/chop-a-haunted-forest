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

	-- Where placeholder trees are spawned
	Forest = {
		TreeCount = 30,
		AreaSize = 160, -- trees spawn in a square this many studs wide, centered on the map
		ClearRadius = 30, -- no trees this close to the center (keeps spawn and sawmill clear)
		MinSpacing = 10, -- minimum distance between two trees
	},

	-- Trees
	Tree = {
		MaxHP = 30,
		TrunkHeight = 14,
		TrunkWidth = 3,
		LeavesSize = 10,
		MinTrunkScale = 0.4, -- trunk width at 0 HP, compared to full width (shows damage)
		ChipsPerHit = 10, -- wood chip particles per hit
		FallTime = 1.2, -- seconds the fall animation takes
		RemoveDelay = 1.5, -- seconds a fallen tree lies there before it disappears
		LogsPerTree = 3,
	},

	-- Fists (the starting tool)
	Fists = {
		Damage = 5,
		Cooldown = 0.5, -- seconds between swings
		Reach = 8, -- studs from the player to the trunk's edge
	},

	-- Logs
	Logs = {
		CarryLimit = 5, -- starting backpack size
		PickupDistance = 8, -- how close you must be to see "Pick up"
		Length = 4,
		Thickness = 1.2,
	},

	-- Coins (per player, reset every run, not saved)
	Coins = {
		Starting = 0,
		PerLog = 5, -- coins for each log sold
	},

	-- Sawmill (placeholder building near spawn)
	Sawmill = {
		Position = Vector3.new(0, 0, -20), -- center of the building (height is found automatically)
		BuildingSize = Vector3.new(14, 10, 8),
		PadSize = 8, -- the "DROP LOGS" pad is this many studs wide and deep
		SellCooldown = 1, -- seconds between sells for one player (stops double-selling)
	},

	-- UI
	UI = {
		NotifyDuration = 2, -- seconds a message stays on screen
	},
}

return table.freeze(Config)
