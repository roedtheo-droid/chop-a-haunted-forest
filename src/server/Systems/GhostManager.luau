--!strict
-- Ghosts: they float around the zones, follow players who come close, and scare them
-- (CourageManager drains courage near them). Catch them with the Ghost Vacuum for coins
-- and courage. (An idea from Theo's Claude Design export.)
--
-- Each zone keeps up to Config.Ghosts.PerZone[zone] ghosts; a new one appears every
-- SpawnEvery seconds while it has fewer. A ghost drifts to a random spot nearby, or
-- towards the closest player within ChaseRadius (not one holding a Lantern or Torch: the
-- light keeps them away), and stops a few studs from them to stare.
--
-- The vacuum: the client only says "I clicked" (the VacuumGhost remote). The server checks
-- the player holds a Ghost Vacuum they own, isn't clicking too fast, and finds the closest
-- ghost in front of them within VacuumRange. So nobody can catch ghosts from across the map.
--
-- A ghost is one anchored "Root" block that moves; the rest of its blocks are welded to it.
-- When a "Ghost" Blender model is imported (see Build/Assets) it's used instead of the blocks.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Assets = require(script.Parent.Parent.Build.Assets)
local AnalyticsManager = require(script.Parent.AnalyticsManager)
local CoinManager = require(script.Parent.CoinManager)
local CourageManager = require(script.Parent.CourageManager)
local EffectsManager = require(script.Parent.EffectsManager)
local KnockdownManager = require(script.Parent.KnockdownManager)
local ToolManager = require(script.Parent.ToolManager)

local cfg = Config.Ghosts
local BLACK = Color3.fromRGB(25, 25, 35)

local GhostManager = {}

local folder: Folder
local random = Random.new()
local lastVacuum: { [Player]: number } = {}
-- The tween moving each ghost right now, so a catch can stop it.
local moving: { [Model]: Tween } = {}

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- The ground height at (x, z): a ray straight down that ignores trees, players and ghosts,
-- so ghosts float over the grass and not over the treetops. The list of things to ignore is
-- made again every few seconds (trees fall, players respawn), not for every ray.
local rayParams: RaycastParams? = nil
local rayParamsMade = 0
local RAY_PARAMS_LIFETIME = 5

local function groundHeightAt(x: number, z: number): number
	local params = rayParams
	if not params or os.clock() - rayParamsMade > RAY_PARAMS_LIFETIME then
		local fresh = RaycastParams.new()
		fresh.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = { folder }
		for _, tree in CollectionService:GetTagged(Tags.Tree) do
			table.insert(ignore, tree)
		end
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		fresh.FilterDescendantsInstances = ignore
		rayParams = fresh
		rayParamsMade = os.clock()
		params = fresh
	end
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return if result then result.Position.Y else 0
end

-- A spot `cfg.Height` above the ground (plus a little bob), kept inside the zone.
local function floatSpot(zone: number, x: number, z: number): Vector3
	local bounds = Zones.getBounds(zone)
	local cx = math.clamp(x, bounds.MinX + cfg.EdgeMargin, bounds.MaxX - cfg.EdgeMargin)
	local cz = math.clamp(z, bounds.MinZ + cfg.EdgeMargin, bounds.MaxZ - cfg.EdgeMargin)
	local y = groundHeightAt(cx, cz) + cfg.Height + random:NextNumber(-cfg.Bob, cfg.Bob)
	return Vector3.new(cx, y, cz)
end

---------------------------------------------------------------------------
-- Building a ghost
---------------------------------------------------------------------------

local function block(model: Model, name: string, size: Vector3, offset: CFrame, root: BasePart?, color: Color3?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color or cfg.Color
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = if color then 0 else cfg.Transparency
	part.CastShadow = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	if root then
		part.Anchored = false
		part.Massless = true
		part.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	else
		part.Anchored = true
	end
	part.Parent = model
	return part
end

-- The blocky placeholder: a big head, a body that gets narrower towards a wispy tail,
-- two black eyes and an "O" mouth on the front (-Z is its front).
local function buildBlocks(model: Model): BasePart
	local s = cfg.Size
	local root = block(model, "Root", Vector3.new(s, s, s), CFrame.new(), nil)
	block(model, "Body", Vector3.new(s * 0.8, s * 0.55, s * 0.8), CFrame.new(0, -s * 0.75, 0), root)
	block(model, "Tail", Vector3.new(s * 0.5, s * 0.4, s * 0.5), CFrame.new(0, -s * 1.2, s * 0.1), root)
	block(model, "TailTip", Vector3.new(s * 0.25, s * 0.3, s * 0.25), CFrame.new(0, -s * 1.5, s * 0.2), root)
	block(model, "ArmL", Vector3.new(s * 0.2, s * 0.45, s * 0.2), CFrame.new(-s * 0.55, -s * 0.6, 0) * CFrame.Angles(0, 0, math.rad(-25)), root)
	block(model, "ArmR", Vector3.new(s * 0.2, s * 0.45, s * 0.2), CFrame.new(s * 0.55, -s * 0.6, 0) * CFrame.Angles(0, 0, math.rad(25)), root)
	local face = -s / 2 - 0.02
	block(model, "EyeL", Vector3.new(s * 0.16, s * 0.24, 0.1), CFrame.new(-s * 0.2, s * 0.08, face), root, BLACK)
	block(model, "EyeR", Vector3.new(s * 0.16, s * 0.24, 0.1), CFrame.new(s * 0.2, s * 0.08, face), root, BLACK)
	block(model, "Mouth", Vector3.new(s * 0.14, s * 0.16, 0.1), CFrame.new(0, -s * 0.22, face), root, BLACK)
	return root
end

-- The imported "Ghost" model: its biggest part becomes the Root and the rest are welded to it.
local function fromAsset(model: Model, asset: Model): BasePart?
	local parts: { BasePart } = {}
	for _, part in asset:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	table.sort(parts, function(a: BasePart, b: BasePart): boolean
		return a.Size.Magnitude > b.Size.Magnitude
	end)
	local root = parts[1]
	if not root then
		return nil
	end
	for _, part in parts do
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Parent = model
		if part ~= root then
			part.Anchored = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	root.Name = "Root"
	asset:Destroy()
	return root
end

local function buildGhost(zone: number, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Ghost"
	local root: BasePart? = nil
	if Assets.has("Ghost") then
		local asset = Assets.model("Ghost")
		if asset then
			root = fromAsset(model, asset)
		end
	end
	if not root then
		root = buildBlocks(model)
	end
	local rootPart = root :: BasePart
	model.PrimaryPart = rootPart

	local light = Instance.new("PointLight")
	light.Color = cfg.LightColor
	light.Range = cfg.LightRange
	light.Brightness = 1
	light.Parent = rootPart

	model:PivotTo(CFrame.new(position))
	model:SetAttribute("ZoneId", zone)
	CollectionService:AddTag(model, Tags.Ghost)
	model.Parent = folder
	return model
end

---------------------------------------------------------------------------
-- Floating around
---------------------------------------------------------------------------

-- The closest player this ghost should follow, if any: alive, standing, in the same zone,
-- within ChaseRadius and not holding a light.
local function playerToFollow(zone: number, from: Vector3): Vector3?
	local best: Vector3? = nil
	local bestDistance = cfg.ChaseRadius
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		if not root or KnockdownManager.isDown(player) or CourageManager.holdsLight(player) then
			continue
		end
		if Zones.indexAt(root.Position) ~= zone then
			continue
		end
		local distance = (root.Position - from).Magnitude
		if distance < bestDistance then
			best = root.Position
			bestDistance = distance
		end
	end
	return best
end

-- Where the ghost goes next, how fast, and the player it stares at on the way (nil when
-- it's just drifting: then it faces where it's going).
local function nextSpot(zone: number, from: Vector3): (Vector3, number, Vector3?)
	local target = playerToFollow(zone, from)
	if target then
		local away = Vector3.new(from.X - target.X, 0, from.Z - target.Z)
		local offset = if away.Magnitude > 0.1 then away.Unit * cfg.HoverDistance else Vector3.new(cfg.HoverDistance, 0, 0)
		local spot = target + offset
		return floatSpot(zone, spot.X, spot.Z), cfg.ChaseSpeed, target
	end
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = random:NextNumber(cfg.Wander * 0.4, cfg.Wander)
	return floatSpot(zone, from.X + math.cos(angle) * distance, from.Z + math.sin(angle) * distance), cfg.Speed, nil
end

local function float(ghost: Model, zone: number)
	while ghost.Parent and ghost:GetAttribute("Caught") ~= true do
		local root = ghost.PrimaryPart
		if not root then
			return
		end
		local from = root.Position
		local spot, speed, staresAt = nextSpot(zone, from)
		local distance = (spot - from).Magnitude
		local seconds = math.clamp(distance / speed, 0.5, cfg.MaxStep)
		-- Move only as far as it gets in `seconds`, then look again (players move).
		local stepTarget = from:Lerp(spot, math.min(1, speed * seconds / math.max(distance, 0.01)))
		local lookAt = staresAt or stepTarget
		local flat = if staresAt then Vector3.new(lookAt.X - stepTarget.X, 0, lookAt.Z - stepTarget.Z) else Vector3.new(stepTarget.X - from.X, 0, stepTarget.Z - from.Z)
		local facing = if flat.Magnitude > 0.1 then CFrame.lookAt(stepTarget, stepTarget + flat) else CFrame.new(stepTarget) * root.CFrame.Rotation
		local tween = TweenService:Create(root, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = facing })
		moving[ghost] = tween
		tween:Play()
		task.wait(seconds)
	end
end

local function spawnGhost(zone: number)
	local bounds = Zones.getBounds(zone)
	local x = random:NextNumber(bounds.MinX + cfg.EdgeMargin, bounds.MaxX - cfg.EdgeMargin)
	local z = random:NextNumber(bounds.MinZ + cfg.EdgeMargin, bounds.MaxZ - cfg.EdgeMargin)
	local ghost = buildGhost(zone, floatSpot(zone, x, z))
	task.spawn(float, ghost, zone)
end

local function ghostsIn(zone: number): number
	local count = 0
	for _, ghost in folder:GetChildren() do
		if ghost:GetAttribute("ZoneId") == zone and ghost:GetAttribute("Caught") ~= true then
			count += 1
		end
	end
	return count
end

---------------------------------------------------------------------------
-- The Ghost Vacuum
---------------------------------------------------------------------------

-- The closest ghost in front of the player, within reach of the vacuum.
local function ghostInFront(root: BasePart): Model?
	local best: Model? = nil
	local bestDistance = cfg.VacuumRange
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0 then look.Unit else Vector3.new(0, 0, -1)
	for _, ghost in folder:GetChildren() do
		if not ghost:IsA("Model") or ghost:GetAttribute("Caught") == true then
			continue
		end
		local offset = ghost:GetPivot().Position - root.Position
		local distance = offset.Magnitude
		local flat = Vector3.new(offset.X, 0, offset.Z)
		-- Right on top of you counts as in front.
		local ahead = if flat.Magnitude > 2 then flat.Unit:Dot(look) else 1
		if distance < bestDistance and ahead >= cfg.VacuumAim then
			best = ghost
			bestDistance = distance
		end
	end
	return best
end

-- The ghost flies into the nozzle, shrinking and fading, then it's gone.
local function suckIn(ghost: Model, player: Player, root: BasePart)
	ghost:SetAttribute("Caught", true)
	local tween = moving[ghost]
	if tween then
		tween:Cancel()
	end
	moving[ghost] = nil
	CollectionService:RemoveTag(ghost, Tags.Ghost)

	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	local head = if tool then tool:FindFirstChild("Head") else nil
	local target = if head and head:IsA("BasePart") then head.Position else root.Position
	local info = TweenInfo.new(cfg.CatchTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local ghostRoot = ghost.PrimaryPart
	if ghostRoot then
		TweenService:Create(ghostRoot, info, { CFrame = CFrame.new(target) * ghostRoot.CFrame.Rotation }):Play()
	end
	for _, part in ghost:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, info, { Transparency = 1 }):Play()
		elseif part:IsA("PointLight") then
			TweenService:Create(part, info, { Brightness = 0 }):Play()
		end
	end
	EffectsManager.playSound("GhostCatch", ghost:GetPivot().Position, player)
	task.delay(cfg.CatchTime + 0.05, function()
		ghost:Destroy()
	end)
end

local function onVacuum(player: Player)
	if ToolManager.getEquippedId(player) ~= "GhostVacuum" then
		return
	end
	local root = getRoot(player)
	if not root or KnockdownManager.isDown(player) then
		return
	end
	local now = os.clock()
	local last = lastVacuum[player]
	if last and now - last < Config.Tools.GhostVacuum.Cooldown * Config.Anticheat.CooldownTolerance then
		return
	end
	lastVacuum[player] = now

	local ghost = ghostInFront(root)
	if not ghost then
		return
	end
	suckIn(ghost, player, root)
	CoinManager.add(player, cfg.Reward)
	CourageManager.add(player, cfg.CourageReward)
	AnalyticsManager.earned(player, "Coins", cfg.Reward, "CaughtGhost")
	AnalyticsManager.event(player, "GhostCaught")
end

---------------------------------------------------------------------------

function GhostManager.init()
	folder = Instance.new("Folder")
	folder.Name = "Ghosts"
	folder.Parent = workspace
end

function GhostManager.start()
	Remotes.getEvent("VacuumGhost").OnServerEvent:Connect(onVacuum)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastVacuum[player] = nil
	end)
	folder.ChildRemoved:Connect(function(ghost: Instance)
		if ghost:IsA("Model") then
			moving[ghost] = nil
		end
	end)

	-- Wait for the forest to be planted, so ghosts float over the ground and not at y = 0.
	task.wait(1)
	while true do
		for zone = 1, Zones.count() do
			if ghostsIn(zone) < (cfg.PerZone[zone] or 0) then
				spawnGhost(zone)
			end
		end
		task.wait(cfg.SpawnEvery)
	end
end

return GhostManager
