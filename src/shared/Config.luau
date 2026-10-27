--!strict
-- Every tunable number in the game lives here.
-- Change values here to balance the game without touching any logic.

local Types = require(script.Parent.Types)

-- Tools. Fists is what you have when you hold nothing.
-- The Tool Shed sells the rest (see Shared/Shop.luau for the order and names).
-- The Lantern and Torch don't chop (Damage 0): the Lantern shows mimics, the Torch burns them.
local tools: { [string]: Types.ToolConfig } = {
	Fists = { Damage = 5, Cooldown = 0.5, Reach = 8, Price = 0 },
	Axe = { Damage = 10, Cooldown = 0.45, Reach = 9, Price = 50 },
	SteelAxe = { Damage = 20, Cooldown = 0.4, Reach = 9, Price = 250 },
	Chainsaw = { Damage = 12, Cooldown = 0.15, Reach = 8, Price = 1000 },
	Lantern = { Damage = 0, Cooldown = 0.5, Reach = 0, Price = 100 },
	Torch = { Damage = 0, Cooldown = 1, Reach = 8, Price = 150 },
}

-- Upgrades bought in the Tool Shed. Each price in the list is one level.
local upgrades: { [string]: Types.UpgradeConfig } = {
	ChopDamage = { PerLevel = 0.2, Prices = { 40, 80, 160, 320, 640 } }, -- +20% damage per level
	CarryLimit = { PerLevel = 3, Prices = { 30, 60, 120, 240, 480 } }, -- +3 logs per level (Log Sack)
	WalkSpeed = { PerLevel = 2, Prices = { 25, 50, 100, 200, 400 } }, -- +2 walk speed per level
	LogVacuum = { PerLevel = 1, Prices = { 300 } }, -- one level: you have it or you don't
	LanternRadius = { PerLevel = 5, Prices = { 60, 120, 240 } }, -- the Lantern sees 5 studs further per level
}

-- Sounds. Swap any Id to change a sound (no code changes needed).
-- "rbxassetid://..." sounds are free sounds from the Roblox Creator Store (most are from the
-- Pro Sound Effects library); "rbxasset://sounds/..." ones are built into Roblox itself.
local sounds: { [string]: Types.SoundConfig } = {
	-- World sounds: everyone near the spot hears them (made by the server, see EffectsManager).
	ChopFists = { Id = "rbxassetid://9113568548", Volume = 0.5 }, -- boxing glove thud
	ChopAxe = { Id = "rbxassetid://9113974103", Volume = 0.6 }, -- slam into a wooden box
	ChopSteelAxe = { Id = "rbxassetid://9120965080", Volume = 0.6 }, -- wood splintering
	ChopChainsaw = { Id = "rbxassetid://133850299035625", Volume = 0.45, MinGap = 0.3 }, -- chainsaw bite
	TreeFall = { Id = "rbxassetid://9120957463", Volume = 0.7, Range = 120 }, -- heavy wooden crash
	MimicWake = { Id = "rbxassetid://9125475729", Volume = 0.9, Range = 120 }, -- creature growl and hiss
	Burn = { Id = "rbxassetid://9114446277", Volume = 0.7 }, -- fire whoosh
	GateOpen = { Id = "rbxassetid://9118644695", Volume = 1, Range = 300 }, -- heavy blocks scraping
	BossWake = { Id = "rbxassetid://9113980319", Volume = 1, Range = 300 }, -- giant monster roar
	BossSlam = { Id = "rbxassetid://9114036511", Volume = 1, Range = 200 }, -- deep impact
	RootSnap = { Id = "rbxassetid://9120801590", Volume = 0.9, Range = 150 }, -- wood breaking
	BossFall = { Id = "rbxassetid://9120957463", Volume = 1, Speed = 0.6, Range = 300 }, -- the tree crash, slower and deeper

	-- Your own sounds: only you hear them (played on your computer, see SoundController).
	LogPickup = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5 },
	Sell = { Id = "rbxassetid://1319346243", Volume = 0.6 }, -- coins into a cash register
	Buy = { Id = "rbxassetid://9121189379", Volume = 0.6 }, -- bag of coins
	QuestDone = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5 },
	KnockedDown = { Id = "rbxassetid://9113525487", Volume = 0.7 }, -- body slam
	ForestCleared = { Id = "rbxassetid://9042409054", Volume = 0.6 }, -- fanfare (APM Music)
}

