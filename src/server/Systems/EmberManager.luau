--!strict
-- Keeps track of each player's Embers, the permanent currency you get from burning mimics.
-- Embers are stored in an "Embers" attribute on the Player. Only the server changes it;
-- the client just reads it to show the HUD.
-- Not saved yet: Phase 8 adds DataStore saving and loads the amount when you join.

local Players = game:GetService("Players")

local EmberManager = {}

function EmberManager.get(player: Player): number
	local value = player:GetAttribute("Embers")
	return if typeof(value) == "number" then value else 0
end

function EmberManager.add(player: Player, amount: number)
	player:SetAttribute("Embers", EmberManager.get(player) + amount)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Embers", 0)
end

function EmberManager.init() end

function EmberManager.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this ran (can happen in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return EmberManager
