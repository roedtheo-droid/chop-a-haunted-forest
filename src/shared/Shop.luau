--!strict
-- The list of things the Tool Shed sells, in the order the shop shows them.
-- Used by the server (to check purchases) and the client (to draw the shop).
-- Prices and numbers live in Config.Tools / Config.Upgrades.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Shop = {}

local items: { Types.ShopItem } = {
	{ Id = "Axe", Kind = "Tool", Name = "Axe", Description = "Chops twice as hard as fists" },
	{ Id = "SteelAxe", Kind = "Tool", Name = "Steel Axe", Description = "A heavy axe that bites deep" },
	{ Id = "Chainsaw", Kind = "Tool", Name = "Chainsaw", Description = "Hold to rip through trees" },
	{ Id = "Lantern", Kind = "Tool", Name = "Lantern", Description = "Hold it: nearby mimics glow faintly" },
	{ Id = "Torch", Kind = "Tool", Name = "Torch", Description = "Burns sleeping mimics for Embers" },
	{ Id = "ChopDamage", Kind = "Upgrade", Name = "Chop Damage", Description = "+20% damage per level" },
	{ Id = "CarryLimit", Kind = "Upgrade", Name = "Log Sack", Description = "Carry 3 more logs per level" },
	{ Id = "WalkSpeed", Kind = "Upgrade", Name = "Walk Speed", Description = "Walk a bit faster per level" },
	{ Id = "LogVacuum", Kind = "Upgrade", Name = "Log Vacuum", Description = "Nearby logs fly into your sack" },
	{
		Id = "LanternRadius",
		Kind = "Upgrade",
		Name = "Lantern Radius",
		Description = "Lantern sees 5 studs further per level",
		Requires = "Lantern",
	},
}
Shop.Items = table.freeze(items)

local byId: { [string]: Types.ShopItem } = {}
for _, item in items do
	byId[item.Id] = item
end

function Shop.getItem(id: string): Types.ShopItem?
	return byId[id]
end

-- Player attribute names. The server sets them; the client only reads them.
function Shop.ownsAttribute(toolId: string): string
	return `Owns_{toolId}`
end

function Shop.levelAttribute(upgradeId: string): string
	return `Upgrade_{upgradeId}`
end

-- While a player tries a tool (the trial table in the Tool Shed): which tool, and the server
-- time (workspace:GetServerTimeNow()) the trial ends. Both are removed when it ends.
Shop.TRIAL_TOOL = "TrialTool"
Shop.TRIAL_ENDS = "TrialEnds"

function Shop.maxLevel(upgradeId: string): number
	local upgrade = Config.Upgrades[upgradeId]
	return if upgrade then #upgrade.Prices else 0
end

-- Price of a tool, or of the NEXT level of an upgrade. nil means "can't buy" (unknown or max level).
function Shop.priceOf(item: Types.ShopItem, currentLevel: number): number?
	if item.Kind == "Tool" then
		local tool = Config.Tools[item.Id]
		return if tool then tool.Price else nil
	end
	local upgrade = Config.Upgrades[item.Id]
	if not upgrade then
		return nil
	end
	return upgrade.Prices[currentLevel + 1]
end

return Shop