-- Particle bursts (see Server/Systems/EffectsManager).
local particles: { [string]: Types.ParticleConfig } = {
	Dust = { Color = Color3.fromRGB(150, 130, 105), Amount = 30, Size = 1.6, Speed = 8, Lifetime = 1.2 }, -- trees landing, gates
	Coins = { Color = Color3.fromRGB(255, 215, 60), Amount = 25, Size = 0.6, Speed = 16, Lifetime = 1 }, -- selling logs
	Embers = { Color = Color3.fromRGB(255, 140, 40), Amount = 30, Size = 0.3, Speed = 6, Lifetime = 1.6 }, -- per second, while a mimic burns
	SlamDust = { Color = Color3.fromRGB(120, 100, 90), Amount = 60, Size = 2.2, Speed = 22, Lifetime = 0.9 }, -- the boss's slam
}

-- Kinds of trees. Each zone uses one kind (see zones below).
-- Trees further from spawn are bigger and tougher, but their logs are worth more.
-- Mixed colours make the "bark colour slightly off" mimic tell (Phase 6) harder to spot.
local treeTypes: { [string]: Types.TreeTypeConfig } = {
	Birch = {
		MaxHP = 30,
		LogValue = 5,
		Scale = 1,
		TrunkColors = { Color3.fromRGB(105, 70, 45), Color3.fromRGB(225, 220, 205), Color3.fromRGB(150, 120, 90) },
		LeafColors = {
			Color3.fromRGB(140, 180, 110),
			Color3.fromRGB(190, 60, 45),
			Color3.fromRGB(225, 130, 50),
			Color3.fromRGB(230, 150, 180),
		},
	},
	Willow = {
		MaxHP = 60,
		LogValue = 8,
		Scale = 1.15,
		TrunkColors = { Color3.fromRGB(95, 85, 75), Color3.fromRGB(70, 70, 68), Color3.fromRGB(85, 95, 70) },
		LeafColors = {
			Color3.fromRGB(110, 130, 110),
			Color3.fromRGB(80, 120, 115),
			Color3.fromRGB(170, 120, 80),
			Color3.fromRGB(170, 175, 160),
		},
	},
	DeadOak = {
		MaxHP = 100,
		LogValue = 12,
		Scale = 1.3,
		TrunkColors = { Color3.fromRGB(50, 42, 38), Color3.fromRGB(40, 40, 42), Color3.fromRGB(70, 40, 35) },
		LeafColors = {
			Color3.fromRGB(110, 30, 30),
			Color3.fromRGB(60, 65, 40),
			Color3.fromRGB(45, 45, 50),
			Color3.fromRGB(120, 60, 30),
		},
	},
}

