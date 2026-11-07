--!strict
-- Shared type definitions used by both the server and the client.

-- Every server system and client controller looks like this.
-- init(): set things up (create instances, connect nothing that depends on others).
-- start(): begin running (connect events, start loops). Runs after every init() is done.
export type Module = {
	init: () -> (),
	start: () -> (),
}

-- What kind of remote an entry in Remotes.luau is.
export type RemoteKind = "Event" | "Function"

-- Numbers for one chopping tool (see Config.Tools).
export type ToolConfig = {
	Damage: number, -- damage per hit
	Cooldown: number, -- seconds between hits
	Reach: number, -- studs from the player to the trunk's edge
	Price: number, -- coins in the Tool Shed (0 = you start with it)
}

-- How one chopping tool FEELS when it hits (see Config.ChopFeel and
-- Client/Controllers/ChopEffectsController). Only looks and sounds: its damage is in ToolConfig.
export type ChopFeelConfig = {
	Sound: string, -- a name in Config.Sounds
	-- Your character's swing: a Roblox animation ("rbxassetid://..."), played at SwingSpeed
	-- (1 = its normal speed). Tools in Config.ChopAnims or Config.SawAnims have none: code moves
	-- the arms instead (see Client/Controllers/ToolAnimController).
	Swing: string?,
	SwingSpeed: number?,
	ChipsMin: number, -- wood chips that fly out of the cut on each hit: a random number from ChipsMin...
	ChipsMax: number, -- ...to ChipsMax
	ChipSize: number, -- how big each chip is, in studs
	Wobble: number, -- degrees the crown sways when the tree is hit
	CameraKick: number, -- studs your camera jolts on your own hits
}

-- Where your hands are in one moment of a tool animation (see Config.ChopAnims and SawAnims).
-- First person (ViewmodelController): Move is studs from where your right fist rests
-- (right, up, back), Turn is degrees (tip back, turn left, lean left) around your forearm.
-- Third person (ToolAnimController): degrees added to each joint of your character.
-- X lifts an arm forward (and leans the waist back), Y twists it, Z swings it sideways
-- (for the left arm: in towards the middle).
export type HandPose = {
	Move: Vector3,
	Turn: Vector3,
}
export type BodyPose = {
	RightArm: Vector3,
	LeftArm: Vector3,
	Waist: Vector3,
}

-- How an axe swings (see Config.ChopAnims): lift it back, chop down faster and faster, stick
-- in the bark for a split second (or swing on through the air on a miss), then come back.
-- The times are seconds; a whole swing is sped up when the tool's cooldown is shorter.
export type ChopAnimConfig = {
	WindUpTime: number, -- lifting the axe back
	StrikeTime: number, -- chopping down (the hit lands at WindUpTime + StrikeTime)
	HitStop: number, -- stuck in the bark
	HitShake: number, -- studs it shivers while stuck
	FollowTime: number, -- on a miss: swinging on through the air
	ReturnTime: number, -- back to rest
	Bounce: number, -- how far it swings past rest on the way back (0 = none)
	-- First person
	ToolPitch: number, -- degrees the axe leans up from your fist
	Pivot: number, -- studs behind your fist that your arm turns around (your elbow)
	RightHand: Vector3, -- where your right fist holds the tool, from the middle of its handle
	LeftHand: Vector3, -- ...and your left fist
	LeftTurn: Vector3, -- degrees the left fist is turned from the right one
	Rest: HandPose,
	WindUp: HandPose,
	Strike: HandPose,
	Follow: HandPose,
	-- Third person
	BodyHold: BodyPose,
	BodyWindUp: BodyPose,
	BodyStrike: BodyPose,
}

