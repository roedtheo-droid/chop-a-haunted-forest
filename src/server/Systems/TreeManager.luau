--!strict
-- One manager for EVERY tree (no scripts inside trees).
-- The client only says "I swung at tree X". This module checks that the swing is
-- allowed (real tree, close enough, not too fast) and then decides the damage.
-- Mimics are trees too: hitting a sleeping one wakes it (MimicManager), and an awake
-- one can still be chopped down.
-- The Torch doesn't chop: it burns a sleeping mimic safely and does nothing to anything
-- else. The Lantern doesn't hit trees at all.
-- Hits on the Elder Hollow (the final boss) and its roots go to BossManager.
-- The chips, sound and shakes of a hit are drawn by every player's own computer: this
-- only tells them a hit counted (the TreeHit remote, see Client/Controllers/ChopEffectsController).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ChopRules = require(ReplicatedStorage.Shared.ChopRules)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local BossManager = require(script.Parent.BossManager)
local EffectsManager = require(script.Parent.EffectsManager)
local EmberManager = require(script.Parent.EmberManager)
local KnockdownManager = require(script.Parent.KnockdownManager)
local LogManager = require(script.Parent.LogManager)
local MimicManager = require(script.Parent.MimicManager)
local QuestManager = require(script.Parent.QuestManager)
local RunManager = require(script.Parent.RunManager)
local ToolManager = require(script.Parent.ToolManager)
local UpgradeManager = require(script.Parent.UpgradeManager)
local ZoneManager = require(script.Parent.ZoneManager)
local Blocky = require(script.Parent.Parent.Build.Blocky)

local CHAR_COLOR = Color3.fromRGB(30, 25, 22) -- a burned mimic turns this colour
local CRUMBLE_TIME = 0.8 -- seconds a burned mimic takes to fade away

local TreeManager = {}

local stumpsFolder: Folder
local notifyRemote: RemoteEvent
local treeHitRemote: RemoteEvent

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

-- Visible damage: a notch on the side the player chops from, deeper as HP goes down.
-- It never gets shallower, even when a waking mimic's HP goes up.
-- Returns where the notch opens on the bark, facing out.
local function cutNotch(tree: Model, trunk: BasePart, fromPosition: Vector3): CFrame
	local cfg = Config.Tree
	local hpFraction = getNumberAttribute(tree, "HP") / math.max(getNumberAttribute(tree, "MaxHP"), 1)
	local cut = cfg.NotchFirstHit + (cfg.NotchMaxDepth - cfg.NotchFirstHit) * (1 - hpFraction)
	cut = math.max(cut, getNumberAttribute(tree, "NotchCut"))
	tree:SetAttribute("NotchCut", cut)
	return Blocky.notch(tree, trunk, fromPosition - trunk.Position, cut)
end

-- The way a tree falls: away from the player who felled it, flat on the ground.
local function fallDirection(tree: Model, fromPosition: Vector3): Vector3
	local base = tree:GetPivot().Position
	local away = Vector3.new(base.X - fromPosition.X, 0, base.Z - fromPosition.Z)
	if away.Magnitude < 0.01 then
		return Vector3.xAxis
	end
	return away.Unit
end

-- A short square stump with a light, ringed top stays where the tree stood, so cleared
-- areas are easy to spot. The tree's roots stay with it. A burned mimic leaves a charred black stump.
local function leaveStump(tree: Model, trunk: BasePart, charred: boolean)
	local width = getNumberAttribute(tree, "TrunkWidth")
	local height = Config.Tree.StumpHeight
	-- Normal stumps are a bit darker than the bark.
	local color = if charred then CHAR_COLOR else trunk.Color:Lerp(Color3.new(0, 0, 0), 0.25)
	-- The Stump model from Blender when that's imported (the same size), or a plain block.
	local stump = Blocky.block(
		Config.Models.Stump,
		"Stump",
		Vector3.new(width, height, width),
		CFrame.new(tree:GetPivot().Position + Vector3.new(0, height / 2, 0)) * trunk.CFrame.Rotation,
		color,
		Enum.Material.Wood,
		stumpsFolder
	)
	stump.CanCollide = false -- so nobody gets stuck on stumps
	if not charred then
		Blocky.rings(stump, Enum.NormalId.Top)
	end
	for _, part in tree:GetChildren() do
		if part.Name == "Root" and part:IsA("BasePart") then
			part.Parent = stumpsFolder
			if charred then
				part.Color = CHAR_COLOR
			end
		end
	end