-- The zones, in order from spawn. Clearing every tree in a zone opens the gate to the next one.
-- Zone 1 starts behind spawn (Forest.StartZ) and each next zone is further along -Z.
local zones: { Types.ZoneConfig } = {
	{
		Name = "Pale Pines",
		Length = 160,
		TreeCount = 30,
		TreeType = "Birch",
		GroundColor = Color3.fromRGB(95, 130, 75),
		GroundMaterial = Enum.Material.Grass,
		Sawmill = Vector3.new(0, 0, -20), -- next to spawn and the Tool Shed
		ClearRadius = 40, -- keeps spawn, the sawmill and the Tool Shed free of trees
		MimicPercent = 5, -- this % of the zone's trees are secretly mimics
		-- A clear afternoon (the place's normal lighting).
		Look = {
			ClockTime = 14.5,
			Brightness = 3,
			Ambient = Color3.fromRGB(70, 70, 70),
			FogDensity = 0.3,
			FogOffset = 0.25,
			FogColor = Color3.fromRGB(199, 199, 199),
			FogDecay = Color3.fromRGB(106, 112, 125),
			Haze = 0,
			Ambience = { Id = "rbxassetid://9112832288", Volume = 0.25 }, -- light birds, mountain air
		},
	},
	{
		Name = "Fog Hollow",
		Length = 180,
		TreeCount = 40,
		TreeType = "Willow",
		GroundColor = Color3.fromRGB(85, 95, 85),
		GroundMaterial = Enum.Material.Ground,
		Sawmill = Vector3.new(-40, 0, -110), -- just inside the gate, off to the left
		ClearRadius = 30,
		MimicPercent = 10,
		-- Thick grey fog: you can only see a short way ahead.
		Look = {
			ClockTime = 14.5,
			Brightness = 2,
			Ambient = Color3.fromRGB(80, 85, 85),
			FogDensity = 0.7,
			FogOffset = 0,
			FogColor = Color3.fromRGB(170, 178, 175),
			FogDecay = Color3.fromRGB(140, 145, 145),
			Haze = 3,
			Ambience = { Id = "rbxassetid://9120505513", Volume = 0.35 }, -- thin trickles and drips, echoing
		},
	},
	{
		Name = "Graveyard Grove",
		Length = 200,
		TreeCount = 50,
		TreeType = "DeadOak",
		GroundColor = Color3.fromRGB(55, 45, 45),
		GroundMaterial = Enum.Material.Mud,
		Sawmill = Vector3.new(-40, 0, -290),
		ClearRadius = 30,
		MimicPercent = 15,
		-- Dusk: dark and gloomy, with a purple haze. The Lantern's glow really helps here.
		Look = {
			ClockTime = 17.7,
			Brightness = 1.5,
			Ambient = Color3.fromRGB(75, 62, 88),
			FogDensity = 0.45,
			FogOffset = 0.1,
			FogColor = Color3.fromRGB(70, 60, 85),
			FogDecay = Color3.fromRGB(40, 35, 50),
			Haze = 1.5,
			Ambience = { Id = "rbxassetid://9114625552", Volume = 0.3 }, -- spooky, eerie wind
		},
	},
}

-- Tutorial quests, in order. They teach new players the core loop.
local quests: { Types.QuestConfig } = {
	{ Event = "FellTree", Goal = 1, Text = "Chop down a tree" },
	{ Event = "PickUpLog", Goal = 3, Text = "Pick up logs (press E)" },
	{ Event = "SellLogs", Goal = 1, Text = "Sell logs on the sawmill pad" },
	{ Event = "BuyAxe", Goal = 1, Text = "Buy an Axe at the Tool Shed" },
	{ Event = "BuyUpgrade", Goal = 1, Text = "Buy any upgrade" },
	{ Event = "FellTree", Goal = 10, Text = "Chop down trees" },
}

local Config = {
	-- Multiplayer
	-- Note: the real player limit is set in Studio (Game Settings > Places).
	-- This value is used by code that needs to know the party size.
	MaxPlayers = 4,

	-- Debug
	-- When true, the server and client print startup info to the Output window.
	DebugPrints = true,
	-- When true, Studio playtests show test shortcuts like the "Skip to boss" button.
	-- They never work in the real game (see Server/Systems/DebugManager).
	StudioShortcuts = true,

	-- The forest: zones in a row with walls around them (see Shared/Zones.luau)
	Forest = {
		Width = 160, -- every zone is this wide (X axis)
		StartZ = 80, -- the edge of zone 1 behind spawn (spawn is at Z = 0)
		MinSpacing = 10, -- minimum distance between two trees
		EdgeMargin = 8, -- no trees closer than this to a wall
		WallHeight = 20, -- too high to jump over
		WallThickness = 2,
	},

	Zones = zones,
	TreeTypes = treeTypes,

	-- Gates between zones
	Gates = {
		Width = 16,
		OpenTime = 2, -- seconds the gate takes to sink into the ground
		MessageCooldown = 3, -- seconds between "Clear every tree first" messages for one player
	},

	-- Each zone's light, fog and background sound (the Look in each zone above) fade in when you walk in.
	ZoneLook = {
		FadeTime = 3, -- seconds the change takes
		Refresh = 0.5, -- seconds between checks of which zone you're in
	},

	Sounds = sounds,
	Particles = particles,

	-- World sounds and particles (see Server/Systems/EffectsManager)
	Effects = {
		SoundRange = 80, -- world sounds are heard up to this many studs away (unless a sound sets its own Range)
		SoundFullVolume = 10, -- ...and are at full volume within this many studs
	},

	-- The glowing line to the nearest tree when a zone is almost cleared
	NearestTree = {
		ShowAtPercent = 95, -- show it when the zone you're in is at least this % cleared
		Refresh = 0.25, -- seconds between updates
	},

	-- Mimics: trees that wake up and chase you when you chop them.
	-- How many there are is set per zone (MimicPercent in the zones list above).
	Mimics = {
		HPMultiplier = 2, -- when it wakes up, a mimic gets this many times its tree's HP
		WakeTime = 1.5, -- seconds it shakes loose before chasing (your head start)
		ChaseSpeed = 20, -- faster than walking (16), slower than sprinting (16 + SprintBonus)
		CatchDistance = 4.5, -- it catches you when your middle is this close to its trunk's middle
		CatchHeight = 8, -- ...and you're no more than this many studs above or below its roots
		SleepAfter = 45, -- seconds without catching anyone before it roots itself again
		HideAfterCatch = true, -- after catching someone it roots itself again right away, so friends can revive them
		RepathInterval = 0.5, -- seconds between working out a new path to its target
		SleepSearchRadius = 20, -- it roots itself again within this many studs
		-- Tells (each mimic gets one at random)
		TintColor = Color3.fromRGB(120, 150, 80), -- "Tint": bark is pulled a little towards this colour
		TintAmount = 0.3, -- 0 = no change, 1 = fully TintColor
		SwayDistance = 0.8, -- "Sway": studs the leaves move side to side
		SwayTime = 1.4, -- seconds for one sway
		TiltAngle = 8, -- "Tilt": degrees a leaning mimic leans
		TallExtra = 0.2, -- "Tilt": a too-tall mimic's trunk is this much longer (0.2 = 20%)
		CreakDistance = 15, -- "Creak": you hear it within this many studs
		CreakSoundId = "rbxassetid://9126263691", -- a free wood creak sound from the Creator Store
		BlinkTime = 0.25, -- "Blink": seconds the knot stays open like an eye
		TellMinGap = 4, -- seconds between creaks or blinks (random between min and max)
		TellMaxGap = 8,
		DecoyKnotChance = 0.3, -- share of trees with a plain knot, so a knot alone isn't a tell
	},

	-- Lantern (bought in the Tool Shed): sleeping mimics near you get a faint outline
	-- that only YOU can see while you hold it.
	Lantern = {
		Radius = 20, -- studs; the Lantern Radius upgrade adds to this
		Refresh = 0.3, -- seconds between checks for mimics nearby
		OutlineColor = Color3.fromRGB(255, 190, 110),
		OutlineTransparency = 0.55, -- 0 = solid, 1 = invisible. Higher is fainter.
		LightRange = 14, -- how far the lantern's glow lights up the ground around you
	},

	-- Torch (bought in the Tool Shed): hit a SLEEPING mimic to burn it safely.
	-- Normal trees and awake mimics don't burn.
	Torch = {
		BurnTime = 2, -- seconds the mimic burns before it crumbles away
	},

	-- Embers: the permanent currency (saved, see Save below)
	Embers = {
		PerMimic = 5, -- Embers for the player who burns a mimic
		PerForestCleared = 25, -- Embers for everyone in the server when the Elder Hollow falls
	},

	-- Saving Embers, lifetime stats and unlocks (see Server/Systems/SaveManager)
	Save = {
		StoreName = "PlayerData", -- the DataStore's name. Changing it starts everyone from scratch!
		AutosaveInterval = 120, -- seconds between autosaves for each player
		Retries = 5, -- tries for each load or save before giving up
		RetryWait = 1, -- seconds before the first retry; doubles each time (1, 2, 4, 8)
		LockTimeout = 300, -- a lock older than this is left over from a crashed server (keep it above AutosaveInterval)
		LockedRetries = 5, -- how many times to wait for another server to finish saving your data
		LockedWait = 3, -- seconds between those tries
		ShutdownWait = 25, -- max seconds to wait for everyone's save when a server shuts down
	},

	-- The Elder Hollow: a giant mimic at the far end of the last zone, the final boss.
	-- It sleeps (and can't be hurt) until every other tree in its zone is cleared.
	-- Then it slams the ground, and players break it by chopping its glowing roots.
	Boss = {
		Position = Vector3.new(0, 0, -415), -- where it stands (height is found automatically)
		ClearRadius = 35, -- no trees grow (and no mimics hide) this close to it
		TrunkHeight = 40,
		TrunkWidth = 10,
		CrownSize = 30, -- the ball of leaves on top
		RootCount = 4, -- weak points around its base
		RootHP = 300, -- HP of each root. The boss's HP bar is all its roots added up.
		RootLength = 12,
		RootThickness = 3,
		SlamInterval = 4, -- seconds between slams
		SlamWarning = 1.5, -- seconds the red circle shows before the slam lands (time to dodge)
		SlamRadius = 10, -- studs
		SlamKnockdown = 8, -- seconds a slam knocks you down (mimics use Knockdown.Duration)
		MessageCooldown = 3, -- seconds between "chop the roots" hints for one player
	},

	-- Getting caught by a mimic
	Knockdown = {
		Duration = 20, -- seconds you're down if nobody revives you
		ReviveHoldTime = 3, -- seconds a friend holds E on you to revive you
		ReviveDistance = 8, -- how close the friend must be
		SafeTime = 5, -- seconds after getting up when mimics can't catch you again (time to run)
	},

	-- Rare purple Cursed trees
	Cursed = {
		Chance = 0.03, -- 3% of trees
		LogMultiplier = 3, -- their logs are worth 3x
		Color = Color3.fromRGB(170, 70, 255),
	},

	-- Trees (sizes are for Scale 1; see TreeTypes for HP and log value)
	Tree = {
		TrunkHeight = 14,
		TrunkWidth = 3,
		LeavesSize = 10,
		MinTrunkScale = 0.4, -- trunk width at 0 HP, compared to full width (shows damage)
		ChipsPerHit = 10, -- wood chip particles per hit
		FallTime = 1.2, -- seconds the fall animation takes
		RemoveDelay = 1.5, -- seconds a fallen tree lies there before it disappears
		LogsPerTree = 3,
		StumpHeight = 1.2, -- the stump a felled tree leaves behind
	},

	Tools = tools,
	Upgrades = upgrades,
	Quests = quests,

	-- Log Vacuum (bought in the Tool Shed as an upgrade)
	LogVacuum = {
		Radius = 15, -- logs closer than this fly to you
		Interval = 0.25, -- seconds between checks for nearby logs
		PullTime = 0.35, -- seconds a log takes to fly to you
	},

	-- Player
	Player = {
		BaseWalkSpeed = 16, -- Roblox's normal walk speed
		SprintBonus = 8, -- holding Shift (or the Sprint button) adds this to your walk speed
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
	-- How much a log is worth depends on its tree (see TreeTypes and Cursed).
	Coins = {
		Starting = 0,
	},

	-- Sawmills (one placeholder building per zone; positions are in Zones above)
	Sawmill = {
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
		QuestsDoneHideDelay = 6, -- seconds the "All quests done" box stays before hiding
	},
}

return table.freeze(Config)
