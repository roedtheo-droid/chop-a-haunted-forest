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

return {}
