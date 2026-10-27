--!strict
-- One manager for EVERY tree (no scripts inside trees).
-- The client only says "I swung at tree X". This module checks that the swing is
-- allowed (real tree, close enough, not too fast) and then decides the damage.
-- Mimics are trees too: hitting a sleeping one wakes it (MimicManager), and an awake
-- one can still be chopped down.
-- The Torch doesn't chop: it burns a sleeping mimic safely and does nothing to anything
-- else. The Lantern doesn't hit trees at all.
-- Hits on the Elder Hollow (the final boss) and its roots go to BossManager.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local BossManager = require(script.Parent.BossManager)
local EmberManager = require(script.Parent.EmberManager)
local KnockdownManager = require(script.Parent.KnockdownManager)
local LogManager = require(script.Parent.LogManager)
local MimicManager = require(script.Parent.MimicManager)
local QuestManager = require(script.Parent.QuestManager)
local RunManager = require(script.Parent.RunManager)
local ToolManager = require(script.Parent.ToolManager)
local UpgradeManager = require(script.Parent.UpgradeManager)
local ZoneManager = require(script.Parent.ZoneManager)

local CHIP_COLOR = Color3.fromRGB(200, 160, 110)
local CHAR_COLOR = Color3.fromRGB(30, 25, 22) -- a burned mimic turns this colour
local CRUMBLE_TIME = 0.8 -- seconds a burned mimic takes to fade away

local TreeManager = {}

local stumpsFolder: Folder
local notifyRemote: RemoteEvent

-- When each player last swung, to stop them swinging faster than the cooldown.
local lastSwing: { [Player]: number } = {}

