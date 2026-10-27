--!strict
-- The ONE list of every remote in the game.
-- The server creates them all at startup (see Server/Systems/RemoteService).
-- The client gets them with Remotes.getEvent / Remotes.getFunction.
--
-- To add a remote: add one line to List below. Nothing else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Types)

local Remotes = {}

-- Name of the folder in ReplicatedStorage that holds every remote.
Remotes.FolderName = "Remotes"

local list: { [string]: Types.RemoteKind } = {
	-- Server -> client: show a short message to one player
	-- (later used for things like "Clear every tree first (N left)").
	Notify = "Event",

	-- Client -> server: "I swung at this tree". The server decides damage.
	SwingAtTree = "Event",

	-- Client -> server: "I want to buy this item" (an item Id from Shared/Shop).
	-- The server checks the price, your coins and that you're at the Tool Shed.
	BuyItem = "Event",
}
Remotes.List = table.freeze(list)

local function getRemote(name: string): Instance
	local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
	return folder:WaitForChild(name)
end

-- Get a RemoteEvent by name. Waits until the server has created it.
function Remotes.getEvent(name: string): RemoteEvent
	assert(list[name] == "Event", `"{name}" is not a RemoteEvent in Remotes.List`)
	local remote = getRemote(name)
	if remote:IsA("RemoteEvent") then
		return remote
	end
	error(`Remote "{name}" exists but is not a RemoteEvent`)
end

-- Get a RemoteFunction by name. Waits until the server has created it.
function Remotes.getFunction(name: string): RemoteFunction
	assert(list[name] == "Function", `"{name}" is not a RemoteFunction in Remotes.List`)
	local remote = getRemote(name)
	if remote:IsA("RemoteFunction") then
		return remote
	end
	error(`Remote "{name}" exists but is not a RemoteFunction`)
end

return Remotes
