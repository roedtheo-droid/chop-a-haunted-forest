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
	-- Server -> client: show a short message (like "Clear every tree first (N left)").
	Notify = "Event",

	-- Client -> server: "I swung at this tree, and my crosshair hit its trunk at this point"
	-- (a Vector3). The server checks the point and decides the damage; the point only picks
	-- where the cut goes.
	SwingAtTree = "Event",

	-- Server -> all clients: a tree was hit, so draw the chop effects (only for looks).
	-- Carries the tree, where the cut opens on the bark, which way that side faces, the tool's Id,
	-- the Player who swung, and the way it falls if this hit felled it (nil otherwise).
	TreeHit = "Event",

	-- Client -> server: "I want to buy this item" (an item Id from Shared/Shop).
	-- The server checks the price, your coins and that you're at the Tool Shed.
	BuyItem = "Event",

	-- Client -> server: "I want to buy this truck" (a truck Id from Config.Trucks).
	-- The server checks the price, your Coins or Embers and that you're on the Garage pad.
	BuyTruck = "Event",

	-- Client -> server: "Park my truck by the Garage" (a truck Id you own, see TruckManager).
	SpawnTruck = "Event",

	-- Server -> all clients: someone sold logs on a DROP LOGS pad, so draw them dropping onto it
	-- and riding the conveyor into the chipper (only for looks). Carries the pad, how many logs
	-- to draw and where they drop from (a Vector3).
	LogsSold = "Event",

	-- Client -> server: "I'm holding sprint" (true) or "I let go" (false).
	-- The server decides the actual speed.
	SetSprint = "Event",

	-- Server -> client: the sleeping mimics your Lantern can see right now (a list of tree
	-- Models, empty when you put it away). Only the server knows which trees are mimics,
	-- so it only ever tells you about the ones close to your own lantern.
	LanternMimics = "Event",

	-- Server -> all clients: the Elder Hollow fell and the whole forest is clear.
	-- Carries the party's totals for this run (a RunSummary, see Shared/Types).
	ForestCleared = "Event",

	-- Client -> server: the Studio-only "Skip to boss" button was clicked.
	-- The server ignores it outside Studio (see Server/Systems/DebugManager).
	DebugSkipToBoss = "Event",
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
