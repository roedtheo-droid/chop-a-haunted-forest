--!strict
-- CollectionService tag names, shared by the server and the client.
-- Using these constants instead of typing "Tree" everywhere avoids typo bugs.

local Tags = {
	Tree = "Tree", -- a standing tree that can be chopped
	Log = "Log", -- a log lying on the ground
	ShopPrompt = "ShopPrompt", -- the "Open shop" prompt at the Tool Shed
	AwakeMimic = "AwakeMimic", -- a mimic that woke up and is chasing players (it can still be chopped)
	RevivePrompt = "RevivePrompt", -- the "Revive" prompt on a knocked-down player
	ElderHollow = "ElderHollow", -- the final boss (its trunk can't be chopped)
	BossRoot = "BossRoot", -- one of the Elder Hollow's roots, its weak points
	Spinner = "Spinner", -- a model that turns all the time, like a saw or a water wheel (see SpinnerController)
}

return table.freeze(Tags)
