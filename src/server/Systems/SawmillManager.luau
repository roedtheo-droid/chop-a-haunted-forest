--!strict
-- Builds a placeholder sawmill (a log cabin with a saw blade) in every zone, each with a
-- striped "DROP LOGS" pad and a big "SELL LOGS" sign.
-- When a player steps on a pad, the SERVER takes all their logs and pays them coins.
-- The client never says how many logs it has or what they're worth, so it can't fake the amount.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CoinManager = require(script.Parent.CoinManager)
local EffectsManager = require(script.Parent.EffectsManager)
local LogManager = require(script.Parent.LogManager)
local QuestManager = require(script.Parent.QuestManager)
local RunManager = require(script.Parent.RunManager)
local Blocky = require(script.Parent.Parent.Build.Blocky)

local PAD_COLOR = Color3.fromRGB(196, 138, 85) -- light wooden planks
local PAD_THICKNESS = 0.4
local STRIPE_WIDTH = 0.8 -- the yellow and black edge around the pad
local SAW_SIZE = 5

local SawmillManager = {}

local notifyRemote: RemoteEvent
local pads: { BasePart } = {}
-- When each player last sold, so standing on the pad doesn't sell over and over.
local lastSell: { [Player]: number } = {}

local function groundHeightAt(x: number, z: number): number
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0))
	return if result then result.Position.Y else 0
end

local function onPadTouched(hit: BasePart)
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
	end
	notifyRemote:FireClient(player, `Sold {logs} log(s) for {coins} coins!`)
	QuestManager.report(player, "SellLogs")
end

local function build(center: Vector3): BasePart
	local cfg = Config.Sawmill
	local groundY = groundHeightAt(center.X, center.Z)
	local ground = Vector3.new(center.X, groundY, center.Z)
	local size = cfg.BuildingSize

	local model = Instance.new("Model")
	model.Name = "Sawmill"

	local building = Blocky.cabin("Building", ground, size, 1, model)

	-- A big saw blade on the side wall, so you can tell it's a sawmill.
	local saw = Blocky.part(
		"Saw",
		Vector3.new(0.4, SAW_SIZE, SAW_SIZE),
		CFrame.new(building.Position + Vector3.new(size.X / 2 + 0.2, 0, 0)),
		Config.Style.Metal,
		Enum.Material.Metal,
		model
	)
	saw.Shape = Enum.PartType.Cylinder -- a cylinder's flat sides face along X

	-- A "SELL LOGS" sign on the front wall, above the door.
	Blocky.sign(
		"SELL LOGS",
		CFrame.new(ground + Vector3.new(0, size.Y * 0.84, size.Z / 2 + 0.3)),
		size.X * 0.75,
		size.Y * 0.24,
		nil,
		model
	)

	-- The pad sits in front of the building, on the side facing spawn and the zone's gate (+Z).
	local dropPad = Instance.new("Part")
	dropPad.Name = "DropPad"
	dropPad.Size = Vector3.new(cfg.PadSize, PAD_THICKNESS, cfg.PadSize)
	dropPad.Position = Vector3.new(center.X, groundY + PAD_THICKNESS / 2, center.Z + size.Z / 2 + cfg.PadSize / 2 + STRIPE_WIDTH)
	dropPad.Color = PAD_COLOR
	dropPad.Material = Enum.Material.WoodPlanks
	dropPad.Anchored = true
	dropPad.Parent = model
	Blocky.hazardEdge(dropPad, STRIPE_WIDTH, model)

	local padText = Blocky.face(dropPad, Enum.NormalId.Top)
	padText.Name = "Text"
	local label = Blocky.label(padText, "DROP LOGS", Config.Style.TitleFont)
	label.Rotation = 90 -- so it reads the right way up when you walk onto the pad from the front

	model.Parent = workspace
	return dropPad
end

function SawmillManager.init()
	for _, zone in Config.Zones do
		table.insert(pads, build(zone.Sawmill))
	end
end

function SawmillManager.start()
	notifyRemote = Remotes.getEvent("Notify")
	for _, pad in pads do
		pad.Touched:Connect(onPadTouched)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		lastSell[player] = nil
	end)
end

return SawmillManager
