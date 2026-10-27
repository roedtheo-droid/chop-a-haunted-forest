--!strict
-- One manager for EVERY tree (no scripts inside trees).
-- The client only says "I swung at tree X". This module checks that the swing is
-- allowed (real tree, close enough, not too fast) and then decides the damage.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local LogManager = require(script.Parent.LogManager)
local ToolManager = require(script.Parent.ToolManager)
local UpgradeManager = require(script.Parent.UpgradeManager)

local CHIP_COLOR = Color3.fromRGB(200, 160, 110)

local TreeManager = {}

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
	local width = cfg.TrunkWidth * scale
	-- Changing Size keeps the part's center, so the trunk shrinks evenly.
	trunk.Size = Vector3.new(trunk.Size.X, width, width)
end

-- Tip the tree over, away from the player, then drop logs and remove it.
local function fellTree(tree: Model, fromPosition: Vector3)
	-- Remove the tag first, so nobody can hit it while it falls.
	CollectionService:RemoveTag(tree, Tags.Tree)
	tree:SetAttribute("Felled", true)

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
		LogManager.spawnLogs(base, away, Config.Tree.LogsPerTree)
		task.delay(Config.Tree.RemoveDelay, function()
			tree:Destroy()
		end)
	end)
	tween:Play()
end

local function onSwing(player: Player, target: unknown)
	-- 1. Is the target a real, standing tree? (The client could send anything.)
	if typeof(target) ~= "Instance" then
		return
	end
	local instance = target :: Instance
	if not instance:IsA("Model") then
		return
	end
	local tree = instance :: Model
	if not CollectionService:HasTag(tree, Tags.Tree) or not tree:IsDescendantOf(workspace) then
		return
	end
	local trunk = getTrunk(tree)
	if not trunk then
		return
	end

	-- 2. Is the player alive and close enough? (Reach depends on the tool they hold.)
	local root = getRootPart(player)
	if not root then
		return
	end
	local stats = ToolManager.getStats(player)
	local base = tree:GetPivot().Position
	local flatDistance = Vector2.new(root.Position.X - base.X, root.Position.Z - base.Z).Magnitude
	if flatDistance > stats.Reach + Config.Tree.TrunkWidth / 2 then
		return
	end

	-- 3. Is the player swinging faster than their tool allows?
	local now = os.clock()
	local last = lastSwing[player]
	if last and now - last < stats.Cooldown * Config.Anticheat.CooldownTolerance then
		return
	end
	lastSwing[player] = now

	-- 4. All good: the SERVER decides the damage, from the held tool and upgrades.
	local damage = stats.Damage * UpgradeManager.damageMultiplier(player)
	local hp = math.max(getNumberAttribute(tree, "HP") - damage, 0)
	tree:SetAttribute("HP", hp)
	emitChips(trunk)
	updateTrunkWidth(tree, trunk)

	if hp <= 0 then
		fellTree(tree, root.Position)
	end
end

function TreeManager.init() end

function TreeManager.start()
	Remotes.getEvent("SwingAtTree").OnServerEvent:Connect(onSwing)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastSwing[player] = nil
	end)
end

return TreeManager