end

-- The tree falls over (`away` is the way it falls), then the logs pop out and it's removed.
-- Mimics don't leave a stump: they pulled their roots out when they woke up.
-- The server doesn't move the tree: every player's computer animates the crack, fall and
-- bounce itself (Client/Controllers/ChopEffectsController), so it's smooth on every screen.
-- The server only waits for it to land, then drops the logs and removes the tree.
local function fellTree(tree: Model, trunk: BasePart, away: Vector3, withStump: boolean)
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

	local cfg = Config.Tree
	local base = tree:GetPivot().Position
	task.delay(cfg.CrackTime + cfg.FallTime, function()
		-- It has landed: the logs pop out of the fallen trunk.
		LogManager.spawnLogs(
			base,
			away,
			cfg.LogsPerTree,
			getNumberAttribute(tree, "LogValue"),
			tree:GetAttribute("Cursed") == true
		)
		-- It lies there for a moment, then fades away on every screen.
		task.delay(cfg.RemoveDelay + cfg.FadeTime, function()
			tree:Destroy()
		end)
	end)
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
	EffectsManager.playSound("Burn", trunk.Position)
	local embers = EffectsManager.stream("Embers", trunk)

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
		if embers then
			embers.Enabled = false
		end
		for _, part in parts do
			TweenService:Create(part, TweenInfo.new(CRUMBLE_TIME), { Transparency = 1 }):Play()
		end
		-- Pictures on parts (like birch marks) don't fade with the part, so hide them.
		for _, descendant in tree:GetDescendants() do
			if descendant:IsA("SurfaceGui") then
				descendant.Enabled = false
			end
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
	if not ChopRules.inReach(root.Position, tree, toolId) then
		return
	end

	-- 3. Is the player swinging faster than their tool allows?
	local stats = Config.Tools[toolId]
	local now = os.clock()
	local last = lastSwing[player]
	if last and now - last < stats.Cooldown * Config.Anticheat.CooldownTolerance then
		return
	end
	lastSwing[player] = now

	-- The SERVER decides the damage, from the held tool and upgrades.
	local damage = stats.Damage * UpgradeManager.damageMultiplier(player)

	-- 4. The Elder Hollow and its roots: BossManager decides what a hit does.
	-- Each chopping tool has its own hit sound (the Torch and Lantern don't chop).
	if isBoss then
		local feel = Config.ChopFeel[toolId]
		if feel then
			EffectsManager.playSound(feel.Sound, tree:GetPivot().Position, player)
		end
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
	local notch = cutNotch(tree, trunk, root.Position)
	local falling = if hp <= 0 then fallDirection(tree, root.Position) else nil

	if falling then
		local wasMimic = MimicManager.isMimic(tree)
		MimicManager.forget(tree)
		fellTree(tree, trunk, falling, not wasMimic)
		QuestManager.report(player, "FellTree")
		RunManager.record(player, "TreesFelled", 1) -- counts for whoever landed the last hit
		if wasMimic then
			RunManager.record(player, "MimicsChopped", 1)
			notifyRemote:FireAllClients(`{player.DisplayName} chopped down a mimic!`)
		end
	end

	-- Every player draws the hit (and the fall) themselves: Client/Controllers/ChopEffectsController.
	-- Sent after fellTree, so every player already has the stump and the "Felled" mark when
	-- the tree starts to fall on their screen.
	treeHitRemote:FireAllClients(tree, notch.Position, notch.LookVector, toolId, player, falling)

	if not falling and MimicManager.isMimic(tree) then
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
	treeHitRemote = Remotes.getEvent("TreeHit")
	Remotes.getEvent("SwingAtTree").OnServerEvent:Connect(onSwing)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastSwing[player] = nil
	end)
end

return TreeManager
