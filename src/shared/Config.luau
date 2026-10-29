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

-- How each chopping tool FEELS (see Client/Controllers/ChopEffectsController): its sound, your
-- swing, the chips and how hard things shake. Bigger tools hit harder and messier.
-- The swing is Roblox's own tool-slash animation, which every game is allowed to use.
local SWING = "rbxassetid://522635514"
local chopFeel: { [string]: Types.ChopFeelConfig } = {
	-- The Torch has no entry: it swings like Fists, but burning is its only effect.
	Fists = {
		Sound = "ChopFists",
		Swing = SWING,
		SwingSpeed = 1.6,
		SwingSize = 1,
		ChipsMin = 3, -- 3 to 6 little wood cubes per punch, like in Chop a Forest
		ChipsMax = 6,
		ChipSize = 0.35,
		Wobble = 1.5,
		CameraKick = 0.06,
	},
	Axe = {
		Sound = "ChopAxe",
		Swing = SWING,
		SwingSpeed = 1.6,
		SwingSize = 1,
		ChipsMin = 5,
		ChipsMax = 8,
		ChipSize = 0.45,
		Wobble = 2,
		CameraKick = 0.09,
	},
	SteelAxe = {
		Sound = "ChopSteelAxe",
		Swing = SWING,
		SwingSpeed = 1.8,
		SwingSize = 1,
		ChipsMin = 8,
		ChipsMax = 12,
		ChipSize = 0.55,
		Wobble = 3,
		CameraKick = 0.13,
	},
	Chainsaw = {
		Sound = "ChopChainsaw",
		Swing = SWING,
		SwingSpeed = 3,
		SwingSize = 0.35, -- a small, fast sawing movement instead of big chops
		ChipsMin = 2, -- fewer per hit, but it hits very often
		ChipsMax = 4,
		ChipSize = 0.3,
		Wobble = 1,
		CameraKick = 0.04,
	},
}

-- Sounds. Swap any Id to change a sound (no code changes needed).
-- "rbxassetid://..." sounds are free sounds from the Roblox Creator Store (most are from the
-- Pro Sound Effects library); "rbxasset://sounds/..." ones are built into Roblox itself.
local sounds: { [string]: Types.SoundConfig } = {
	-- Chop sounds: every player's computer plays these itself, a little higher or lower each
	-- time (see ChopEffectsController). Hits on the boss are played by the server.
	ChopFists = { Id = "rbxassetid://9113568548", Volume = 0.5 }, -- boxing glove thud
	ChopAxe = { Id = "rbxassetid://9113974103", Volume = 0.6 }, -- slam into a wooden box
	ChopSteelAxe = { Id = "rbxassetid://9120965080", Volume = 0.6 }, -- wood splintering
	ChopChainsaw = { Id = "rbxassetid://133850299035625", Volume = 0.45, MinGap = 0.3 }, -- chainsaw bite
	TreeCrack = { Id = "rbxassetid://9120801590", Volume = 0.5, Range = 100 }, -- wood breaking, as a felled tree starts to tip
	TreeFall = { Id = "rbxassetid://9120957463", Volume = 0.7, Range = 120 }, -- heavy wooden crash when it lands

	-- World sounds: everyone near the spot hears them (made by the server, see EffectsManager).
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
-- The look follows STYLE_GUIDE.md: blocky trunks with roots, crowns made of leaf blocks.
local treeTypes: { [string]: Types.TreeTypeConfig } = {
	-- Pale Pines: bright, happy and green, with white birches and a few autumn trees.
	Birch = {
		Name = "Oak", -- the parts version of these trees is an oak
		MaxHP = 50, -- 10 punches with Fists, like in Chop a Forest
		LogValue = 5,
		Scale = 1,
		TrunkColors = { Color3.fromRGB(120, 75, 45), Color3.fromRGB(135, 85, 50), Color3.fromRGB(110, 68, 40) },
		LeafColors = {
			Color3.fromRGB(60, 130, 45),
			Color3.fromRGB(75, 150, 55),
			Color3.fromRGB(95, 165, 60),
			Color3.fromRGB(60, 130, 45),
			Color3.fromRGB(75, 150, 55),
			Color3.fromRGB(95, 165, 60),
			Color3.fromRGB(60, 130, 45),
			Color3.fromRGB(75, 150, 55),
			Color3.fromRGB(95, 165, 60),
			Color3.fromRGB(200, 60, 45), -- red autumn tree
			Color3.fromRGB(230, 140, 50), -- orange autumn tree
			Color3.fromRGB(235, 150, 185), -- pink blossom tree
		},
		LeafBlocks = 4,
		BirchChance = 0.3,
		BirchColor = Color3.fromRGB(235, 232, 222),
		-- Blender models (see Models below): 60% oaks and 40% pines, two shapes of each, and
		-- the birches use the two birch shapes. Until they're imported into Studio, these
		-- trees are built from parts.
		Shapes = { Oak = 0.3, Oak2 = 0.3, Pine = 0.2, Pine2 = 0.2 },
		BirchShapes = { Birch = 0.5, Birch2 = 0.5 },
	},
	-- Fog Hollow: the same trees, but greyer and gloomier.
	Willow = {
		Name = "Willow",
		MaxHP = 60,
		LogValue = 8,
		Scale = 1.15,
		TrunkColors = { Color3.fromRGB(95, 80, 68), Color3.fromRGB(80, 72, 66), Color3.fromRGB(88, 84, 70) },
		LeafColors = {
			Color3.fromRGB(85, 120, 85),
			Color3.fromRGB(100, 135, 95),
			Color3.fromRGB(75, 105, 80),
			Color3.fromRGB(140, 150, 120),
		},
		LeafBlocks = 4,
		BirchChance = 0.2,
		BirchColor = Color3.fromRGB(205, 208, 200),
		-- Blender models: willows with long hanging strands, and pale birches.
		Shapes = { Willow1 = 0.5, Willow2 = 0.5 },
		BirchShapes = { Birch = 0.5, Birch2 = 0.5 },
	},
	-- Graveyard Grove: dead, crooked trees with a few dark leaves and bare branches.
	DeadOak = {
		Name = "Dead Oak",
		MaxHP = 100,
		LogValue = 12,
		Scale = 1.3,
		TrunkColors = { Color3.fromRGB(55, 44, 40), Color3.fromRGB(45, 40, 44), Color3.fromRGB(70, 45, 38) },
		LeafColors = {
			Color3.fromRGB(110, 30, 35),
			Color3.fromRGB(75, 70, 40),
			Color3.fromRGB(120, 60, 30),
		},
		LeafBlocks = 2,
		Branches = 2,
		-- Blender models: bare, forked branches with a few dark leaves.
		Shapes = { DeadOak1 = 0.5, DeadOak2 = 0.5 },
	},
}

-- Tree shapes made in Blender (see Models below). TrunkWidth is the trunk's width at Scale 1:
-- keep it the same as in blender/models/trees.py, or the trees come out the wrong size.
-- Pines stay green (no autumn colours), a little darker than the oaks.
local pineGreens = { Color3.fromRGB(47, 107, 42), Color3.fromRGB(58, 127, 51), Color3.fromRGB(70, 138, 56) }
local treeShapes: { [string]: Types.TreeShapeConfig } = {
	Oak = { Name = "Oak", TrunkWidth = 3 },
	Oak2 = { Name = "Oak", TrunkWidth = 3 },
	Pine = { Name = "Pine", TrunkWidth = 2.2, LeafColors = pineGreens },
	Pine2 = { Name = "Pine", TrunkWidth = 2.2, LeafColors = pineGreens },
	Birch = { Name = "Birch", TrunkWidth = 2.4 },
	Birch2 = { Name = "Birch", TrunkWidth = 2.4 },
	Willow1 = { Name = "Willow", TrunkWidth = 3.2 },
	Willow2 = { Name = "Willow", TrunkWidth = 3.2 },
	DeadOak1 = { Name = "Dead Oak", TrunkWidth = 3 },
	DeadOak2 = { Name = "Dead Oak", TrunkWidth = 3 },
}

-- The zones, in order from spawn. Clearing every tree in a zone opens the gate to the next one.
-- The camp (with spawn) comes first, then zone 1, and each next zone is further along -Z.
local zones: { Types.ZoneConfig } = {
	{
		Name = "Pale Pines",
		Length = 260,
		TreeCount = 60,
		TreeType = "Birch",
		GroundColor = Color3.fromRGB(90, 170, 60),
		GroundMaterial = Enum.Material.Grass,
		Sawmill = Vector3.new(50, 0, 410), -- in the camp, by the river
		ClearRadius = 30, -- no trees this close to the sawmill
		MimicPercent = 5, -- this % of the zone's trees are secretly mimics
		-- A sunny, cartoony midday: bright colours, soft shadows, almost no fog.
		Look = {
			ClockTime = 13,
			Brightness = 3,
			Ambient = Color3.fromRGB(110, 110, 115),
			FogDensity = 0.25,
			FogOffset = 0.3,
			FogColor = Color3.fromRGB(200, 225, 240),
			FogDecay = Color3.fromRGB(150, 180, 210),
			Haze = 0,
			Saturation = 0.2,
			Tint = Color3.fromRGB(255, 250, 240),
			CloudCover = 0.55, -- fluffy white clouds and a little sunshine through the trees
			CloudDensity = 0.3,
			CloudColor = Color3.fromRGB(255, 255, 255),
			SunRays = 0.1,
			Ambience = { Id = "rbxassetid://9112832288", Volume = 0.25 }, -- light birds, mountain air
		},
	},
	{
		Name = "Fog Hollow",
		Length = 300,
		TreeCount = 90,
		TreeType = "Willow",
		GroundColor = Color3.fromRGB(95, 125, 80),
		GroundMaterial = Enum.Material.Grass,
		Sawmill = Vector3.new(-90, 0, 80), -- just inside the gate, off to the left
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
			Saturation = -0.1,
			Tint = Color3.fromRGB(235, 242, 242),
			CloudCover = 0.85, -- a heavy grey sky, no sun
			CloudDensity = 0.6,
			CloudColor = Color3.fromRGB(185, 190, 192),
			SunRays = 0,
			Ambience = { Id = "rbxassetid://9120505513", Volume = 0.35 }, -- thin trickles and drips, echoing
		},
	},
	{
		Name = "Graveyard Grove",
		Length = 340,
		TreeCount = 120,
		TreeType = "DeadOak",
		GroundColor = Color3.fromRGB(60, 48, 52),
		GroundMaterial = Enum.Material.Mud,
		Sawmill = Vector3.new(-90, 0, -220),
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
			Saturation = 0,
			Tint = Color3.fromRGB(240, 220, 255),
			CloudCover = 0.7, -- purple dusk clouds, a last bit of low sun
			CloudDensity = 0.45,
			CloudColor = Color3.fromRGB(125, 105, 140),
			SunRays = 0.04,
			Ambience = { Id = "rbxassetid://9114625552", Volume = 0.3 }, -- spooky, eerie wind
		},
	},
}

