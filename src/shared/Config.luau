--!strict
-- Every tunable number in the game lives here.
-- Change values here to balance the game without touching any logic.

local Types = require(script.Parent.Types)

-- Chopping tools. Fists is what you have when you hold nothing.
-- The Tool Shed sells the rest (see Shared/Shop.luau for the order and names).
local tools: { [string]: Types.ToolConfig } = {
	Fists = { Damage = 5, Cooldown = 0.5, Reach = 8, Price = 0 },
	Axe = { Damage = 10, Cooldown = 0.45, Reach = 9, Price = 50 },
	SteelAxe = { Damage = 20, Cooldown = 0.4, Reach = 9, Price = 250 },
	Chainsaw = { Damage = 12, Cooldown = 0.15, Reach = 8, Price = 1000 },
}

-- Upgrades bought in the Tool Shed. Each price in the list is one level.
local upgrades: { [string]: Types.UpgradeConfig } = {
	ChopDamage = { PerLevel = 0.2, Prices = { 40, 80, 160, 320, 640 } }, -- +20% damage per level
	CarryLimit = { PerLevel = 3, Prices = { 30, 60, 120, 240, 480 } }, -- +3 logs per level (Log Sack)
	WalkSpeed = { PerLevel = 2, Prices = { 25, 50, 100, 200, 400 } }, -- +2 walk speed per level
}

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
		ClearRadius = 40, -- no trees this close to the center (keeps spawn, sawmill and shed clear)
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

	Tools = tools,
	Upgrades = upgrades,

	-- Player
	Player = {
		BaseWalkSpeed = 16, -- Roblox's normal walk speed
	},

	-- Server checks
	Anticheat = {
		-- The server accepts a swing after this share of the tool's cooldown,
		-- so normal network lag doesn't make honest swings miss.
		CooldownTolerance = 0.85,
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

	-- Tool Shed (placeholder building next to the sawmill)
	Shop = {
		Position = Vector3.new(22, 0, -20), -- center of the building (height is found automatically)
		BuildingSize = Vector3.new(10, 8, 8),
		PromptDistance = 10, -- how close you must be to see "Open shop"
		MaxBuyDistance = 20, -- the server refuses purchases from further away than this
		BuyCooldown = 0.25, -- seconds between purchases for one player
	},

	-- UI
	UI = {
		NotifyDuration = 2, -- seconds a message stays on screen
	},
}

return table.freeze(Config)
