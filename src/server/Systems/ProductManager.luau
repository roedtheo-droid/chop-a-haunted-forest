--!strict
-- The one place that hears about Robux purchases of developer products.
--
-- Roblox only lets a game have ONE ProcessReceipt function, so every system that sells
-- something for Robux (the Garage's trucks, the Chainsaw trial...) registers its product here
-- with a function that gives the player what they paid for. That function returns true once
-- it's really done (for something saved forever: once the save is written). Until then Roblox
-- keeps the purchase and asks again later, so a crash can't lose something someone paid for.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ProductManager = {}

local handlers: { [number]: (player: Player) -> boolean } = {}

-- Call `grant` when someone buys developer product `productId`. A product id of 0 means
-- "not on sale yet" and is skipped.
function ProductManager.register(productId: number, grant: (player: Player) -> boolean)
	if productId == 0 then
		return
	end
	if handlers[productId] then
		warn(`[ProductManager] Developer product {productId} is used twice in Config`)
	end
	handlers[productId] = grant
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local grant = handlers[receipt.ProductId]
	if not player or not grant then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, done = pcall(grant, player)
	if not ok then
		warn(`[ProductManager] Giving product {receipt.ProductId} failed: {done}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return if done then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

function ProductManager.init() end

function ProductManager.start()
	MarketplaceService.ProcessReceipt = processReceipt
end

return ProductManager