local function getNumberAttribute(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function getTrunk(tree: Model): BasePart?
	local trunk = tree:FindFirstChild("Trunk")
	return if trunk and trunk:IsA("BasePart") then trunk else nil
end

local function getRootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Wood chips burst out of the trunk on every hit.
local function emitChips(trunk: BasePart)
	local emitter = trunk:FindFirstChild("Chips") :: ParticleEmitter?
	if not emitter then
		local newEmitter = Instance.new("ParticleEmitter")
		newEmitter.Name = "Chips"
		newEmitter.Enabled = false
		newEmitter.Color = ColorSequence.new(CHIP_COLOR)
		newEmitter.Size = NumberSequence.new(0.35)
		newEmitter.Lifetime = NumberRange.new(0.4, 0.7)
		newEmitter.Speed = NumberRange.new(10, 18)
		newEmitter.SpreadAngle = Vector2.new(70, 70)
		newEmitter.Acceleration = Vector3.new(0, -50, 0)
		newEmitter.Parent = trunk
		emitter = newEmitter
	end
	if emitter then
		emitter:Emit(Config.Tree.ChipsPerHit)
	end
end

-- Visible damage: the trunk gets thinner as HP goes down.
local function updateTrunkWidth(tree: Model, trunk: BasePart)
	local cfg = Config.Tree
	local hpFraction = getNumberAttribute(tree, "HP") / math.max(getNumberAttribute(tree, "MaxHP"), 1)
	local scale = cfg.MinTrunkScale + (1 - cfg.MinTrunkScale) * hpFraction
	local width = getNumberAttribute(tree, "TrunkWidth") * scale
	-- Changing Size keeps the part's center, so the trunk shrinks evenly.
	trunk.Size = Vector3.new(trunk.Size.X, width, width)
end

-- A short stump stays where the tree stood, so cleared areas are easy to spot.
-- A burned mimic leaves a charred black stump.
local function leaveStump(tree: Model, trunk: BasePart, charred: boolean)
	local width = getNumberAttribute(tree, "TrunkWidth")
	local height = Config.Tree.StumpHeight
	local stump = Instance.new("Part")
	stump.Name = "Stump"
	stump.Shape = Enum.PartType.Cylinder
	stump.Size = Vector3.new(height, width, width)
	stump.CFrame = CFrame.new(tree:GetPivot().Position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	-- Normal stumps are a bit darker than the bark.
	stump.Color = if charred then CHAR_COLOR else trunk.Color:Lerp(Color3.new(0, 0, 0), 0.25)
	stump.Material = Enum.Material.Wood
	stump.Anchored = true
	stump.CanCollide = false -- so nobody gets stuck on stumps
	stump.Parent = stumpsFolder
end

-- Tip the tree over, away from the player, then drop logs and remove it.
-- Mimics don't leave a stump: they pulled their roots out when they woke up.
local function fellTree(tree: Model, trunk: BasePart, fromPosition: Vector3, withStump: boolean)
	-- Remove the tag first, so nobody can hit it while it falls.
	CollectionService:RemoveTag(tree, Tags.Tree)
	tree:SetAttribute("Felled", true)
	if withStump then
		leaveStump(tree, trunk, false)
	end
	ZoneManager.treeCleared(getNumberAttribute(tree, "ZoneId"))

	for _, part in tree:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false -- don't fling players standing nearby
		end
	end

	local startPivot = tree:GetPivot()
	local base = startPivot.Position

	-- Direction from the player to the tree, flat on the ground.
	local away = Vector3.new(base.X - fromPosition.X, 0, base.Z - fromPosition.Z)
	if away.Magnitude < 0.01 then
		away = Vector3.xAxis
	end
	away = away.Unit

	-- Rotating "up" around this axis by 90 degrees points the tree along `away`.
	local axis = Vector3.yAxis:Cross(away)
	local rotation = CFrame.fromAxisAngle(axis, math.rad(90))
	local endPivot = CFrame.new(base) * rotation * startPivot.Rotation

	-- TweenService can't move a whole Model, so we tween a number from 0 to 1
	-- and move the model ourselves each time the number changes.
	local alpha = Instance.new("NumberValue")
	alpha.Value = 0
	alpha.Changed:Connect(function(value: number)
		tree:PivotTo(startPivot:Lerp(endPivot, value))
	end)

	local tween = TweenService:Create(
		alpha,
		TweenInfo.new(Config.Tree.FallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = 1 }
	)
	tween.Completed:Connect(function()
		alpha:Destroy()
		LogManager.spawnLogs(
			base,
			away,
			Config.Tree.LogsPerTree,
			getNumberAttribute(tree, "LogValue"),
			tree:GetAttribute("Cursed") == true
		)
		task.delay(Config.Tree.RemoveDelay, function()
			tree:Destroy()
		end)
	end)
	tween:Play()
end

-- A sleeping mimic was hit with the Torch: it catches fire, chars black and crumbles away.
-- It counts as cleared, and the player who burned it gets Embers.
local function burnMimic(player: Player, tree: Model, trunk: BasePart)
	-- Remove the tag first, so nobody can hit it (or see it with a Lantern) while it burns.
	CollectionService:RemoveTag(tree, Tags.Tree)
	tree:SetAttribute("Felled", true)
	MimicManager.forget(tree)
	leaveStump(tree, trunk, true)
	ZoneManager.treeCleared(getNumberAttribute(tree, "ZoneId"))

	local embers = Config.Embers.PerMimic
	EmberManager.add(player, embers)
	RunManager.record(player, "MimicsBurned", 1)
	notifyRemote:FireAllClients(`{player.DisplayName} burned a mimic and got {embers} Embers!`)

	local fire = Instance.new("Fire")
	fire.Size = math.clamp(getNumberAttribute(tree, "TrunkWidth") * 3, 2, 30) -- Fire can't be bigger than 30
	fire.Heat = 15
	fire.Parent = trunk

	local parts: { BasePart } = {}
	for _, descendant in tree:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			table.insert(parts, descendant)
		end
	end

	-- Turn black while it burns...
	local burnTime = Config.Torch.BurnTime
	for _, part in parts do
		TweenService:Create(part, TweenInfo.new(burnTime), { Color = CHAR_COLOR }):Play()
	end
	-- ...then fade away.
	task.delay(burnTime, function()
		fire.Enabled = false
		for _, part in parts do
			TweenService:Create(part, TweenInfo.new(CRUMBLE_TIME), { Transparency = 1 }):Play()
		end
		task.delay(CRUMBLE_TIME, function()
			tree:Destroy()
		end)
	end)
end

local function onSwing(player: Player, target: unknown)
	-- 1. Is the target a real, standing tree, an awake mimic, or the boss (its trunk or a root)?
	-- (The client could send anything.)
	if typeof(target) ~= "Instance" then
		return
	end
	local instance = target :: Instance
	if not instance:IsA("Model") then
		return
	end
	local tree = instance :: Model
	local isBoss = CollectionService:HasTag(tree, Tags.ElderHollow) or CollectionService:HasTag(tree, Tags.BossRoot)
	local choppable = isBoss
		or CollectionService:HasTag(tree, Tags.Tree)
		or CollectionService:HasTag(tree, Tags.AwakeMimic)
	if not choppable or not tree:IsDescendantOf(workspace) then
		return
	end
	-- Trees behind a closed gate can't be chopped (stops players who teleport past it).
	if not ZoneManager.isOpen(getNumberAttribute(tree, "ZoneId")) then
		return
	end

	-- 2. Is the player alive, standing up and close enough? (Reach depends on the tool they hold.)
	local root = getRootPart(player)
	if not root or KnockdownManager.isDown(player) then
		return
	end
	local toolId = ToolManager.getEquippedId(player)
	if toolId == "Lantern" then
		return -- the Lantern is for looking, not hitting
	end
	local stats = Config.Tools[toolId]
	local base = tree:GetPivot().Position
	local flatDistance = Vector2.new(root.Position.X - base.X, root.Position.Z - base.Z).Magnitude
	if flatDistance > stats.Reach + getNumberAttribute(tree, "TrunkWidth") / 2 then
		return
	end

	-- 3. Is the player swinging faster than their tool allows?
	local now = os.clock()
	local last = lastSwing[player]
	if last and now - last < stats.Cooldown * Config.Anticheat.CooldownTolerance then
		return
	end
	lastSwing[player] = now

	-- The SERVER decides the damage, from the held tool and upgrades.
	local damage = stats.Damage * UpgradeManager.damageMultiplier(player)

	-- 4. The Elder Hollow and its roots: BossManager decides what a hit does.
	if isBoss then
		BossManager.hit(player, tree, damage)
		return
	end

	local trunk = getTrunk(tree)
	if not trunk then
		return
	end

	-- 5. The Torch burns sleeping mimics. It does nothing to normal trees, and awake
	-- mimics are moving too fast to catch fire.
	if toolId == "Torch" then
		if MimicManager.isSleeping(tree) then
			burnMimic(player, tree, trunk)
		elseif CollectionService:HasTag(tree, Tags.AwakeMimic) then
			notifyRemote:FireClient(player, "Awake mimics won't burn! Only sleeping ones do.")
		end
		return
	end

	-- 6. All good: chop it.
	local hp = math.max(getNumberAttribute(tree, "HP") - damage, 0)
	tree:SetAttribute("HP", hp)
	emitChips(trunk)
	updateTrunkWidth(tree, trunk)

	if hp <= 0 then
		local wasMimic = MimicManager.isMimic(tree)
		MimicManager.forget(tree)
		fellTree(tree, trunk, root.Position, not wasMimic)
		QuestManager.report(player, "FellTree")
		RunManager.record(player, "TreesFelled", 1) -- counts for whoever landed the last hit
		if wasMimic then
			RunManager.record(player, "MimicsChopped", 1)
			notifyRemote:FireAllClients(`{player.DisplayName} chopped down a mimic!`)
		end
	elseif MimicManager.isMimic(tree) then
		MimicManager.wake(tree, player) -- does nothing if it's already awake
	end
end

function TreeManager.init()
	stumpsFolder = Instance.new("Folder")
	stumpsFolder.Name = "Stumps"
	stumpsFolder.Parent = workspace
end

function TreeManager.start()
	notifyRemote = Remotes.getEvent("Notify")
	Remotes.getEvent("SwingAtTree").OnServerEvent:Connect(onSwing)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastSwing[player] = nil
	end)
end

return TreeManager
