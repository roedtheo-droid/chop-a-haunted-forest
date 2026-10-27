--!strict
-- Keeps track of each player's Embers, the permanent currency you get from burning mimics.
-- Embers live in the player's save (SaveManager), so they're kept between visits.
-- The "Embers" attribute on the Player is a copy for the HUD to show; only the server sets it.

local SaveManager = require(script.Parent.SaveManager)

local EmberManager = {}

function EmberManager.get(player: Player): number
	local data = SaveManager.getData(player)
	return if data then data.Embers else 0
end

function EmberManager.add(player: Player, amount: number)
	local data = SaveManager.getData(player)
	if not data then
		return -- the player already left
	end
	data.Embers += amount
	player:SetAttribute("Embers", data.Embers)
end

function EmberManager.init() end

function EmberManager.start() end

return EmberManager