-- How the Chainsaw moves (see Config.SawAnims): it buzzes in your hands while you hold it.
-- Hold the mouse button and it pushes forward, saws back and forth, shakes harder, the chain
-- runs and the engine revs.
export type SawAnimConfig = {
	RevHold: number, -- seconds after your last swing that it still counts as cutting
	Blend: number, -- how fast it moves between holding and cutting (higher = faster)
	StrokeSpeed: number, -- saw strokes per second while cutting
	-- First person
	ToolPitch: number,
	Pivot: number,
	RightHand: Vector3,
	LeftHand: Vector3,
	LeftTurn: Vector3,
	Rest: HandPose,
	Cut: HandPose,
	Stroke: number, -- studs it moves forward and back with each stroke
	IdleShake: number, -- studs it buzzes while you just hold it...
	CutShake: number, -- ...and while you cut
	ChainSpeed: number, -- studs per second the chain teeth run along the bar while you cut
	-- Third person
	BodyHold: BodyPose,
	BodyCut: BodyPose,
	BodyStroke: number, -- degrees the arms move with each stroke
	BodyIdleShake: number, -- degrees the arms buzz while holding...
	BodyCutShake: number, -- ...and while cutting
	-- The engine: a looped sound in the saw, heard by everyone near you.
	Engine: string, -- a name in Config.Sounds
	IdleSpeed: number, -- the engine sound's speed while you just hold it...
	CutSpeed: number, -- ...and while you cut (higher sounds like revving)
	IdleVolume: number, -- share of the sound's Volume while you just hold it (1 while cutting)
}

-- Numbers for one upgrade (see Config.Upgrades).
-- Prices[1] is the price of level 1, Prices[2] of level 2, and so on.
-- The max level is the number of prices.
export type UpgradeConfig = {
	PerLevel: number, -- how much each level adds
	Prices: { number },
}

-- One thing you can buy in the Tool Shed (see Shared/Shop.luau).
export type ShopItem = {
	Id: string,
	Kind: "Tool" | "Upgrade",
	Name: string,
	Description: string,
	Requires: string?, -- a tool you must own before you can buy this (like "Lantern")
}

-- One kind of tree (see Config.TreeTypes). Each zone has its own kind.
export type TreeTypeConfig = {
	Name: string, -- shown on the tree HP bar when it's built from parts (Blender shapes have their own Name)
	MaxHP: number,
	LogValue: number, -- coins for each log from this tree
	Scale: number, -- size compared to Config.Tree (1 = normal, 1.3 = 30% bigger)
	TrunkColors: { Color3 }, -- each tree picks one at random
	LeafColors: { Color3 }, -- each tree picks one at random (list a colour twice to make it more common)
	LeafBlocks: number, -- how many leaf blocks make up its crown (0 = a bare, dead tree)
	Branches: number?, -- bare branches sticking out of the trunk (for dead trees)
	BirchChance: number?, -- 0 to 1: share of trees that are white birches with dark marks
	BirchColor: Color3?, -- a birch's bark colour
	-- Blender models (Config.Models.Trees) for this tree type, and how often each is picked
	-- (like { Oak = 0.6, Pine = 0.4 }). Not set: the tree is built from parts.
	Shapes: { [string]: number }?,
	BirchShapes: { [string]: number }?, -- the same, for this type's birches
}

