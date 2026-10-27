--!strict
-- CollectionService tag names, shared by the server and the client.
-- Using these constants instead of typing "Tree" everywhere avoids typo bugs.

local Tags = {
	Tree = "Tree", -- a standing tree that can be chopped
	Log = "Log", -- a log lying on the ground
}

return table.freeze(Tags)
