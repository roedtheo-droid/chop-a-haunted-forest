--!strict
-- The Elder Hollow: the final boss, a giant mimic at the far end of the last zone.
--
-- It stands there from the start, asleep. It can't be hurt, and it counts as one of its
-- zone's trees. When every other tree in the zone is gone, it wakes up:
--   Slams    Every few seconds a red circle appears under one player. When the slam
--            lands, anyone still inside is knocked down (KnockdownManager).
--   Roots    Its trunk is too hard to chop. Its glowing roots are its weak points, and
--            its HP (the bar on everyone's screen) is all its roots' HP added up.
-- When the last root breaks, it topples over and its zone (the whole forest) is clear,
-- and RunManager shows everyone the FOREST CLEARED! screen.
--
-- Players hit it through the normal SwingAtTree remote: TreeManager checks reach and
-- cooldown like for any tree, then calls BossManager.hit.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Boss = require(ReplicatedStorage.Shared.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Zones = require(ReplicatedStorage.Shared.Zones)
local KnockdownManager = require(script.Parent.KnockdownManager)
local RunManager = require(script.Parent.RunManager)
local ZoneManager = require(script.Parent.ZoneManager)

local BARK_COLOR = Color3.fromRGB(45, 36, 34)
local CROWN_COLOR = Color3.fromRGB(50, 38, 58)
local ROOT_GLOW = Color3.fromRGB(255, 110, 40)
local BROKEN_ROOT_COLOR = Color3.fromRGB(70, 65, 60)
local EYE_COLOR = Color3.fromRGB(255, 50, 30)
local SLAM_COLOR = Color3.fromRGB(255, 40, 40)
local SLAM_HEIGHT = 10 -- a slam only hits players this close to the ground
local ROOT_TILT = math.rad(12) -- roots dip into the ground at their far end
local WAKE_SHAKE_TIME = 2
local SLAM_SHAKE_TIME = 0.3
local FALL_TIME = 3
local ROOT_SINK_TIME = 1

type Root = {
	Model: Model,
	Part: BasePart,
	FullThickness: number,
	Broken: boolean,
}
type State = "Asleep" | "Awake" | "Defeated"

local BossManager = {}

local notifyRemote: RemoteEvent
local stateFolder: Folder
local bossModel: Model
local roots: { Root } = {}
local rootByModel: { [Model]: Root } = {}
local state: State = "Asleep"
local lastHint: { [Player]: number } = {}

local function getNumber(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function groundHeightAt(x: number, z: number): number
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0))
	return if result then result.Position.Y else 0
end

local function makePart(name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Wood
	part.Anchored = true
	part.Parent = parent
	return part
end

-- A short message to one player, but not more often than every few seconds.
local function hint(player: Player, text: string)
	local now = os.clock()
	local last = lastHint[player]
	if last and now - last < Config.Boss.MessageCooldown then
		return
	end
	lastHint[player] = now
	notifyRemote:FireClient(player, text)
end

---------------------------------------------------------------------------
-- Building it
---------------------------------------------------------------------------

local function buildRoot(index: number, base: Vector3): Root
	local cfg = Config.Boss
	-- Spread the roots evenly around the trunk, pointing outwards.
	local angle = (index - 1) / cfg.RootCount * math.pi * 2 + math.pi / 4
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local middle = base + outward * (cfg.TrunkWidth / 2 + cfg.RootLength / 2 - 1)

	local model = Instance.new("Model")
	model.Name = `Root{index}`
	-- A cylinder's length runs along its X axis: turn it to point outwards, then tip
	-- its far end down into the ground.
	local cframe = CFrame.lookAt(middle, middle + outward)
		* CFrame.Angles(0, math.rad(90), 0)
		* CFrame.Angles(0, 0, -ROOT_TILT)
		+ Vector3.new(0, cfg.RootThickness * 0.3, 0)
	local part = makePart(
		"Root",
		Enum.PartType.Cylinder,
		Vector3.new(cfg.RootLength, cfg.RootThickness, cfg.RootThickness),
		cframe,
		BARK_COLOR,
		model
	)
	part.CanCollide = false -- so players don't trip over them mid-fight

	model.WorldPivot = CFrame.new(middle)
	model:SetAttribute("HP", cfg.RootHP)
	model:SetAttribute("MaxHP", cfg.RootHP)
	model:SetAttribute("ZoneId", Boss.ZoneId)
	-- TreeManager's reach check uses TrunkWidth: you can hit a root anywhere along it.
	model:SetAttribute("TrunkWidth", cfg.RootLength)
	model.Parent = bossModel
	CollectionService:AddTag(model, Tags.BossRoot)

	local root: Root = { Model = model, Part = part, FullThickness = cfg.RootThickness, Broken = false }
	rootByModel[model] = root
	return root
end

local function build()
	local cfg = Config.Boss
	local base = Vector3.new(cfg.Position.X, groundHeightAt(cfg.Position.X, cfg.Position.Z), cfg.Position.Z)

	bossModel = Instance.new("Model")
	bossModel.Name = "ElderHollow"
	makePart(
		"Trunk",
		Enum.PartType.Cylinder,
		Vector3.new(cfg.TrunkHeight, cfg.TrunkWidth, cfg.TrunkWidth),
		CFrame.new(base + Vector3.new(0, cfg.TrunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		BARK_COLOR,
		bossModel
	)
	local crown = makePart(
		"Crown",
		Enum.PartType.Ball,
		Vector3.one * cfg.CrownSize,
		CFrame.new(base + Vector3.new(0, cfg.TrunkHeight, 0)),
		CROWN_COLOR,
		bossModel
	)
	crown.Material = Enum.Material.Grass

	-- Its pivot is the bottom of the trunk, so it topples over from its base.
	bossModel.WorldPivot = CFrame.new(base)
	bossModel:SetAttribute("ZoneId", Boss.ZoneId)
	bossModel:SetAttribute("TrunkWidth", cfg.TrunkWidth)
	for index = 1, cfg.RootCount do
		table.insert(roots, buildRoot(index, base))
	end
	bossModel.Parent = workspace
	CollectionService:AddTag(bossModel, Tags.ElderHollow)
end

---------------------------------------------------------------------------
-- Awake
---------------------------------------------------------------------------

-- Rock the whole boss side to side for a moment.
local function shake(duration: number, angle: number)
	local start = bossModel:GetPivot()
	local elapsed = 0
	while elapsed < duration do
		elapsed += RunService.Heartbeat:Wait()
		if state == "Defeated" then
			return -- it's falling over: leave it alone
		end
		bossModel:PivotTo(start * CFrame.Angles(0, 0, math.sin(elapsed * 30) * angle))
	end
	bossModel:PivotTo(start)
end

local function updateHP()
	local hp = 0
	for _, root in roots do
		if not root.Broken then
			hp += getNumber(root.Model, "HP")
		end
	end
	stateFolder:SetAttribute("HP", hp)
end

local function addEyes()
	local cfg = Config.Boss
	local base = bossModel:GetPivot().Position
	for _, side in { -1, 1 } do
		-- On the side facing the zone's entrance (+Z), where players come from.
		local eye = makePart(
			"Eye",
			Enum.PartType.Ball,
			Vector3.one * 2,
			CFrame.new(base + Vector3.new(side * cfg.TrunkWidth * 0.2, cfg.TrunkHeight * 0.7, cfg.TrunkWidth / 2)),
			EYE_COLOR,
			bossModel
		)
		eye.Material = Enum.Material.Neon
		eye.CanCollide = false
	end
end

-- A red circle shows under a player first, then the slam lands there.
local function slam(at: Vector3)
	local cfg = Config.Boss
	local groundY = bossModel:GetPivot().Position.Y
	local center = Vector3.new(at.X, groundY, at.Z)

	local circle = Instance.new("Part")
	circle.Name = "SlamWarning"
	circle.Shape = Enum.PartType.Cylinder
	circle.Size = Vector3.new(0.2, cfg.SlamRadius * 2, cfg.SlamRadius * 2)
	circle.CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	circle.Color = SLAM_COLOR
	circle.Material = Enum.Material.Neon
	circle.Transparency = 0.75
	circle.Anchored = true
	circle.CanCollide = false
	circle.CanTouch = false
	circle.CanQuery = false -- clicks go through it, so you can still hit a root under it
	circle.Parent = workspace
	TweenService:Create(circle, TweenInfo.new(cfg.SlamWarning), { Transparency = 0.25 }):Play()

	task.wait(cfg.SlamWarning)
	if state ~= "Awake" then
		circle:Destroy()
		return
	end

	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		if
			root
			and flatDistance(root.Position, center) <= cfg.SlamRadius
			and math.abs(root.Position.Y - groundY) <= SLAM_HEIGHT
		then
			KnockdownManager.knockDown(player, "Slam")
		end
	end

	-- A white flash that spreads out and fades.
	circle.Color = Color3.new(1, 1, 1)
	circle.Transparency = 0
	local fade = TweenService:Create(circle, TweenInfo.new(0.4), {
		Transparency = 1,
		Size = circle.Size + Vector3.new(0, 6, 6),
	})
	fade.Completed:Connect(function()
		circle:Destroy()
	end)
	fade:Play()
	task.spawn(shake, SLAM_SHAKE_TIME, math.rad(2))
end

-- A random player in the boss's zone who is standing up.
local function pickTarget(): BasePart?
	local targets: { BasePart } = {}
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		if root and not KnockdownManager.isDown(player) and Zones.indexAt(root.Position) == Boss.ZoneId then
			table.insert(targets, root)
		end
	end
	if #targets == 0 then
		return nil
	end
	return targets[math.random(1, #targets)]
end

local function slamLoop()
	while state == "Awake" do
		task.wait(Config.Boss.SlamInterval)
		local target = pickTarget()
		if state == "Awake" and target then
			slam(target.Position)
		end
	end
end

local function wake()
	if state ~= "Asleep" then
		return
	end
	state = "Awake"
	stateFolder:SetAttribute("State", "Awake")
	notifyRemote:FireAllClients("The Elder Hollow awakens! Chop its glowing roots!")

	-- The roots light up so everyone can see where to hit.
	for _, root in roots do
		root.Part.Color = ROOT_GLOW
		root.Part.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = ROOT_GLOW
		light.Range = Config.Boss.RootLength
		light.Parent = root.Part
	end
	addEyes()
	shake(WAKE_SHAKE_TIME, math.rad(1.5))
	task.spawn(slamLoop)
end

---------------------------------------------------------------------------
-- Getting hit
---------------------------------------------------------------------------

local function emitSparks(part: BasePart)
	local emitter = part:FindFirstChild("Sparks") :: ParticleEmitter?
	if not emitter then
		local newEmitter = Instance.new("ParticleEmitter")
		newEmitter.Name = "Sparks"
		newEmitter.Enabled = false
		newEmitter.Color = ColorSequence.new(ROOT_GLOW)
		newEmitter.LightEmission = 1
		newEmitter.Size = NumberSequence.new(0.4)
		newEmitter.Lifetime = NumberRange.new(0.3, 0.6)
		newEmitter.Speed = NumberRange.new(10, 20)
		newEmitter.SpreadAngle = Vector2.new(70, 70)
		newEmitter.Acceleration = Vector3.new(0, -50, 0)
		newEmitter.Parent = part
		emitter = newEmitter
	end
	if emitter then
		emitter:Emit(Config.Tree.ChipsPerHit)
	end
end

local function breakRoot(root: Root, player: Player)
	root.Broken = true
	CollectionService:RemoveTag(root.Model, Tags.BossRoot)
	local part = root.Part
	part.Color = BROKEN_ROOT_COLOR
	part.Material = Enum.Material.Wood
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light:Destroy()
	end
	-- Sink into the ground, then disappear.
	local sink = TweenService:Create(part, TweenInfo.new(ROOT_SINK_TIME), {
		CFrame = part.CFrame - Vector3.new(0, Config.Boss.RootThickness * 2, 0),
	})
	sink.Completed:Connect(function()
		root.Model:Destroy()
	end)
	sink:Play()

	local left = 0
	for _, other in roots do
		if not other.Broken then
			left += 1
		end
	end
	if left > 0 then
		notifyRemote:FireAllClients(`{player.DisplayName} snapped a root! {left} to go.`)
	end
end

-- Topple over, away from whoever broke the last root.
local function defeat(player: Player)
	state = "Defeated"
	stateFolder:SetAttribute("State", "Defeated")
	CollectionService:RemoveTag(bossModel, Tags.ElderHollow)
	notifyRemote:FireAllClients(`{player.DisplayName} brought down the Elder Hollow!`)

	for _, descendant in bossModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false -- don't squash anyone
			if descendant.Name == "Eye" then
				descendant:Destroy()
			end
		end
	end

	local startPivot = bossModel:GetPivot()
	local base = startPivot.Position
	local root = getRoot(player)
	local from = if root then root.Position else base + Vector3.zAxis
	local away = Vector3.new(base.X - from.X, 0, base.Z - from.Z)
	away = if away.Magnitude > 0.01 then away.Unit else -Vector3.zAxis
	local endPivot = CFrame.new(base) * CFrame.fromAxisAngle(Vector3.yAxis:Cross(away), math.rad(90)) * startPivot.Rotation

	-- Same trick as TreeManager: tween a number and move the model ourselves.
	local alpha = Instance.new("NumberValue")
	alpha.Changed:Connect(function(value: number)
		bossModel:PivotTo(startPivot:Lerp(endPivot, value))
	end)
	local tween = TweenService:Create(
		alpha,
		TweenInfo.new(FALL_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = 1 }
	)
	tween.Completed:Connect(function()
		alpha:Destroy()
		-- It lies there for good, and the last zone (so the whole forest) is clear.
		ZoneManager.treeCleared(Boss.ZoneId)
		RunManager.forestCleared()
	end)
	tween:Play()
end

-- A player hit the boss's trunk or one of its roots (TreeManager already checked reach
-- and cooldown). `damage` comes from the server's own tool numbers, never the client.
function BossManager.hit(player: Player, target: Model, damage: number)
	if state == "Asleep" then
		local zoneState = ReplicatedStorage:FindFirstChild(Zones.StateFolderName)
		local zone = if zoneState then zoneState:FindFirstChild(tostring(Boss.ZoneId)) else nil
		local others = if zone then getNumber(zone, "Left") - 1 else 0 -- every tree left, except the boss
		local zoneName = Config.Zones[Boss.ZoneId].Name
		hint(player, `The Elder Hollow is asleep. Clear every other tree in {zoneName} first ({others} left).`)
		return
	end
	if state ~= "Awake" then
		return
	end

	local root = rootByModel[target]
	if not root then
		hint(player, "Its bark is too hard! Chop the glowing roots.")
		return
	end
	if root.Broken then
		return
	end
	if damage <= 0 then
		hint(player, "That won't hurt it. Chop the glowing roots!")
		return
	end

	local hp = math.max(getNumber(root.Model, "HP") - damage, 0)
	root.Model:SetAttribute("HP", hp)
	emitSparks(root.Part)
	-- Visible damage: the root gets thinner, like a tree trunk does.
	local minScale = Config.Tree.MinTrunkScale
	local thickness = root.FullThickness * (minScale + (1 - minScale) * hp / Config.Boss.RootHP)
	root.Part.Size = Vector3.new(root.Part.Size.X, thickness, thickness)

	if hp <= 0 then
		breakRoot(root, player)
	end
	updateHP()

	for _, other in roots do
		if not other.Broken then
			return
		end
	end
	defeat(player)
end

function BossManager.init()
	stateFolder = Instance.new("Folder")
	stateFolder.Name = Boss.StateFolderName
	local maxHP = Config.Boss.RootCount * Config.Boss.RootHP
	stateFolder:SetAttribute("State", "Asleep")
	stateFolder:SetAttribute("HP", maxHP)
	stateFolder:SetAttribute("MaxHP", maxHP)
	stateFolder.Parent = ReplicatedStorage

	build()
	ZoneManager.addTree(Boss.ZoneId) -- the boss is its zone's last tree
end

function BossManager.start()
	notifyRemote = Remotes.getEvent("Notify")

	-- Wake up when the boss is the only "tree" left in its zone.
	local zoneState = ReplicatedStorage:WaitForChild(Zones.StateFolderName):WaitForChild(tostring(Boss.ZoneId))
	local function check()
		if state == "Asleep" and getNumber(zoneState, "Left") <= 1 then
			task.spawn(wake)
		end
	end
	zoneState:GetAttributeChangedSignal("Left"):Connect(check)
	check()

	Players.PlayerRemoving:Connect(function(player: Player)
		lastHint[player] = nil
	end)
end

return BossManager
