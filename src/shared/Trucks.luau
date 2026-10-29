--!strict
-- The log trucks sold in the Garage (the list and their numbers are in Config.Trucks).
-- Used by the server (to check purchases) and the client (to draw the Garage screen).

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Trucks = {}

Trucks.List = Config.Trucks

local byId: { [string]: Types.TruckConfig } = {}
local byProduct: { [number]: Types.TruckConfig } = {}
for _, truck in Config.Trucks do
	byId[truck.Id] = truck
	if truck.ProductId ~= 0 then
		byProduct[truck.ProductId] = truck
	end
end

function Trucks.get(id: string): Types.TruckConfig?
	return byId[id]
end

-- The Robux truck that a developer product sells (nil if none does).
function Trucks.getByProduct(productId: number): Types.TruckConfig?
	return byProduct[productId]
end

-- Its tier: 1 for the first truck in the list, and so on.
function Trucks.tierOf(id: string): number
	for index, truck in Config.Trucks do
		if truck.Id == id then
			return index
		end
	end
	return 0
end

-- Ember and Robux trucks are saved forever; Coin trucks only last for this run.
function Trucks.isPermanent(truck: Types.TruckConfig): boolean
	return truck.Currency ~= "Coins"
end

-- The name of a permanent truck in the player's save (SaveData.Unlocks).
function Trucks.unlockName(id: string): string
	return `Truck_{id}`
end

-- Player attribute names. Only the server sets them; the client only reads them.
-- A permanent truck shows up as "Unlock_Truck_<id>" (SaveManager sets one per unlock), a
-- truck bought with Coins as "RunTruck_<id>" (gone next run).
function Trucks.runAttribute(id: string): string
	return `RunTruck_{id}`
end

function Trucks.owns(player: Player, id: string): boolean
	return player:GetAttribute(Trucks.runAttribute(id)) == true
		or player:GetAttribute(`Unlock_{Trucks.unlockName(id)}`) == true
end

-- The biggest Speed and Carry in the list (the Garage's bars are full at these).
function Trucks.maxStats(): (number, number)
	local speed, carry = 0, 0
	for _, truck in Config.Trucks do
		speed = math.max(speed, truck.Speed)
		carry = math.max(carry, truck.Carry)
	end
	return speed, carry
end

return table.freeze(Trucks)
