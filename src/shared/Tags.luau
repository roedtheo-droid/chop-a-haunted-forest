--!strict
-- CollectionService tag names, shared by the server and the client.
-- Using these constants instead of typing "Tree" everywhere avoids typo bugs.

local Tags = {
	Tree = "Tree", -- a standing tree that can be chopped
	Log = "Log", -- a log lying on the ground
	ShopPrompt = "ShopPrompt", -- the "Open shop" prompt at the Tool Shed
	BuyPrompt = "BuyPrompt", -- a "Buy" prompt on a tool's board in the Tool Shed (its ItemId attribute says which)
	AwakeMimic = "AwakeMimic", -- a mimic that woke up and is chasing players (it can still be chopped)
	RevivePrompt = "RevivePrompt", -- the "Revive" prompt on a knocked-down player
	ElderHollow = "ElderHollow", -- the final boss (its trunk can't be chopped)
	BossRoot = "BossRoot", -- one of the Elder Hollow's roots, its weak points
	Spinner = "Spinner", -- a model that turns all the time, like a saw or a water wheel (see SpinnerController)
	FogBank = "FogBank", -- a fog cloud in zone 2 that drifts slowly (see AmbientController)
	Flicker = "Flicker", -- a lamp's light that flickers a little (see AmbientController)
	Landowner = "Landowner", -- Mr. Graves, the NPC at the vault (see LandownerController)
	LandownerPrompt = "LandownerPrompt", -- his "Talk" prompt
	GaragePad = "GaragePad", -- the glowing pad in front of the Garage (see GarageController)
	SellBillboard = "SellBillboard", -- the floating SELL LOGS billboard over a sawmill's pad (see SellYardController)
}

return table.freeze(Tags)
