--!strict
-- Builds the Garage (see Build/GarageBuilding) and handles every truck purchase.
--
-- The client only says "I want to buy truck X". The server checks that the truck exists,
-- the player is standing on the Garage pad, isn't clicking too fast and doesn't own it yet,
-- and then takes the price:
--   Coins   CoinManager.spend. The truck is yours until the end of this run (Coins reset too).
--   Embers  EmberManager.spend. The truck is saved forever (SaveManager unlock).
--   Robux   Roblox shows its purchase window for the truck's developer product. When Roblox
--           says the player paid (ProcessReceipt), the truck is saved forever and the save is
--           written right away. While the product id is 0, the truck isn't for sale.
-- Who owns what is shown to the client with player attributes (see Shared/Trucks).

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Trucks = require(ReplicatedStorage.Shared.Trucks)
local Types = require(ReplicatedStorage.Shared.Types)
local CoinManager = require(script.Parent.CoinManager)
local EmberManager = require(script.Parent.EmberManager)
local SaveManager = require(script.Parent.SaveManager)
local GarageBuilding = require(script.Parent.Parent.Build.GarageBuilding)

local GarageManager = {}

local notifyRemote: RemoteEvent
local pad: BasePart
local garageBase: CFrame -- the middle of the Garage's floor, its doors facing -Z
local lastBuy: { [Player]: number } = {}

local function groundHeightAt(x: number, z: number): number
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0))
	return if result then result.Position.Y else 0
end

local function notify(player: Player, text: string, value: string)
	notifyRemote:FireClient(player, string.format(text, value))
end

-- Is the player standing on the pad (or very close to it)? TruckManager asks this too.
function GarageManager.isOnPad(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local offset = pad.CFrame:PointToObjectSpace(root.Position)
	local margin = Config.Garage.BuyMargin
	return math.abs(offset.X) <= pad.Size.X / 2 + margin
		and math.abs(offset.Z) <= pad.Size.Z / 2 + margin
		and math.abs(offset.Y) <= 10
end

-- Give a truck the player just paid for.
local function give(player: Player, truck: Types.TruckConfig)
	local text = Config.Garage.Text
	if Trucks.isPermanent(truck) then
		SaveManager.addUnlock(player, Trucks.unlockName(truck.Id))
		notify(player, text.Bought, truck.Name)
	else
		player:SetAttribute(Trucks.runAttribute(truck.Id), true)
		notify(player, text.BoughtForRun, truck.Name)
	end
end

local function onBuy(player: Player, truckId: unknown)
	local text = Config.Garage.Text
	-- 1. Is it a real truck? (The client could send anything.)
	if typeof(truckId) ~= "string" then
		return
	end
	local truck = Trucks.get(truckId :: string)
	if not truck then
		return
	end

	-- 2. Not too fast, and standing on the pad?
	local now = os.clock()
	local last = lastBuy[player]
	if last and now - last < Config.Garage.BuyCooldown then
		return
	end
	lastBuy[player] = now
	if not GarageManager.isOnPad(player) then
		notifyRemote:FireClient(player, text.NotOnPad)
		return
	end

	-- 3. Not owned yet?
	if Trucks.owns(player, truck.Id) then
		notify(player, text.AlreadyOwned, truck.Name)
		return
	end

	-- 4. Pay (spend() checks the balance and takes it in one step), then give it.
	if truck.Currency == "Coins" then
		if not CoinManager.spend(player, truck.Price) then
			notify(player, text.NeedCoins, Format.number(truck.Price - CoinManager.get(player)))
			return
		end
		give(player, truck)
	elseif truck.Currency == "Embers" then
		if not EmberManager.spend(player, truck.Price) then
			notify(player, text.NeedEmbers, Format.number(truck.Price - EmberManager.get(player)))
			return
		end
		give(player, truck)
	else
		if truck.ProductId == 0 then
			notify(player, text.NotOnSale, truck.Name)
			return
		end
		-- Roblox shows its own purchase window. ProcessReceipt gives the truck once they've paid.
		MarketplaceService:PromptProductPurchase(player, truck.ProductId)
	end
end

-- Roblox calls this when a player has paid for a developer product (and again later if we
-- don't answer "granted", for example because saving failed). Giving a truck twice does no
-- harm (an unlock is only stored once), so a repeated receipt is safe.
local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local truck = Trucks.getByProduct(receipt.ProductId)
	if not player or not truck then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not Trucks.owns(player, truck.Id) then
		give(player, truck)
	end
	-- Only say "done" once it's really saved, so a crash can't lose a paid truck.
	if not SaveManager.saveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Where spawned trucks park, next to the driveway (see Config.Truck), facing the camp.
function GarageManager.parkingSpots(): { CFrame }
	local front = -Config.Garage.BuildingSize.Z / 2
	local spots = {}
	for _, side in Config.Truck.SpawnSides do
		table.insert(spots, garageBase * CFrame.new(side, 0, front - Config.Truck.SpawnOut))
	end
	return spots
end

function GarageManager.init()
	local cfg = Config.Garage
	local folder = Instance.new("Folder")
	folder.Name = "Garage"
	local spot = cfg.Position
	local ground = Vector3.new(spot.X, groundHeightAt(spot.X, spot.Z), spot.Z)
	local base = CFrame.lookAt(ground, Vector3.new(cfg.FaceToward.X, ground.Y, cfg.FaceToward.Z))
	garageBase = base
	pad = GarageBuilding.build(folder, base)
	CollectionService:AddTag(pad, Tags.GaragePad)
	folder.Parent = workspace
end

function GarageManager.start()
	notifyRemote = Remotes.getEvent("Notify")
	Remotes.getEvent("BuyTruck").OnServerEvent:Connect(onBuy)
	MarketplaceService.ProcessReceipt = processReceipt

	Players.PlayerRemoving:Connect(function(player: Player)
		lastBuy[player] = nil
	end)
end

return GarageManager
