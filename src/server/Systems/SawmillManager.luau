--!strict
-- Builds a placeholder sawmill in every zone, each with a glowing "DROP LOGS" pad.
-- When a player steps on a pad, the SERVER takes all their logs and pays them coins.
-- The client never says how many logs it has or what they're worth, so it can't fake the amount.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CoinManager = require(script.Parent.CoinManager)
local LogManager = require(script.Parent.LogManager)
local QuestManager = require(script.Parent.QuestManager)
local RunManager = require(script.Parent.RunManager)

local BUILDING_COLOR = Color3.fromRGB(120, 85, 60)
local ROOF_COLOR = Color3.fromRGB(70, 50, 40)
local PAD_COLOR = Color3.fromRGB(255, 200, 60)
local PAD_THICKNESS = 0.4

local SawmillManager = {}

local notifyRemote: RemoteEvent
local pads: { BasePart } = {}
-- When each player last sold, so standing on the pad doesn't sell over and over.
local lastSell: { [Player]: number } = {}

local function groundHeightAt(x: number, z: number): number
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0))
	return if result then result.Position.Y else 0
end

local function makeLabel(parent: Instance, text: string)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = parent
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
	notifyRemote:FireClient(player, `Sold {logs} log(s) for {coins} coins!`)
	QuestManager.report(player, "SellLogs")
end

local function build(center: Vector3): BasePart
	local cfg = Config.Sawmill
	local groundY = groundHeightAt(center.X, center.Z)
	local size = cfg.BuildingSize

	local model = Instance.new("Model")
	model.Name = "Sawmill"

	local building = Instance.new("Part")
	building.Name = "Building"
	building.Size = size
	building.Position = Vector3.new(center.X, groundY + size.Y / 2, center.Z)
	building.Color = BUILDING_COLOR
	building.Material = Enum.Material.WoodPlanks
	building.Anchored = true
	building.Parent = model

	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(size.X + 2, 1, size.Z + 2)
	roof.Position = building.Position + Vector3.new(0, size.Y / 2 + 0.5, 0)
	roof.Color = ROOF_COLOR
	roof.Anchored = true
	roof.Parent = model

	-- A sign floating above the roof.
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromOffset(220, 50)
	sign.StudsOffset = Vector3.new(0, size.Y / 2 + 4, 0)
	sign.AlwaysOnTop = false
	sign.MaxDistance = 150
	sign.Parent = building
	makeLabel(sign, "SAWMILL")

	-- The pad sits in front of the building, on the side facing spawn and the zone's gate (+Z).
	local dropPad = Instance.new("Part")
	dropPad.Name = "DropPad"
	dropPad.Size = Vector3.new(cfg.PadSize, PAD_THICKNESS, cfg.PadSize)
	dropPad.Position = Vector3.new(center.X, groundY + PAD_THICKNESS / 2, center.Z + size.Z / 2 + cfg.PadSize / 2)
	dropPad.Color = PAD_COLOR
	dropPad.Material = Enum.Material.Neon
	dropPad.Anchored = true
	dropPad.Parent = model

	local padText = Instance.new("SurfaceGui")
	padText.Name = "Text"
	padText.Face = Enum.NormalId.Top
	padText.Parent = dropPad
	makeLabel(padText, "DROP LOGS")

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
