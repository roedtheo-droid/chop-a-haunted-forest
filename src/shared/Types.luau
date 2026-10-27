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
}

-- One kind of tree (see Config.TreeTypes). Each zone has its own kind.
export type TreeTypeConfig = {
	MaxHP: number,
	LogValue: number, -- coins for each log from this tree
	Scale: number, -- size compared to Config.Tree (1 = normal, 1.3 = 30% bigger)
	TrunkColors: { Color3 }, -- each tree picks one at random
	LeafColors: { Color3 }, -- each tree picks one at random
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
