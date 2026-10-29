--!strict
-- Builds a sawmill in every zone (the building is in Build/SawmillBuilding), each with a sell
-- yard in front (Build/SellYard): the striped "DROP LOGS" pad, signs, and a conveyor into a
-- wood chipper.
-- When a player steps on a pad, the SERVER takes all their logs and pays them coins.
-- The client never says how many logs it has or what they're worth, so it can't fake the amount.
-- Every player's computer then shows the logs dropping onto the pad and riding the conveyor
-- into the chipper (the LogsSold remote, see Client/Controllers/SellYardController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Zones = require(ReplicatedStorage.Shared.Zones)
local CoinManager = require(script.Parent.CoinManager)
local EffectsManager = require(script.Parent.EffectsManager)
local LogManager = require(script.Parent.LogManager)
local QuestManager = require(script.Parent.QuestManager)
local RunManager = require(script.Parent.RunManager)
local SawmillBuilding = require(script.Parent.Parent.Build.SawmillBuilding)
local SellYard = require(script.Parent.Parent.Build.SellYard)

local SawmillManager = {}

local notifyRemote: RemoteEvent
local soldRemote: RemoteEvent
local pads: { BasePart } = {}
-- When each player last sold, so standing on the pad doesn't sell over and over.
local lastSell: { [Player]: number } = {}

local function groundHeightAt(x: number, z: number): number
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0))
	return if result then result.Position.Y else 0
end

-- Show `count` logs dropping onto `pad` at `from` and riding into the chipper, on every
-- player's screen. Only for looks: the coins are already paid. TruckManager uses it too.
function SawmillManager.showSell(pad: BasePart, count: number, from: Vector3)
	soldRemote:FireAllClients(pad, math.min(count, Config.Sawmill.MaxShownLogs), from)
end

local function onPadTouched(pad: BasePart, hit: BasePart)
	-- Which player touched the pad? (hit could be a leg, an arm or a hat.)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	local last = lastSell[player]
	if last and now - last < Config.Sawmill.SellCooldown then
		return
	end

	local logs, coins = LogManager.takeAll(player)
	if logs <= 0 then
		return
	end
	lastSell[player] = now

	CoinManager.add(player, coins)
	RunManager.record(player, "CoinsEarned", coins)
	-- Coins burst out around the player standing on the pad (the cha-ching is played on
	-- their own computer by SoundController, since only they need to hear it).
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		EffectsManager.burst("Coins", root.Position)
		SawmillManager.showSell(pad, logs, root.Position)
	end
	notifyRemote:FireClient(player, string.format(Config.Sawmill.Text.Sold, logs, Format.number(coins)))
	QuestManager.report(player, "SellLogs")
end

local function build(center: Vector3, index: number): BasePart
	local cfg = Config.Sawmill
	local zone = Config.Zones[index]
	local groundY = groundHeightAt(center.X, center.Z)
	local ground = Vector3.new(center.X, groundY, center.Z)

	local model = Instance.new("Model")
	model.Name = "Sawmill"
	-- The sawmill in the camp stands by the river, so its water wheel's stream runs into it.
	local riverZ = if Zones.isInCamp(ground) then Zones.getRiverZ() else nil
	local wear = cfg.Wear[index] or 0
	SawmillBuilding.build(ground, wear, riverZ, model)

	-- The sell yard sits in front of the building, on the side facing spawn and the zone's gate (+Z).
	-- Its billboard shows what one log from this zone's trees is worth.
	local treeType = Config.TreeTypes[zone.TreeType]
	local perLog = if treeType then treeType.LogValue else 0
	local pad = SellYard.build(ground, wear, perLog, model)

	model.Parent = workspace
	return pad
end

-- Every DROP LOGS pad (TruckManager sells a truck's bed when it drives onto one).
function SawmillManager.getPads(): { BasePart }
	return pads
end

function SawmillManager.init()
	for index, zone in Config.Zones do
		table.insert(pads, build(zone.Sawmill, index))
	end
end

function SawmillManager.start()
	notifyRemote = Remotes.getEvent("Notify")
	soldRemote = Remotes.getEvent("LogsSold")
	for _, pad in pads do
		pad.Touched:Connect(function(hit: BasePart)
			onPadTouched(pad, hit)
		end)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		lastSell[player] = nil
	end)
end

return SawmillManager