-- One tree shape made in Blender (see Config.Models.Trees and blender/models/trees.py).
export type TreeShapeConfig = {
	Name: string, -- shown on the tree HP bar, like "Oak"
	TrunkWidth: number, -- the trunk's width at Scale 1, the same as blender/ builds it
	LeafColors: { Color3 }?, -- its own leaf colours (not set: the tree type's LeafColors)
}

-- A prop made in Blender (see Config.Models.Props and blender/models/props.py).
export type PropModelConfig = {
	Model: string, -- its name in ServerStorage > MapAssets
	Part: string, -- the part the game sizes it by
	Width: number, -- how wide that part is at the size of the parts version, in studs
}

-- How Blocky.dress colours one kind of part of a Blender model (by its name).
export type SkinLook = {
	Color: Color3,
	Material: Enum.Material,
	Solid: boolean?, -- stops players and the camera (the walls and roofs of a building)
}

-- How one kind of part of an imported tool model is coloured (see Config.ToolModels).
export type ToolPaint = {
	Color: Color3,
	Material: Enum.Material,
	Transparency: number?, -- 0 = solid (the default), 1 = invisible
}

-- How a tool model is held (see Config.ToolModels and Server/Systems/ToolManager).
export type ToolModelConfig = {
	Forward: Vector3, -- the direction in the imported model that points away from your hand
	Up: Vector3, -- the direction in the imported model that points up (the axe's blade side)
	Size: number, -- the model's longest side, in studs
	Grip: string, -- the part that sits at GripAt (where your hand holds it)
	GripAt: Vector3, -- where that part goes, seen from the tool's handle (-Z is forward)
	Head: string, -- the part the invisible "Head" sits on (lights, fire, the ghost beam)
	Fire: number?, -- how big the Torch's fire is on this model
	Paint: { [string]: ToolPaint }, -- by part name without the tool's name ("Head", "Shaft")
}

-- One kind of little thing scattered over a zone's ground (see Config.Details).
export type DetailConfig = {
	Model: string, -- the Blender model (see blender/models/details.py)
	Part: string, -- the part it's sized by (its bottom stands on the ground)
	Count: number, -- how many in the zone
	Size: { number }, -- smallest and biggest width of that part, in studs
	Colors: { Color3 }, -- each one picks a colour for its parts
	StemColor: Color3?, -- for parts named Stem and Dot (flowers, mushrooms)
	Glow: boolean?, -- glowing (Neon), and no white dots
}

-- How one gate between two zones looks (see Config.Gates.Looks and Server/Build/Edges).
export type GateLookConfig = {
	Door: "Wood" | "Iron", -- wooden planks, or iron bars you can see through
	Gatehouse: "Log" | "Stone", -- log towers with roofs, or stone pillars with an iron arch
	Border: "Ridge" | "StoneWall", -- along the rest of the border: big rocks, or a crumbling wall
	LampColor: Color3, -- the gatehouse's lanterns
	Flicker: boolean, -- do the lanterns flicker?
}

-- One sound (see Config.Sounds).
export type SoundConfig = {
	Id: string, -- "rbxassetid://123" from the Creator Store, or "rbxasset://sounds/..." built into Roblox
	Volume: number, -- 0 to 1 (0.5 is a good start)
	Speed: number?, -- 1 if not set. Lower is slower and deeper.
	Range: number?, -- world sounds: heard up to this many studs away (Config.Effects.SoundRange if not set)
	MinGap: number?, -- seconds before the same player can make this sound again (stops chainsaw spam)
}

-- One kind of particle burst (see Config.Particles).
export type ParticleConfig = {
	Color: Color3,
	Amount: number, -- particles per burst (or per second for a stream, like burning embers)
	Size: number,
	Speed: number,
	Lifetime: number, -- seconds each particle lives
}

-- How a zone looks: its light and fog (see Client/Controllers/AtmosphereController).
-- It only changes YOUR screen, while you're in that zone.
export type ZoneLookConfig = {
	ClockTime: number, -- time of day, 0 to 24 (14.5 = afternoon, 17.7 = dusk)
	Brightness: number, -- how strong the sunlight is
	Ambient: Color3, -- the light in shadows (darker = gloomier)
	FogDensity: number, -- 0 = clear, 1 = you can't see a thing
	FogOffset: number, -- how far away the fog starts (0 = right in front of you)
	FogColor: Color3,
	FogDecay: Color3, -- the colour of the fog far away
	Haze: number, -- 0 to 10, how washed out the distance looks
	Saturation: number, -- -1 to 1: how strong the colours are (0 = normal, above 0 = more cartoony)
	Tint: Color3, -- the whole screen is tinted a little towards this colour (white = no tint)
	CloudCover: number, -- 0 = a clear sky, 1 = the whole sky is cloud
	CloudDensity: number, -- 0 = thin, wispy clouds, 1 = thick ones
	CloudColor: Color3,
	SunRays: number, -- 0 to 1: soft beams of light when you look towards the sun
	Ambience: SoundConfig, -- a quiet background sound that loops while you're in the zone
}

-- One zone (see Config.Zones). Zones sit in a row, starting at spawn.
export type ZoneConfig = {
	Name: string,
	Length: number, -- how deep the zone is, in studs (along the Z axis)
	TreeCount: number,
	TreeType: string, -- a key in Config.TreeTypes
	GroundColor: Color3,
	GroundMaterial: Enum.Material,
	Sawmill: Vector3, -- where this zone's sawmill stands (height is found automatically)
	ClearRadius: number, -- no trees this close to the sawmill
	MimicPercent: number, -- this % of the zone's trees are secretly mimics
	Look: ZoneLookConfig, -- its light and fog
}

-- One camera shot in the intro flyover (see Config.Intro and Client/Controllers/IntroController).
export type IntroShot = {
	From: Vector3, -- where the camera starts
	To: Vector3, -- where it ends up
	LookFrom: Vector3, -- what it looks at first
	LookTo: Vector3, -- what it looks at last
	Time: number, -- seconds
}

-- What knocked a player down (see Server/Systems/KnockdownManager).
-- It decides how long they're down and what their screen says.
export type KnockdownCause = "Swallowed" | "Slam"

-- The party's totals for one run, shown on the FOREST CLEARED! screen
-- (sent by Server/Systems/RunManager).
export type RunSummary = {
	TreesFelled: number,
	MimicsBurned: number,
	CoinsEarned: number,
	Seconds: number, -- how long the run took
	Embers: number, -- Embers everyone got for clearing the forest
}

-- What gets saved for each player (see Server/Systems/SaveManager).
-- Only plain numbers, strings and tables: DataStores store everything as JSON text.
export type SaveData = {
	Version: number, -- which shape this save has, so old saves can be upgraded later
	Embers: number,
	Stats: { [string]: number }, -- lifetime stats, like Stats.TreesFelled
	Unlocks: { string }, -- permanent unlocks, like "Truck_StakeHauler" (bought with Embers or Robux)
}

-- How a log truck looks, as blocky placeholder parts (see Shared/TruckBuilder).
export type TruckLook = {
	Cab: Color3, -- the cab and hood
	Body: Color3, -- the bed, dump box or canvas
	Trim: Color3, -- bumpers, grille and stacks
	-- What's behind the cab: "Wood" (low wooden sides), "Stakes" (wooden stake sides),
	-- "Flatbed" (long and flat, short stakes), "TallStakes", "Dump" (a dump box),
	-- "Canvas" (an army cover), "LogTrailer" (logs on bolsters), "LogBed" (a tall bed of logs).
	Bed: string,
	Axles: number, -- 2 = 4 wheels, 3 = 6 wheels, 4 = 8 wheels
	Length: number, -- studs from bumper to bumper (before Scale)
	Scale: number, -- 1 = a normal truck; big rigs are bigger
	Rounded: boolean?, -- an old truck with rounded hood and roof
	Sleeper: boolean?, -- a big rig's tall cab with exhaust stacks
}

-- One log truck in the Garage (see Config.Trucks). Speed and Carry are what it does once you
-- drive it; Price is in Currency (for Robux, ProductId is the developer product to sell).
export type TruckConfig = {
	Id: string,
	Name: string,
	Speed: number,
	Carry: number, -- logs its bed holds
	Currency: "Coins" | "Embers" | "Robux",
	Price: number,
	ProductId: number, -- Robux trucks only: 0 means "not on sale yet" (the button says Coming soon)
	Skins: boolean, -- shows the SKINS panel (display only for now)
	Look: TruckLook,
}

-- One tutorial quest (see Config.Quests).
-- Event is what the player has to do; the server reports these events:
--   "FellTree", "PickUpLog", "SellLogs", "BuyAxe", "BuyUpgrade"
export type QuestConfig = {
	Event: string,
	Goal: number, -- how many times
	Text: string, -- what the quest box says
}

return {}