-- How each gate between two zones looks, in order: gate 1 is between zone 1 and zone 2.
-- See Types.GateLookConfig and Server/Build/Edges.
local gateLooks: { Types.GateLookConfig } = {
	{ Door = "Wood", Gatehouse = "Log", Border = "Ridge", LampColor = Color3.fromRGB(255, 205, 130), Flicker = false },
	{ Door = "Iron", Gatehouse = "Stone", Border = "StoneWall", LampColor = Color3.fromRGB(255, 140, 60), Flicker = true },
}

-- Little things on each zone's ground, one list per zone (see Types.DetailConfig and
-- Details below).
local zoneDetails: { { Types.DetailConfig } } = {
	{ -- Pale Pines
		{
			Model = "GrassTuft",
			Part = "Grass",
			Count = 150,
			Size = { 0.8, 1.4 },
			Colors = { Color3.fromRGB(95, 170, 60), Color3.fromRGB(80, 150, 50), Color3.fromRGB(120, 180, 70) },
		},
		{
			Model = "Flowers",
			Part = "Stem",
			Count = 50,
			Size = { 1.2, 1.8 },
			Colors = {
				Color3.fromRGB(255, 215, 70),
				Color3.fromRGB(250, 250, 245),
				Color3.fromRGB(240, 150, 200),
				Color3.fromRGB(170, 130, 230),
			},
			StemColor = Color3.fromRGB(60, 140, 50),
		},
	},
	{ -- Fog Hollow
		{
			Model = "Fern",
			Part = "Frond",
			Count = 90,
			Size = { 3, 4.5 },
			Colors = { Color3.fromRGB(70, 120, 70), Color3.fromRGB(85, 130, 80), Color3.fromRGB(60, 100, 65) },
		},
		{
			Model = "Mushrooms",
			Part = "Stem",
			Count = 30,
			Size = { 1.2, 1.8 },
			Colors = { Color3.fromRGB(140, 255, 120) },
			StemColor = Color3.fromRGB(240, 228, 205),
			Glow = true,
		},
	},
	{ -- Graveyard Grove
		{
			Model = "DeadLeaves",
			Part = "Leaf",
			Count = 110,
			Size = { 2.6, 3.6 },
			Colors = { Color3.fromRGB(92, 47, 43), Color3.fromRGB(120, 70, 35), Color3.fromRGB(70, 50, 40) },
		},
		{
			Model = "Bones",
			Part = "Bone",
			Count = 12,
			Size = { 1.6, 2.2 },
			Colors = { Color3.fromRGB(225, 218, 195) },
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

	-- Extra chop text, like in Chop a Forest. Both are off by default to keep the effects clean.
	ShowTreeHpBar = false, -- true: the tree's name and HP show under the crosshair (see TreeHpBar)
	ShowTimberText = false, -- true: "TIMBER!" pops up when a tree falls (see Timber)

	-- The forest: zones in a row with walls around them (see Shared/Zones.luau)
	Forest = {
		Width = 260, -- the camp and every zone are this wide (X axis)
		StartZ = 520, -- the back edge of the camp, behind spawn. Zone 1 starts Camp.Length further on.
		MinSpacing = 10, -- minimum distance between two trees
		EdgeMargin = 8, -- no trees closer than this to a wall
		-- Groves and clearings: trees grow thicker in some places and thinner in others (the
		-- same number of trees, just not spread evenly), and each zone has a few open clearings.
		GroveSize = 70, -- studs across a grove (and the thin patches between them)
		GroveContrast = 1.6, -- how much thicker the groves are than the thin patches (0 = even)
		GroveMinChance = 0.12, -- even the thinnest patch keeps some trees
		Clearings = 3, -- open clearings in each zone
		ClearingRadius = { 12, 20 },
		-- The walls are invisible: you see hedges, rocks and gatehouses in front of them instead
		-- (see Edges below). 30 is too high to jump over, even from the top of a ridge rock.
		WallHeight = 30,
		WallThickness = 2,
	},

	Zones = zones,
	TreeTypes = treeTypes,

	-- Models made in Blender (see the blender/ folder and Server/Build/Assets). Each one is
	-- imported into Studio and put in ServerStorage > MapAssets (see README.md).
	-- Anything that isn't imported yet is built from plain parts, so the game always works.
	Models = {
		Folder = "MapAssets", -- the folder in ServerStorage
		BarkBlock = "BarkBlock", -- stretched copies of it make up a chopped trunk (see Build/Carve)
		Rocks = { "Rock1", "Rock2" }, -- each rock picks one of these at random
		Trees = treeShapes, -- which tree types use them: Shapes in TreeTypes above
		Patches = { "Patch1", "Patch2", "Patch3" }, -- flat blobs on the ground (see Ground below)
		Pebbles = "Pebbles", -- along the path's edges
		RiverBank = "RiverBank", -- pieces of the river's banks
		Hedges = { "Hedge1", "Hedge2", "Hedge3" }, -- along the outside walls (see Edges below)
		RidgeRocks = { "RidgeRock1", "RidgeRock2" }, -- the rocky ridge at a gate with Border = "Ridge"
		StoneWalls = { "StoneWall1", "StoneWall2" }, -- the crumbling wall at a gate with Border = "StoneWall"
		-- By the Gatehouse in Gates.Looks.
		Gatehouses = { Log = "LogGatehouse", Stone = "StoneGatehouse" } :: { [string]: string },
		Mountains = { "Mountains1", "Mountains2" }, -- mountain ranges far away (see Scenery)
		Hills = { "Hill1", "Hill2" }, -- rolling hills with little trees, behind the border trees
		-- Props along the path and in the landmarks (see Server/Build/Props). Width: how wide
		-- Part is at the size of the parts version (keep it the same as blender/models/props.py).
		Props = {
			BerryBush = { Model = "BerryBush", Part = "Bush", Width = 4.2 },
			FallenLog = { Model = "FallenLog", Part = "Log", Width = 8 }, -- the game picks each log's length
			LampPost = { Model = "LampPost", Part = "Post", Width = 0.77 },
			Fence = { Model = "FenceSection", Part = "Post", Width = 0.71 }, -- one post and its rails
			Pumpkin = { Model = "Pumpkin", Part = "Pumpkin", Width = 2.2 },
			Reeds = { Model = "Reeds", Part = "Reed", Width = 2.2 },
			LilyPad = { Model = "LilyPad", Part = "Pad", Width = 1.8 },
			Mushrooms = { Model = "Mushrooms", Part = "Stem", Width = 1.34 },
		},
		-- The landmarks (see Server/Build/Landmarks) and the camp's things (Server/Build/CampProps
		-- and Systems/CampManager), with the same meaning as Props above.
		Landmarks = {
			Tent = { Model = "Tent", Part = "Canvas", Width = 7 },
			Dock = { Model = "Dock", Part = "Deck", Width = 15.92 },
			Rowboat = { Model = "Rowboat", Part = "Hull", Width = 7.1 },
			WindmillTower = { Model = "WindmillTower", Part = "Tower", Width = 10.24 },
			WindmillSails = { Model = "WindmillSails", Part = "Hub", Width = 1.6 }, -- they turn around the hub
			IronFence = { Model = "IronFence", Part = "Iron", Width = 3 }, -- one 3-stud section of the graveyard's fence
			Crypt = { Model = "Crypt", Part = "Stone", Width = 10.35 },
		},
		-- The tall stones in a ring around the boss's clearing.
		BossStones = {
			{ Model = "BossStone1", Part = "Stone", Width = 3 },
			{ Model = "BossStone2", Part = "Stone", Width = 3 },
		},
		Camp = {
			Bridge = { Model = "Bridge", Part = "Deck", Width = 16.15 }, -- built for Camp.BridgeWidth 16 and RiverWidth 14
			Well = { Model = "Well", Part = "Stone", Width = 5.06 },
			QuestBoard = { Model = "QuestBoard", Part = "Post", Width = 8 },
			Campfire = { Model = "Campfire", Part = "Stone", Width = 6.08 },
			Bench = { Model = "Bench", Part = "Leg", Width = 4.65 },
			Signpost = { Model = "Signpost", Part = "Post", Width = 1.1 },
			SignArrow = { Model = "SignArrow", Part = "Board", Width = 5.4 }, -- one of the signpost's arrows
		},
		-- A slab, a cross and a pillar (Props.gravestone's kind 1, 2 and 3).
		Gravestones = {
			{ Model = "Gravestone1", Part = "Stone", Width = 2.6 },
			{ Model = "Gravestone2", Part = "Stone", Width = 2.6 },
			{ Model = "Gravestone3", Part = "Stone", Width = 2.6 },
		},
		-- One-part models the game sizes itself: it sets their Size, which stretches the model
		-- to fill that box. A log on the ground (Server/Systems/LogManager), a felled tree's
		-- stump (TreeManager), and the Elder Hollow's trunk, crown blocks and roots (BossManager).
		Log = "Log",
		Stump = "Stump",
		Boss = { Trunk = "ElderTrunk", Crown = "ElderCrown", Root = "ElderRoot" },
		-- The Tool Shed and the sawmills (Server/Build/ToolShed and SawmillBuilding). Their
		-- models are made for Shop.BuildingSize 56 x 18 x 38 with a 12 x 13 door, and for
		-- Sawmill.BuildingSize 20 x 11 x 14. If you change those, the game says so in the
		-- Output and builds that building from parts instead.
		Buildings = {
			ToolShedShell = "ToolShedShell",
			Stove = "Stove",
			Armchair = "Armchair",
			Barrel = "Barrel",
			Crate = "Crate",
			UpgradeBench = "UpgradeBench",
			HangingLamp = "HangingLamp",
			SawmillShed = "SawmillShed",
			SawTable = "SawTable",
			SawBlade = "SawBlade", -- resized to Sawmill.SawSize
			WaterWheel = "WaterWheel", -- resized to Sawmill.WheelRadius
			Workshop = "Workshop",
			LogPile = "LogPile",
		},
		FitTolerance = 0.05, -- how far (5%) a model's size may be off before the parts are used
	},

	-- Little things scattered over each zone's ground (see Server/Build/Details): grass and
	-- flowers, ferns and glowing mushrooms, dead leaves and bones. Only for looks: you walk
	-- through them and clicks go through them. Fewer of them = faster on phones.
	Details = {
		PathGap = 6.5, -- studs from the middle of the path (it's 8 wide, plus its dirt edge)
		EdgeGap = 4, -- studs from the walls
		BorderGap = 10, -- studs from a border between two zones (the gatehouses, ridge and wall)
		FallbackShare = 0.4, -- without the models: only this share of them, made of a few parts each
		Zones = zoneDetails, -- what's on each zone's ground (at the top of this file)
	},

	-- What you see at the forest's edges, in front of the invisible walls (see Server/Build/Edges).
	Edges = {
		HedgeLength = 12, -- studs per piece of hedge along the outside walls
		HedgeOffset = 1.6, -- the hedge's middle is this far past the walls' inside, so you bump into its leaves
		HedgeHeight = { 6, 11 }, -- lowest and highest (only for the parts version, without the models)
		-- The hedge's colour next to the camp and zone 1, zone 2 and zone 3.
		HedgeColors = { Color3.fromRGB(55, 110, 45), Color3.fromRGB(78, 100, 72), Color3.fromRGB(38, 52, 40) },
		TwigZone = 3, -- from this zone on, dark dead twigs poke out of the hedge
		TwigColor = Color3.fromRGB(58, 42, 36),
		BoulderEvery = 26, -- studs between the boulders at the hedge's foot
		BoulderSize = { 2, 3.5 },
		-- A rocky ridge (Border = "Ridge")
		RidgeSpacing = 9, -- studs between rocks (they're wider than that, so they overlap)
		RidgeRockSize = { 8, 11 },
		RidgeColor = Color3.fromRGB(143, 150, 163),
		RidgeTreeChance = 0.3, -- this share of the rocks has a little tree on top
		RidgeTreeScale = 0.5,
		-- A crumbling stone wall (Border = "StoneWall")
		StoneWallLength = 8, -- studs per piece
		StoneWallHeight = { 3, 7 }, -- lowest and highest (only for the parts version)
		StoneWallGaps = 2, -- pieces on each side that have fallen down into rubble
		StoneWallColor = Color3.fromRGB(107, 103, 117),
		DeadTrees = 4, -- bare trees along the wall
		DeadTreeScale = 0.9,
		-- The gatehouse around each gate (which one: Gates.Looks)
		GatehouseWidth = 30, -- the gate plus a tower 7 wide on each side
		LampHeight = 11, -- the lanterns on the towers (only for the parts version)
		LampRange = 20, -- how far their light reaches
		LampBrightness = 1.5,
	},

	-- Soft patches of colour on the ground, so the floors aren't one flat colour, and where two
	-- zones meet each one's colour frays into the other (see Server/Build/Ground).
	Ground = {
		CampPatches = 14,
		ZonePatches = { 30, 34, 38 }, -- in zone 1, 2 and 3
		PatchSize = { 8, 24 }, -- smallest and biggest, in studs
		BlendPatches = 10, -- on each side of a border between two zones
		BlendDepth = 24, -- how far (studs) into the next zone they reach
		CampColors = { Color3.fromRGB(146, 212, 102), Color3.fromRGB(104, 173, 68) },
		-- One list per zone. Each patch picks one colour at random.
		ZoneColors = {
			{ Color3.fromRGB(110, 190, 70), Color3.fromRGB(76, 146, 51), Color3.fromRGB(132, 176, 70) }, -- grass, dark grass, mossy
			{ Color3.fromRGB(111, 138, 98), Color3.fromRGB(85, 72, 58), Color3.fromRGB(72, 98, 70) }, -- grey-green, mud, dark moss
			{ Color3.fromRGB(77, 61, 68), Color3.fromRGB(92, 47, 43), Color3.fromRGB(46, 36, 40) }, -- dusty, dead leaves, dark mud
		},
	},

	-- The camp: a safe area before zone 1 with spawn, the Tool Shed and the first sawmill.
	-- No trees grow here. A river with a bridge runs across its far end (see Server/Systems/CampManager).
	Camp = {
		Length = 150, -- studs from the back hedge to where zone 1 starts
		Spawn = Vector3.new(0, 0, 480), -- where players appear
		GroundColor = Color3.fromRGB(124, 196, 81), -- a bit brighter than zone 1
		RiverWidth = 14,
		RiverGap = 3, -- studs between the river and zone 1
		RiverColor = Color3.fromRGB(90, 169, 230),
		RiverTransparency = 0.35, -- you see the darker riverbed through the water
		RiverbedColor = Color3.fromRGB(52, 98, 118),
		BankColor = Color3.fromRGB(226, 205, 150), -- the sandy banks along both sides
		BankLength = 12, -- studs per piece of bank (each one a little longer or shorter)
		RiverRocks = 6, -- small rocks sticking out of the water
		RiverReeds = 12, -- clumps of reeds on the banks
		RiverLilyPads = 10,
		BridgeWidth = 16,
		-- The things in the camp (see Server/Build/CampProps). Positions are (X, 0, Z).
		PlazaSize = 24, -- the square of stone tiles around spawn
		Campfire = Vector3.new(30, 0, 466),
		QuestBoard = Vector3.new(-14, 0, 462),
		Well = Vector3.new(-30, 0, 494),
		Signpost = Vector3.new(8, 0, 400), -- just before the bridge
		Benches = { Vector3.new(-9, 0, 440), Vector3.new(9, 0, 440), Vector3.new(-9, 0, 420), Vector3.new(9, 0, 420) },
		FlowerBeds = { Vector3.new(-16, 0, 497), Vector3.new(16, 0, 497), Vector3.new(-16, 0, 463), Vector3.new(16, 0, 463) },
	},

	-- A dirt path from spawn through every gate to the boss. Trees don't grow on it.
	-- Points are (X, Z) on the map, in order. The gates are at X = 0, so the path crosses there.
	-- The path bends smoothly through the points (see Zones.getPathPoints).
	Path = {
		Width = 8,
		TreeClearance = 9, -- no trees closer than this to the middle of the path
		Color = Color3.fromRGB(210, 173, 115),
		Smoothness = 6, -- pieces between two points: more = rounder bends (and more parts)
		EdgeWidth = 1.2, -- a darker strip of dirt along each side
		EdgeColor = Color3.fromRGB(168, 129, 79),
		PebbleSpacing = 7, -- studs between little groups of pebbles along the edges
		Points = {
			Vector2.new(0, 480),
			Vector2.new(0, 370),
			Vector2.new(14, 300),
			Vector2.new(-22, 220),
			Vector2.new(12, 150),
			Vector2.new(0, 110),
			Vector2.new(28, 40),
			Vector2.new(-34, -40),
			Vector2.new(22, -130),
			Vector2.new(0, -190),
			Vector2.new(-24, -280),
			Vector2.new(32, -370),
			Vector2.new(0, -428),
		},
	},

	-- The big things in each zone (see Server/Build/Landmarks). Positions are (X, 0, Z).
	-- No trees grow (and no mimics hide) closer than ClearRadius to them.
	Landmarks = {
		-- Zone 1: Pale Pines
		Lake = { Position = Vector3.new(-70, 0, 255), ClearRadius = 42 }, -- with a sandy beach, a dock and a rowboat
		TentCamp = { Position = Vector3.new(80, 0, 300), ClearRadius = 20 }, -- a lumberjack camp
		Meadow = { Position = Vector3.new(75, 0, 170), ClearRadius = 24 }, -- full of flowers
		-- Zone 2: Fog Hollow
		Swamp = { Position = Vector3.new(80, 0, -20), ClearRadius = 22 },
		SmallSwamp = { Position = Vector3.new(-62, 0, -100), ClearRadius = 17 },
		Windmill = { Position = Vector3.new(85, 0, -150), ClearRadius = 18 }, -- an old ruin
		-- Zone 3: Graveyard Grove
		Graveyard = { Position = Vector3.new(80, 0, -320), ClearRadius = 32 },
		Crypt = { Position = Vector3.new(-75, 0, -400), ClearRadius = 17 },
	},

	-- Little things along the path and around the zones (see Server/Systems/LandmarkManager).
	-- Only for looks: you can't chop them.
	Props = {
		-- Props along the path come in little groups, with empty stretches in between.
		GroupSpacing = { 35, 50 }, -- studs between groups (picked at random each time)
		GroupSize = { 2, 4 }, -- props in a group
		GroupSpread = 4, -- how far (studs) a group's props spread along the path
		PathOffset = 5.4, -- how far from the middle of the path (the path is 8 wide, trees stay 9 away)
		LampSpacing = 42, -- in zones 2 and 3, a lamp post every this many studs, on alternate sides
		GateGap = 14, -- no props this close to a gate or the bridge
		FogBanks = 9, -- drifting fog in zone 2
		FogDrift = 14, -- studs each fog bank drifts to each side
		FogDriftSpeed = 0.12, -- how fast it drifts (lower = slower)
		Flicker = 0.3, -- how much the crooked lamps in zone 3 flicker (0 = steady)
		WindmillSpin = 0.15, -- the broken windmill's sails turn very slowly (radians per second)
		BossStones = 11, -- tall stones in a ring around the boss's clearing
		BossStoneRadius = 34,
	},

	-- Gates between zones
	Gates = {
		Width = 16,
		DoorHeight = 14, -- the door you see; the invisible wall above it goes up to Forest.WallHeight
		DoorDepth = 1,
		Looks = gateLooks, -- the door, gatehouse and border of each gate (at the top of this file)
		OpenTime = 2, -- seconds the gate takes to sink into the ground
		MessageCooldown = 3, -- seconds between "Clear every tree first" messages for one player
	},

	-- Each zone's light, fog and background sound (the Look in each zone above) fade in when you walk in.
	ZoneLook = {
		FadeTime = 3, -- seconds the change takes
		Refresh = 0.5, -- seconds between checks of which zone you're in
		ShadowSoftness = 0.3, -- 0 = sharp shadows, 1 = very soft
		BloomIntensity = 0.4, -- a soft glow around bright things
		BloomSize = 24,
		BloomThreshold = 0.95,
		SunRaySpread = 0.3, -- how wide the sun's rays fan out (0 to 1); how strong they are is in each zone's Look
	},

	-- The intro when you join (see Client/Controllers/IntroController): the camera flies over
	-- the forest, then the title and a PLAY button show while it circles over the camp.
	-- PLAY swoops the camera down behind your character. Positions are (X, Y, Z) on the map.
	Intro = {
		Enabled = true, -- false skips it (handy when you're testing other things in Studio)
		Title = "CHOP A HAUNTED FOREST",
		Subtitle = "Chop every tree... but watch out for the mimics!",
		FadeTime = 1, -- seconds the screen takes to fade in from black at the start
		CutTime = 0.35, -- seconds of black between two camera shots
		BarSize = 0.08, -- black bars at the top and bottom during the flyover, as a share of the screen
		-- Each shot moves the camera from From to To while it turns from looking at LookFrom
		-- to looking at LookTo, over Time seconds.
		Shots = {
			{ -- the camp: spawn, the Tool Shed and the sawmill
				From = Vector3.new(-70, 40, 510),
				To = Vector3.new(60, 32, 502),
				LookFrom = Vector3.new(-10, 4, 455),
				LookTo = Vector3.new(10, 4, 440),
				Time = 4,
			},
			{ -- Pale Pines and the lake
				From = Vector3.new(10, 55, 345),
				To = Vector3.new(-20, 45, 310),
				LookFrom = Vector3.new(-60, 0, 260),
				LookTo = Vector3.new(-75, 0, 230),
				Time = 3.5,
			},
			{ -- the fog of Fog Hollow and the broken windmill
				From = Vector3.new(10, 35, -70),
				To = Vector3.new(25, 28, -105),
				LookFrom = Vector3.new(80, 12, -140),
				LookTo = Vector3.new(85, 12, -150),
				Time = 3.5,
			},
			{ -- the graveyard, where the Elder Hollow waits
				From = Vector3.new(0, 26, -250),
				To = Vector3.new(30, 20, -275),
				LookFrom = Vector3.new(70, 4, -320),
				LookTo = Vector3.new(80, 4, -330),
				Time = 4,
			},
		},
		-- Behind the title, the camera circles slowly around this spot over the camp.
		OrbitCenter = Vector3.new(0, 4, 455),
		OrbitRadius = 55, -- small enough that the camera stays inside the camp, clear of the big trees behind it
		OrbitHeight = 42,
		OrbitSpeed = 0.06, -- radians per second (lower = slower)
		SwoopTime = 1.6, -- seconds the camera takes to swoop down behind your character after PLAY
		SwoopOffset = Vector3.new(0, 6, 14), -- where the camera ends up, seen from your character
	},

	-- The cartoony look (see STYLE_GUIDE.md): colours and fonts for buildings, signs and the UI.
	Style = {
		TitleFont = Enum.Font.LuckiestGuy, -- big words: signs, "FOREST CLEARED!"
		BodyFont = Enum.Font.FredokaOne, -- everything else
		TextStroke = 3, -- the black outline around text, in pixels
		Wood = Color3.fromRGB(168, 105, 58), -- cabin walls and signs
		DarkWood = Color3.fromRGB(95, 60, 30), -- borders and the lines between logs
		Roof = Color3.fromRGB(125, 55, 35),
		InnerWood = Color3.fromRGB(235, 200, 150), -- the inside of a tree: stump tops and log ends
		Rings = Color3.fromRGB(205, 160, 105), -- growth rings on stump tops and log ends
		BirchMark = Color3.fromRGB(45, 42, 40), -- the dark marks on birch bark
		HazardYellow = Color3.fromRGB(250, 210, 30), -- the striped edge around sell pads
		HazardBlack = Color3.fromRGB(30, 30, 30),
		Window = Color3.fromRGB(190, 230, 255),
		Metal = Color3.fromRGB(175, 182, 195), -- saw blades
		-- The UI (see Client/UiKit): white text with a black outline on dark, rounded boxes,
		-- and wooden panels for menus.
		Box = Color3.fromRGB(30, 26, 24), -- HUD boxes
		BoxTransparency = 0.2,
		BoxStroke = 2, -- the black border around boxes, panels and buttons, in pixels
		PanelStroke = 4, -- the dark wood border around menus
		Corner = 10, -- how round the corners are, in pixels
		CardWood = Color3.fromRGB(125, 80, 45), -- the rows inside a wooden menu
		Gold = Color3.fromRGB(255, 215, 70), -- coins and headings
		Ember = Color3.fromRGB(255, 130, 60),
		Cream = Color3.fromRGB(245, 225, 190), -- small text on wood
		Green = Color3.fromRGB(90, 200, 70), -- buy buttons and progress bars
		Red = Color3.fromRGB(220, 50, 50), -- close buttons, "can't afford", full backpack
		Grey = Color3.fromRGB(125, 118, 110), -- buttons you can't press (Owned, MAX)
		BarBack = Color3.fromRGB(55, 45, 40), -- the empty part of a progress bar
	},

	-- Scenery around the forest, only for looks: you can't chop it (see Server/Systems/SceneryManager).
	Scenery = {
		FenceColor = Color3.fromRGB(120, 78, 45), -- wooden fences (see Build/Props)
		OutsideGround = Color3.fromRGB(85, 160, 55), -- the grass around the forest (the baseplate and the big tiles below)
		BorderTreeSpacing = 14, -- studs between the big trees just outside the walls
		BorderTreeDistance = 10, -- studs from the wall to the first row of them
		BorderTreeRows = 2, -- rows of them, one behind the other
		BorderTreeRowGap = 16, -- studs between the rows
		BorderTreeRowSpacing = 1.4, -- each row further out has its trees this much further apart
		BorderTreeScale = { 1.4, 2.1 }, -- smallest and biggest: bigger than forest trees, so they show above the hedge
		-- Rolling hills with little trees, behind the border trees
		HillCount = 24, -- all the way around the forest
		HillDistance = { 60, 100 }, -- studs from the forest's edge to the middle of each hill
		HillWidth = { 100, 160 },
		HillSink = 1, -- hills sit this far down, so their flat edge is under the grass
		HillColor = Color3.fromRGB(85, 150, 55),
		FarTreeColor = Color3.fromRGB(48, 100, 50), -- the little trees on the hills
		-- Mountain ranges in two rings: a near one, and a far one that's paler and bluer, so it
		-- looks further away.
		MountainCount = 18,
		MountainDistance = 320, -- studs from the forest's edge to the near ring
		MountainWidth = { 220, 330 }, -- how wide each range is
		MountainColor = Color3.fromRGB(110, 120, 138),
		SnowColor = Color3.fromRGB(245, 248, 252),
		FarMountainCount = 14,
		FarMountainDistance = 560,
		FarMountainWidth = { 320, 480 },
		FarMountainColor = Color3.fromRGB(150, 165, 188),
		FarSnowColor = Color3.fromRGB(226, 234, 245),
		SnowCap = 0.3, -- without the models: the top 30% of each (block) mountain is snow
		-- Big flat ground tiles under everything (3 x 3 of them, each 2048 studs, as big as a part
		-- can be), so you never see the edge of the baseplate behind the far mountains.
		OutsideTiles = 3,
	},

	Sounds = sounds,
	Particles = particles,

	-- World sounds and particles (see Server/Systems/EffectsManager)
	Effects = {
		SoundRange = 80, -- world sounds are heard up to this many studs away (unless a sound sets its own Range)
		SoundFullVolume = 10, -- ...and are at full volume within this many studs
	},

	-- Chop effects, only for looks: every player draws them on their own screen
	-- (see Client/Controllers/ChopEffectsController).
	-- How many chips, how big, how hard the crown sways and your camera jolts is set per
	-- tool in chopFeel at the top of this file.
	ChopEffects = {
		ImpactDelay = 0.12, -- seconds from your click to the moment your swing hits the tree (in first person: when the fist lands, FirstPerson.PunchOut)
		PitchJitter = 0.08, -- each hit sounds up to 8% higher or lower, so it never sounds the same twice
		ChipSpeed = 16, -- the little wood cubes that fly out of the cut
		ChipLifetime = 1.2, -- seconds before a chip fades away
		MaxChips = 80, -- never more chips than this at once (keeps phones fast)
		WobbleTime = 0.35,
		PuffCubes = 5, -- little beige cubes that puff out where a swing hits
		PuffSize = 0.5,
		PuffTime = 0.35,
		-- A warm glow bursts out of the cut on every hit, like light shining out of the wood.
		GlowTime = 0.3, -- seconds it takes to fade
		GlowColor = Color3.fromRGB(255, 236, 175), -- warm white-yellow
		GlowSize = 1.3, -- how big it starts, compared to the cut's opening
		GlowGrow = 1.8, -- how much bigger it gets while it fades
		GlowBrightness = 4, -- the light it casts around the cut
		GlowRange = 9, -- studs
		ChipsToPlayer = 0.7, -- 0 = chips fly straight out of the cut, 1 = straight at the player who hit
		-- Long thin splinters fly out with the chips.
		SplintersMin = 1,
		SplintersMax = 2,
		SplinterSize = Vector3.new(0.1, 0.1, 0.7),
		-- Fine sawdust drifts down from the cut.
		SawdustBits = 6,
		SawdustSize = 0.12,
		SawdustTime = 1.4, -- seconds before it's gone
		SawdustFall = 1.5, -- studs per second it sinks
		-- A few leaves come loose from the crown on every hit and flutter down.
		HitLeavesMin = 2,
		HitLeavesMax = 3,
		LeafSize = 0.5, -- studs
		LeafFallSpeed = 2.2, -- studs per second they sink
		LeafFlutter = 1.2, -- studs they sway from side to side while they fall
		LeafFallTime = 2.5, -- seconds before a falling leaf is gone
		KickTime = 0.12, -- seconds your camera jolts on your own hits
		KickPush = 0.12, -- studs your camera is pushed towards the tree on your own hits
		KickTilt = 0.8, -- degrees it nods down with it
		-- Your own hits show the moment your swing lands. When the server then says the hit
		-- counted, it isn't shown again if it was shown this many seconds ago.
		ShownWindow = 0.5,
		EffectsDistance = 150, -- you only see effects on trees this close
		ShakeDistance = 45, -- your camera shakes when a tree lands this close to you
		ShakeStrength = 0.25, -- studs the camera moves at most
		ShakeTime = 0.3,
		DustCubes = 15, -- grey cubes in the puffs along a tree that lands (shared by 3 puffs)
		DustSize = 1.4,
		DustTime = 0.9,
		DustColor = Color3.fromRGB(205, 190, 165),
		LeafCubes = 10, -- leaf cubes that fly off the crown when a tree lands
		LeafCubeSize = 0.9,
		LeafTime = 1.2,
	},

	-- The health bar under the crosshair while you aim at a tree (see Client/Controllers/TreeHpController).
	-- Only shows when ShowTreeHpBar (above) is true.
	TreeHpBar = {
		Below = 26, -- pixels from the middle of the screen (or the mouse) down to the tree's name
		Width = 150, -- pixels
		BarHeight = 22,
		NameHeight = 22,
		Text = "%.1f/%.1f HP", -- HP left / max HP, with one decimal
		-- The fill changes colour as the tree loses HP: green, then yellow, orange and red, and
		-- grey at 0. Each colour is used down to its share of HP left.
		Colors = {
			{ Above = 0.75, Color = Color3.fromRGB(90, 200, 70) },
			{ Above = 0.5, Color = Color3.fromRGB(240, 210, 50) },
			{ Above = 0.25, Color = Color3.fromRGB(240, 140, 40) },
			{ Above = 0, Color = Color3.fromRGB(220, 50, 50) },
		},
		EmptyColor = Color3.fromRGB(125, 118, 110),
	},

	-- "TIMBER!" over the cut when a tree falls (see Client/Controllers/ChopEffectsController).
	-- Only shows when ShowTimberText (above) is true.
	Timber = {
		Text = "TIMBER!",
		Color = Color3.fromRGB(255, 190, 40), -- orange-yellow
		StrokeColor = Color3.fromRGB(80, 45, 20), -- dark brown outline
		Size = Vector2.new(320, 100), -- pixels: width, height (the same size on screen however far away the tree is)
		Above = 1, -- studs above the cut
		ScaleIn = 0.15, -- seconds it pops in
		Hold = 0.6, -- seconds it stays
		FadeTime = 0.3, -- seconds it fades away
	},

	-- First person (see Client/Controllers/ViewmodelController). The camera sits in your head, and
	-- only you see your own two blocky forearms and fists at the bottom of the screen. Each swing
	-- jabs one fist (left, right, left...), or swings the tool you hold in your right hand.
	-- A small hollow circle in the middle of the screen shows what you'll hit.
	FirstPerson = {
		FirstPersonOnly = true, -- false = the old camera behind your character, aiming with the mouse
		SkinColor = Color3.fromRGB(245, 205, 160), -- only used if your character's arm colour can't be found
		ForearmSize = Vector3.new(0.8, 0.8, 4), -- studs: width, height, length (long, so its end never shows mid-punch)
		FistSize = Vector3.new(1.05, 1.05, 1.05),
		Roundness = 0.22, -- how round the corners of the fists and forearms are (0 = sharp, 0.5 = very round)
		RestOffset = Vector3.new(1.15, -1.05, -2.3), -- where the right fist rests, seen from the camera (the left one is mirrored)
		RestPitch = 14, -- degrees the forearms tilt up from the bottom of the screen
		RestYaw = 10, -- degrees they point in towards the middle
		-- A punch (see ViewmodelController): a short wind-up, a jab that speeds up until it
		-- lands, a tiny freeze when it hits the bark, then it springs back and settles.
		PunchOut = 0.12, -- seconds from the click to the fist landing (wind-up + jab)...
		PunchBack = 0.2, -- ...and seconds to spring back to rest
		WindUp = 0.25, -- studs the fist pulls back before it jabs
		WindUpShare = 0.3, -- share of PunchOut spent pulling back
		PunchReachMin = 0.8, -- studs a fist jabs forward: it stops at the bark you aim at,
		PunchReachMax = 2.2, -- ...but always moves at least Min and never more than Max
		PunchTwist = 25, -- degrees the fist turns as it jabs
		HitStop = 0.04, -- seconds the fist freezes against the bark on a hit (makes it feel solid)
		HitShake = 0.02, -- studs it shivers during that freeze
		RecoilSpeed = 9, -- studs per second it bounces back off the bark
		AirFollow = 4, -- studs per second it keeps going when you punch thin air
		ReturnBounce = 0.55, -- how springy the return is: lower bounces more, 1 = no bounce
		CounterPull = 0.12, -- the other fist pulls back this share of the jab
		ToolPitch = 30, -- degrees a held tool leans up from pointing straight ahead
		ToolGrip = 0.25, -- where your fist holds a tool's handle: 0 = its end, 0.5 = its middle
		ToolSwingAngle = 65, -- degrees a tool chops down in a swing (smaller for the Chainsaw, see SwingSize in chopFeel)
		CrosshairSize = 14, -- pixels across
		CrosshairThickness = 2, -- pixels
		CrosshairColor = Color3.fromRGB(255, 255, 255),
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
		Position = Vector3.new(0, 0, -470), -- where it stands (height is found automatically)
		ClearRadius = 40, -- no trees grow (and no mimics hide) this close to it
		TrunkHeight = 40,
		TrunkWidth = 10,
		CrownSize = 30, -- the ball of leaves on top
		RootCount = 4, -- weak points around its base
		RootHP = 300, -- HP of each root. The boss's HP bar is all its roots added up.
		RootLength = 12,
		RootThickness = 3,
		SparksPerHit = 10, -- glowing sparks when a root is hit
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
		SizeSpread = 0.15, -- each tree is up to 15% bigger or smaller, so they don't look copied
		LeavesSize = 10, -- the biggest leaf block (the others are a bit smaller)
		LeafMaterial = Enum.Material.SmoothPlastic,
		RootCount = 4, -- little blocks that flare out at the bottom of the trunk
		RootLength = 1.6, -- how far a root sticks out past the trunk
		RootHeight = 1.6,
		BirchMarks = 6, -- dark marks on each side of a birch trunk
		BirchName = "Birch", -- a birch's name on the tree HP bar, when it's built from parts
		MinTrunkScale = 0.4, -- the boss's trunk width at 0 HP, compared to full width (shows damage)
		-- Hitting a tree cuts into it where you aim: see Cut below.
		-- A felled tree cracks, falls, bounces, lies there and fades away. Every player's
		-- computer animates it (see Client/Controllers/ChopEffectsController).
		CrackTime = 0.35, -- seconds it shudders and creaks before it tips over
		CrackLean = 3, -- degrees it leans while it cracks
		FallTime = 1.1, -- seconds it takes to fall (slow at first, then faster)
		BounceAngle = 6, -- degrees it bounces back up when it hits the ground
		BounceTime = 0.3,
		RemoveDelay = 1.5, -- seconds a fallen tree lies there before it fades away
		FadeTime = 0.5, -- seconds it takes to sink into the ground and fade
		SinkDepth = 1.5, -- studs it sinks while it fades
		LogsPerTree = 3,
		StumpHeight = 1.2, -- the stump a felled tree leaves behind
	},

	-- Carving (see Server/Build/Carve), like in Chop a Forest: every hit scoops a round hole out
	-- of the trunk where you aim. Hit the same spot and the dent gets wider and deeper; hit
	-- somewhere else and a new dent starts there. The trunk has layers like a real one (bark,
	-- pale wood, a darker ring, a pale heart), so a dent shows a dark bark rim, then pale wood,
	-- then the ring. At 0 HP the tree breaks at its deepest dent.
	Cut = {
		BarkThickness = 0.1, -- how thick the bark is, as a share of the trunk's width
		RimShade = 0.3, -- the bark around a dent is this much darker than the bark (0 = the same, 1 = black)
		RingWidth = 0.55, -- the darker ring's outside, as a share of the trunk's width
		HeartWidth = 0.3, -- the pale heart in the middle
		InnerColors = {
			Color3.fromRGB(235, 200, 150), -- pale wood (and the heart)
			Color3.fromRGB(205, 160, 105), -- the darker ring
		},
		HoleSize = 0.24, -- a punch's hole: its radius as a share of the trunk's width
		HitsPerTree = 10, -- HoleSize is for a hit that takes this share of a tree's HP (1/10: a punch on an oak)
		MinHoleScale = 0.7, -- smaller hits still scoop at least this big a hole (compared to HoleSize)...
		MaxHoleScale = 2, -- ...and big tools at most this big
		HoleOut = 0.45, -- how far out of the wood each hole's middle sits (share of its radius): a new dent starts as a shallow bowl
		DigStep = 0.45, -- each hit on a dent digs this much deeper (share of the hole's radius)
		MaxDepth = 0.5, -- the deepest a hole's middle goes: this far past the middle of the trunk (share of half its width), so a dent gets almost all the way through
		HoleJitter = 0.15, -- holes are shifted a little at random, so dents look natural
		SplitGap = 0.2, -- studs of wood that vanish where the tree breaks
		PointMargin = 1, -- studs the aimed point may be outside the trunk (lag, moving mimics)
		HeadReachExtra = 2, -- studs added to the tool's Reach, measured from your head to the point you hit
	},

	Tools = tools,
	ChopFeel = chopFeel,
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
		Scatter = 3, -- logs land up to this many studs to the side of the fallen trunk
		-- Logs pop out of the fallen trunk in a little arc (every player's computer animates it).
		PopStart = 1.5, -- studs above the ground they start, inside the fallen trunk
		PopHeight = 3, -- how high the arc goes
		PopTime = 0.55, -- seconds from popping out to lying still (the Log Vacuum waits this long)
	},

	-- Coins (per player, reset every run, not saved)
	-- How much a log is worth depends on its tree (see TreeTypes and Cursed).
	Coins = {
		Starting = 0,
	},

	-- Sawmills (one per zone; positions are in Zones above). See Server/Build/SawmillBuilding.
	Sawmill = {
		BuildingSize = Vector3.new(20, 11, 14), -- the open-fronted mill shed
		RoofHeight = 6,
		PadSize = 8, -- the "DROP LOGS" pad is this many studs wide and deep
		SellCooldown = 1, -- seconds between sells for one player (stops double-selling)
		SawSize = 6, -- how wide the big round saw is
		WheelRadius = 5, -- the water wheel on the side
		SawSpin = 6, -- how fast the saw turns (radians per second, only for looks)
		WheelSpin = 0.7, -- how fast the water wheel turns
		SpinDistance = 250, -- the saw and wheel only turn on your screen when you're this close
		Wear = { 0, 0.15, 0.28 }, -- how much darker each zone's sawmill is: zones 2 and 3 are old and worn
	},

	-- Tool Shed (in the camp, across the path from the sawmill)
	Shop = {
		-- A big cabin that fills the camp's left side, between the river and spawn.
		Position = Vector3.new(-62, 0, 430), -- center of the building (height is found automatically)
		Turn = 90, -- degrees: 0 = the door faces spawn's side (+Z), 90 = the middle of the camp (+X)
		-- Width, wall height, depth. The room inside is laid out to fit whatever size this is,
		-- and the furniture stays player-sized (see Build/ToolShed).
		BuildingSize = Vector3.new(56, 18, 38),
		DoorWidth = 12,
		DoorHeight = 13,
		RoofHeight = 12,
		PromptDistance = 10, -- how close to the counter (inside) you must be to see "Open shop"
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
