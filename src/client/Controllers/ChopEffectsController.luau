--!strict
-- The fun part of chopping, only for looks (see STYLE_GUIDE.md). The server tells every
-- player about each hit (the TreeHit remote), and each player draws the effects on their own screen:
--   * the tool's chop sound, a little higher or lower each time
--   * a warm glow bursts out of the cut with a few rays of light and a soft beige puff
--   * little wood cubes and a splinter or two fly out towards the player who hit, and drop
--   * fine sawdust drifts down from the cut, and a few leaves come loose and flutter down
--   * the crown wobbles
--   * your camera is pushed towards the tree and jolts a little on your own hits
--   * "TIMBER!" over the cut when a tree falls (only with Config.ShowTimberText)
--   * a felled tree slips, falls away from whoever felled it and bounces, with a crash, a dust
--     cloud along it, leaves bursting off its crown and a small shake; then it turns into logs
-- How many chips and how hard things shake depends on the tool (Config.ChopFeel).
-- Your own hits don't wait for the server: ChopController calls showMyHit the moment your
-- swing lands, so chopping feels instant.
-- None of this changes the game, so it's fine that it runs on the client.
-- (The dents are cut by CarveController, from holes the server picks, so everyone sees the same ones.)

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ChopRules = require(ReplicatedStorage.Shared.ChopRules)
local Config = require(ReplicatedStorage.Shared.Config)
local Fx = require(ReplicatedStorage.Shared.Fx)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CarveController = require(script.Parent.CarveController)

local cfg = Config.ChopEffects
local Style = Config.Style
local CRACK_SHUDDER = math.rad(1) -- how much a cracking tree shakes, besides leaning over
local MAX_FLOATERS = 150 -- never more sawdust and falling leaves than this at once (keeps phones fast)
local GLOW_RAYS = 5 -- thin rays of light that shoot out of the cut with the glow
local GLOW_RAY_LENGTH = 1.6 -- studs

-- Something light that drifts and sinks on our screen: sawdust or a falling leaf.
type Floater = {
	Part: BasePart,
	Start: Vector3,
	Drift: Vector3, -- its push at the start (studs per second), which slows down quickly
	Fall: number, -- studs per second it sinks
	Sway: number, -- studs it sways from side to side
	SwayDirection: Vector3,
	SwaySpeed: number, -- radians per second
	Phase: number,
	Spin: Vector3, -- the axis it turns around
	SpinSpeed: number, -- radians per second
	Started: number,
	Life: number, -- seconds before it's gone (it fades out at the end)
	Transparency: number, -- how see-through it is to begin with
}

type Wobble = {
	Leaves: BasePart,
	Axis: Vector3,
	Angle: number, -- radians: how far it sways at most (bigger tools sway it more)
	Pivot: Vector3, -- the top of the trunk: the crown turns around this point
	Started: number,
	Applied: CFrame, -- the turn we added last frame, so we can take it off again
}

-- A felled tree falling over on our screen.
type Fall = {
	Start: CFrame, -- where the tree's pivot (the bottom of its trunk) was before it fell
	Axis: Vector3, -- turning around this tips the top over the way it falls
	Away: Vector3, -- the way it falls, flat on the ground
	Height: number, -- the trunk's height
	Split: number, -- studs above the ground where it broke (it tips over from there), 0 if it fell whole
	Drop: number, -- studs the broken top drops while it falls, so it ends up lying on the ground
	Started: number,
	Near: boolean, -- close enough to see the dust and leaves where it lands
	Landed: boolean,
	Fade: { [BasePart]: number }?, -- each part's own transparency, once it starts to fade
}

-- A log popping out of a fallen tree on our screen.
type Pop = {
	Log: BasePart,
	From: Vector3, -- inside the fallen trunk
	To: CFrame, -- where the server put it
	Spin: Vector3, -- the axis it spins around while it flies
	Started: number,
}

local ChopEffectsController = {}

local player = Players.LocalPlayer
local random = Random.new()
local folder: Folder -- everything we make here goes in this folder, which only this player has
local wobbles: { [Model]: Wobble } = {}
local falls: { [Model]: Fall } = {}
local pops: { Pop } = {}
local chipCount = 0
local floaters: { Floater } = {}
local shakeUntil = 0
local shakeStrength = 0
local shakeTime = 1
local kickStarted = -math.huge -- when your camera was last pushed towards a tree
local lastSound: { [Player]: { [string]: number } } = {}
local shownAt: { [Model]: number } = {} -- when this computer last drew your own hit on each tree

local function getTrunk(tree: Model): BasePart?
	local trunk = tree:FindFirstChild("Trunk")
	return if trunk and trunk:IsA("BasePart") then trunk else nil
end

-- How far a point is from the player (or the camera, if they have no character).
local function distanceTo(position: Vector3): number
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return (root.Position - position).Magnitude
	end
	local camera = workspace.CurrentCamera
	return if camera then (camera.CFrame.Position - position).Magnitude else math.huge
end

local function plainPart(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	part.CanQuery = false -- so clicks go through to the trees behind
	return part
end

local function pitchJitter(): number
	return 1 + random:NextNumber(-cfg.PitchJitter, cfg.PitchJitter)
end

-- Shake the camera for `duration` seconds, by at most `strength` studs.
-- A small shake (like your own hit) never cuts a bigger one (a tree landing) short.
local function shakeCamera(strength: number, duration: number)
	local now = os.clock()
	local left = if now < shakeUntil then shakeStrength * (shakeUntil - now) / shakeTime else 0
	if strength <= left then
		return
	end
	shakeStrength = strength
	shakeTime = duration
	shakeUntil = now + duration
end

-- Runs right after the camera scripts have placed the camera this frame, so we just nudge it.
local function updateShake()
	local now = os.clock()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- Your own hit: a quick push towards the tree and back, with a little nod.
	local kick = (now - kickStarted) / cfg.KickTime
	if kick < 1 then
		local curve = math.sin(kick * math.pi)
		camera.CFrame *= CFrame.new(0, 0, -cfg.KickPush * curve) * CFrame.Angles(-math.rad(cfg.KickTilt) * curve, 0, 0)
	end
	if now >= shakeUntil then
		return
	end
	local amount = shakeStrength * (shakeUntil - now) / shakeTime
	camera.CFrame *= CFrame.new(
		random:NextNumber(-amount, amount),
		random:NextNumber(-amount, amount),
		random:NextNumber(-amount, amount) * 0.5
	)
end

---------------------------------------------------------------------------
-- Every hit: sound, glow, chips, splinters, puff, sawdust, leaves and wobble
---------------------------------------------------------------------------

local function playChopSound(feel: Types.ChopFeelConfig, position: Vector3, hitter: Player?)
	local sound = Config.Sounds[feel.Sound]
	if not sound then
		return
	end
	-- Sounds with a MinGap (the Chainsaw) don't pile up when one player's hits come fast.
	local gap = sound.MinGap
	if gap and hitter then
		local played = lastSound[hitter] or {}
		lastSound[hitter] = played
		local now = os.clock()
		local last = played[feel.Sound]
		if last and now - last < gap then
			return
		end
		played[feel.Sound] = now
	end
	Fx.playSound(sound, position, pitchJitter())
end

-- A small piece of wood thrown out of the cut: it flies, bounces on the ground and fades away.
local function throwWood(name: string, size: Vector3, cframe: CFrame, color: Color3, velocity: Vector3)
	local piece = plainPart(name, size, cframe, color)
	piece.Material = Enum.Material.Wood
	piece.AssemblyLinearVelocity = velocity
	piece.AssemblyAngularVelocity = Vector3.new(random:NextNumber(-15, 15), random:NextNumber(-15, 15), random:NextNumber(-15, 15))
	piece.Parent = folder
	chipCount += 1

	task.delay(cfg.ChipLifetime, function()
		TweenService:Create(piece, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end)
	-- Removed on a timer, not when the fade ends, so a chip can never be left behind.
	task.delay(cfg.ChipLifetime + 0.3, function()
		piece:Destroy()
		chipCount -= 1
	end)
end

-- Which way wood flies out of the cut: mostly towards the player who hit (`toward`), a bit up,
-- spread out a little.
local function flyDirection(outward: Vector3, toward: Vector3): Vector3
	local aim = (outward * (1 - cfg.ChipsToPlayer) + toward * cfg.ChipsToPlayer).Unit
	local spread = Vector3.new(random:NextNumber(-0.6, 0.6), random:NextNumber(0.3, 1), random:NextNumber(-0.6, 0.6))
	return (aim + spread).Unit
end

-- Little wood cubes (mostly pale inner wood, some bark) and a long splinter or two.
local function spawnChips(position: Vector3, outward: Vector3, toward: Vector3, barkColor: Color3, feel: Types.ChopFeelConfig)
	local start = position + outward * 0.4
	for index = 1, random:NextInteger(feel.ChipsMin, feel.ChipsMax) do
		if chipCount >= cfg.MaxChips then
			return
		end
		local size = feel.ChipSize * random:NextNumber(0.6, 1.3)
		throwWood(
			"Chip",
			Vector3.one * size,
			CFrame.new(start) * CFrame.Angles(random:NextNumber(0, 6), random:NextNumber(0, 6), 0),
			if index % 3 == 0 then barkColor else Style.InnerWood,
			flyDirection(outward, toward) * cfg.ChipSpeed * random:NextNumber(0.6, 1)
		)
	end
	for _ = 1, random:NextInteger(cfg.SplintersMin, cfg.SplintersMax) do
		if chipCount >= cfg.MaxChips then
			return
		end
		local direction = flyDirection(outward, toward)
		-- Long side along the way it flies, so it looks like it's been ripped out.
		throwWood(
			"Splinter",
			cfg.SplinterSize * random:NextNumber(0.7, 1.2),
			CFrame.lookAt(start, start + direction),
			Style.InnerWood:Lerp(Color3.new(1, 1, 1), 0.1),
			direction * cfg.ChipSpeed * random:NextNumber(0.7, 1.1)
		)
	end
end

-- A small puff of soft beige dust around the cut.
local function hitPuff(position: Vector3, outward: Vector3)
	for _ = 1, cfg.PuffCubes do
		local size = cfg.PuffSize * random:NextNumber(0.6, 1.2)
		local cube = plainPart(
			"Puff",
			Vector3.one * size,
			CFrame.new(position + outward * 0.3) * CFrame.Angles(0, random:NextNumber(0, 6), 0),
			cfg.DustColor:Lerp(Color3.new(1, 1, 1), random:NextNumber(0.2, 0.5))
		)
		cube.Anchored = true
		cube.CanCollide = false
		cube.Material = Enum.Material.SmoothPlastic
		cube.Transparency = 0.3
		cube.Parent = folder

		-- It billows out around the cut (only a little towards the player, so it never fills
		-- your screen in first person).
		local side = Vector3.yAxis:Cross(outward)
		local drift = outward * random:NextNumber(0.1, 0.4)
			+ side * random:NextNumber(-0.9, 0.9)
			+ Vector3.yAxis * random:NextNumber(-0.3, 0.7)
		local duration = cfg.PuffTime * random:NextNumber(0.7, 1.2)
		TweenService:Create(
			cube,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = cube.CFrame + drift, Size = cube.Size * 1.8, Transparency = 1 }
		):Play()
		Debris:AddItem(cube, duration)
	end
end

-- How big a punch's hole in this trunk is across (see Config.Cut.HoleSize): the glow covers it.
local function holeSize(trunk: BasePart): number
	return trunk.Size.X * Config.Cut.HoleSize * 2
end

-- A warm white-yellow glow bursts out of the cut, like light shining out of the wood: a glowing
-- plate over the opening that grows and fades, a few thin rays of light shooting out, and a
-- light that brightens the bark around it for a moment.
local function hitGlow(position: Vector3, outward: Vector3, opening: Vector2)
	local face = CFrame.lookAt(position + outward * 0.05, position + outward * 2)
	local glow = plainPart(
		"Glow",
		Vector3.new(opening.X * cfg.GlowSize, opening.Y * cfg.GlowSize, 0.05),
		face,
		cfg.GlowColor
	)
	glow.Anchored = true
	glow.CanCollide = false
	glow.CastShadow = false
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.15
	local light = Instance.new("PointLight")
	light.Color = cfg.GlowColor
	light.Brightness = cfg.GlowBrightness
	light.Range = cfg.GlowRange
	light.Parent = glow
	glow.Parent = folder

	local info = TweenInfo.new(cfg.GlowTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(glow, info, { Size = glow.Size * cfg.GlowGrow, Transparency = 1 }):Play()
	TweenService:Create(light, info, { Brightness = 0 }):Play()
	Debris:AddItem(glow, cfg.GlowTime)

	for _ = 1, GLOW_RAYS do
		-- Out of the cut, fanned out a little around the way it faces.
		local direction = (outward + Vector3.new(random:NextNumber(-0.7, 0.7), random:NextNumber(-0.5, 0.7), random:NextNumber(-0.7, 0.7))).Unit
		local length = GLOW_RAY_LENGTH * random:NextNumber(0.6, 1.2)
		local ray = plainPart(
			"GlowRay",
			Vector3.new(0.07, 0.07, length * 0.3),
			CFrame.lookAt(position, position + direction) * CFrame.new(0, 0, -length * 0.15),
			cfg.GlowColor
		)
		ray.Anchored = true
		ray.CanCollide = false
		ray.CastShadow = false
		ray.Material = Enum.Material.Neon
		ray.Transparency = 0.2
		ray.Parent = folder
		-- It shoots out and stretches as it fades.
		TweenService:Create(ray, info, {
			Size = Vector3.new(0.03, 0.03, length),
			CFrame = CFrame.lookAt(position, position + direction) * CFrame.new(0, 0, -length * 0.8),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ray, cfg.GlowTime)
	end
end

-- Start something light drifting and sinking (see Floater and updateFloaters).
local function addFloater(part: BasePart, drift: Vector3, fall: number, sway: number, life: number)
	if #floaters >= MAX_FLOATERS then
		part:Destroy()
		return
	end
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Parent = folder
	local angle = random:NextNumber(0, math.pi * 2)
	table.insert(floaters, {
		Part = part,
		Start = part.Position,
		Drift = drift,
		Fall = fall,
		Sway = sway,
		SwayDirection = Vector3.new(math.cos(angle), 0, math.sin(angle)),
		SwaySpeed = random:NextNumber(2.5, 4),
		Phase = random:NextNumber(0, math.pi * 2),
		Spin = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1)).Unit,
		SpinSpeed = random:NextNumber(1.5, 4),
		Started = os.clock(),
		Life = life,
		Transparency = part.Transparency,
	})
	Debris:AddItem(part, life + 0.5) -- just in case: it can never be left behind
end

local function updateFloaters(now: number)
	for index = #floaters, 1, -1 do
		local floater = floaters[index]
		local t = now - floater.Started
		if t >= floater.Life or not floater.Part.Parent then
			floater.Part:Destroy()
			table.remove(floaters, index)
			continue
		end
		-- Its push slows down quickly, it sinks steadily and sways from side to side.
		local pushed = floater.Drift * (1 - math.exp(-3 * t)) / 3
		local sway = floater.SwayDirection * math.sin(t * floater.SwaySpeed + floater.Phase) * floater.Sway
		local position = floater.Start + pushed - Vector3.yAxis * floater.Fall * t + sway
		floater.Part.CFrame = CFrame.new(position) * CFrame.fromAxisAngle(floater.Spin, t * floater.SpinSpeed)
		-- Fade out over the last 30% of its life.
		local fade = math.clamp((t / floater.Life - 0.7) / 0.3, 0, 1)
		floater.Part.Transparency = floater.Transparency + (1 - floater.Transparency) * fade
	end
end

-- Fine pale sawdust that drifts out of the cut and sinks slowly.
local function sawdust(position: Vector3, outward: Vector3)
	for _ = 1, cfg.SawdustBits do
		local bit = plainPart(
			"Sawdust",
			Vector3.one * cfg.SawdustSize * random:NextNumber(0.6, 1.3),
			CFrame.new(position + outward * 0.2 + Vector3.new(random:NextNumber(-0.3, 0.3), random:NextNumber(-0.2, 0.2), random:NextNumber(-0.3, 0.3))),
			Style.InnerWood:Lerp(Color3.new(1, 1, 1), random:NextNumber(0.1, 0.35))
		)
		bit.Material = Enum.Material.SmoothPlastic
		local drift = outward * random:NextNumber(0.6, 1.6) + Vector3.new(random:NextNumber(-0.5, 0.5), random:NextNumber(0, 0.6), random:NextNumber(-0.5, 0.5))
		addFloater(bit, drift, cfg.SawdustFall * random:NextNumber(0.7, 1.3), 0.15, cfg.SawdustTime * random:NextNumber(0.7, 1.2))
	end
end

-- Leaves come loose from the crown and flutter down. `count` of them, pushed up by `burst`
-- studs per second (0 = they just drop).
local function looseLeaves(crown: BasePart, count: number, burst: number)
	local size = crown.Size
	for _ = 1, count do
		local start = (
			crown.CFrame
			* CFrame.new(random:NextNumber(-0.45, 0.45) * size.X, random:NextNumber(-0.5, 0.2) * size.Y, random:NextNumber(-0.45, 0.45) * size.Z)
		).Position
		local leaf = plainPart(
			"Leaf",
			Vector3.new(cfg.LeafSize, cfg.LeafSize * 0.25, cfg.LeafSize) * random:NextNumber(0.7, 1.3),
			CFrame.new(start),
			crown.Color:Lerp(Color3.new(1, 1, 1), random:NextNumber(0, 0.15))
		)
		leaf.Material = crown.Material
		local angle = random:NextNumber(0, math.pi * 2)
		local drift = Vector3.new(math.cos(angle), 0, math.sin(angle)) * random:NextNumber(0.5, 2) * (if burst > 0 then 2 else 1)
			+ Vector3.yAxis * burst * random:NextNumber(0.6, 1.2)
		addFloater(
			leaf,
			drift,
			cfg.LeafFallSpeed * random:NextNumber(0.7, 1.2),
			cfg.LeafFlutter * random:NextNumber(0.6, 1.2),
			cfg.LeafFallTime * random:NextNumber(0.8, 1.2)
		)
	end
end

-- The crown of leaves sways for a moment. We only move it on our own screen, and only the
-- leaves (the server never moves a standing tree's leaves, so we can't fight with it).
local function wobble(tree: Model, trunk: BasePart, outward: Vector3, degrees: number)
	local leaves = tree:FindFirstChild("Leaves")
	if not (leaves and leaves:IsA("BasePart")) then
		return -- dead trees without leaves don't wobble
	end
	local existing = wobbles[tree]
	if existing then
		existing.Started = os.clock() -- hit again while wobbling: start over
		existing.Angle = math.rad(degrees)
		return
	end
	wobbles[tree] = {
		Leaves = leaves,
		-- Turning around this axis tips the top towards (and away from) the player.
		Axis = Vector3.yAxis:Cross(outward).Unit,
		Angle = math.rad(degrees),
		Pivot = (trunk.CFrame * CFrame.new(0, trunk.Size.Y / 2, 0)).Position,
		Started = os.clock(),
		Applied = CFrame.identity,
	}
end

-- Stop a wobble and put the crown back where it belongs.
local function stopWobble(tree: Model)
	local state = wobbles[tree]
	if state then
		state.Leaves.CFrame = state.Applied:Inverse() * state.Leaves.CFrame
		wobbles[tree] = nil
	end
end

local function updateWobbles()
	local now = os.clock()
	for tree, state in wobbles do
		local leaves = state.Leaves
		if not leaves.Parent then
			wobbles[tree] = nil
			continue
		end
		if tree:GetAttribute("Felled") then
			stopWobble(tree) -- it's about to fall: the fall moves the whole tree now
			continue
		end
		local t = math.min((now - state.Started) / cfg.WobbleTime, 1)
		local angle = math.sin(t * math.pi * 3) * (1 - t) * state.Angle
		-- Take last frame's turn off and put this frame's on, both around the top of the trunk.
		local turn = CFrame.new(state.Pivot) * CFrame.fromAxisAngle(state.Axis, angle) * CFrame.new(-state.Pivot)
		leaves.CFrame = turn * state.Applied:Inverse() * leaves.CFrame
		state.Applied = turn
		if t >= 1 then
			wobbles[tree] = nil
		end
	end
end

---------------------------------------------------------------------------

-- Chips fly towards whoever hit: your own camera, or the other player's head.
local function towardHitter(hitter: Player?, position: Vector3, outward: Vector3): Vector3
	local from: Vector3? = nil
	if hitter == player then
		local camera = workspace.CurrentCamera
		from = if camera then camera.CFrame.Position else nil
	elseif hitter then
		local character = hitter.Character
		local head = if character then character:FindFirstChild("Head") else nil
		from = if head and head:IsA("BasePart") then head.Position else nil
	end
	return if from and (from - position).Magnitude > 0.1 then (from - position).Unit else outward
end

-- Draw one hit. `position` is where it hit the trunk, `outward` the way that side faces.
-- `hitter` is the player who swung (nil if they just left the game).
-- (The dent itself is cut by the server, see Server/Build/Carve.)
local function playHit(
	tree: Model,
	trunk: BasePart,
	position: Vector3,
	outward: Vector3,
	toolId: string,
	hitter: Player?,
	falling: boolean
)
	local feel = Config.ChopFeel[toolId] or Config.ChopFeel.Fists
	local hole = holeSize(trunk)
	playChopSound(feel, position, hitter)
	hitGlow(position, outward, Vector2.new(hole, hole))
	spawnChips(position, outward, towardHitter(hitter, position, outward), trunk.Color, feel)
	hitPuff(position, outward)
	sawdust(position, outward)
	local crown = tree:FindFirstChild("Leaves")
	if crown and crown:IsA("BasePart") then
		looseLeaves(crown, random:NextInteger(cfg.HitLeavesMin, cfg.HitLeavesMax), 0)
	end
	if not falling then
		wobble(tree, trunk, outward, feel.Wobble)
	end
	if hitter == player then
		shakeCamera(feel.CameraKick, cfg.KickTime)
		kickStarted = os.clock()
	end
end

---------------------------------------------------------------------------
-- A felled tree: slip, fall, bounce, then it turns into logs
---------------------------------------------------------------------------

-- A tan dust cloud that rolls out along the ground from `position`: cubes that grow, drift out
-- low and to the sides (`along` is the way the trunk lies), and fade.
local function dustPuff(position: Vector3, along: Vector3, count: number)
	local side = Vector3.yAxis:Cross(along)
	for _ = 1, count do
		local size = cfg.DustSize * random:NextNumber(0.6, 1.2)
		local cube = plainPart(
			"Dust",
			Vector3.one * size,
			CFrame.new(position + Vector3.new(random:NextNumber(-0.8, 0.8), size / 2, random:NextNumber(-0.8, 0.8)))
				* CFrame.Angles(0, random:NextNumber(0, 6), 0),
			cfg.DustColor:Lerp(Color3.new(1, 1, 1), random:NextNumber(0, 0.25))
		)
		cube.Anchored = true
		cube.CanCollide = false
		cube.Material = Enum.Material.SmoothPlastic
		cube.Transparency = 0.15
		cube.Parent = folder

		-- Mostly out to the sides of the trunk, a bit along it, and only a little up: it rolls.
		local drift = side * random:NextNumber(-5, 5) + along * random:NextNumber(-1.5, 1.5) + Vector3.yAxis * random:NextNumber(0.3, 1.5)
		local duration = cfg.DustTime * random:NextNumber(0.8, 1.4)
		TweenService:Create(cube, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = (cube.CFrame + drift) * CFrame.Angles(0, random:NextNumber(-1, 1), 0),
			Size = cube.Size * 2.2,
			Transparency = 1,
		}):Play()
		Debris:AddItem(cube, duration) -- removed on a timer, so it can never be left behind
	end
end

-- The moment a falling tree hits the ground: a crash, a dust cloud rolling along the trunk,
-- leaves bursting up off the crown and fluttering down, and a small shake if you're close.
local function land(tree: Model, fall: Fall)
	local base = fall.Start.Position
	local length = fall.Height - fall.Split -- the part that fell
	local landing = base + fall.Away * length * 0.6
	Fx.playSound(Config.Sounds.TreeFall, landing, pitchJitter())
	if not fall.Near then
		return
	end
	for index = 1, cfg.DustPuffs do
		local along = (index - 0.5) / cfg.DustPuffs
		dustPuff(base + fall.Away * length * along, fall.Away, math.ceil(cfg.DustCubes / cfg.DustPuffs))
	end
	local crown = tree:FindFirstChild("Leaves")
	if crown and crown:IsA("BasePart") then
		looseLeaves(crown, cfg.LeafCubes, cfg.LandLeafBurst)
	end
	local distance = distanceTo(landing)
	if distance <= cfg.ShakeDistance then
		shakeCamera(cfg.ShakeStrength * (1 - distance / cfg.ShakeDistance * 0.6), cfg.ShakeTime)
	end
end

-- Fade every part of the tree towards invisible (`amount` 0 to 1).
local function fadeTree(tree: Model, fall: Fall, amount: number)
	local own = fall.Fade
	if not own then
		local start: { [BasePart]: number } = {}
		for _, descendant in tree:GetDescendants() do
			if descendant:IsA("BasePart") then
				start[descendant] = descendant.Transparency
			elseif descendant:IsA("SurfaceGui") then
				descendant.Enabled = false -- pictures on parts (birch marks) don't fade with them
			end
		end
		fall.Fade = start
		own = start
	end
	for part, transparency in own do
		part.Transparency = transparency + (1 - transparency) * amount
	end
end

-- A felled tree starts to fall on our screen. The server doesn't move it at all.
local function startFall(tree: Model, trunk: BasePart, away: Vector3, near: boolean)
	if falls[tree] then
		return
	end
	stopWobble(tree)
	local start = tree:GetPivot()
	-- The server broke it at its deepest dent (see Carve.split): the top tips over from there.
	local splitAttribute = tree:GetAttribute("SplitHeight")
	local split = if typeof(splitAttribute) == "number" then splitAttribute else 0
	falls[tree] = {
		Start = start,
		Axis = Vector3.yAxis:Cross(away), -- turning "up" around this by 90 degrees points it along `away`
		Away = away,
		Height = trunk.Size.Y, -- the trunk is a block: Size.Y is its height
		Split = split,
		Drop = math.max(split - trunk.Size.X / 2, 0), -- lying down, the middle of the trunk is half its width up
		Started = os.clock(),
		Near = near,
		Landed = false,
		Fade = nil,
	}
	Fx.playSound(Config.Sounds.TreeCrack, start.Position + Vector3.new(0, split, 0), pitchJitter())
end

local function updateFalls(now: number)
	local timing = Config.Tree
	local lean = math.rad(timing.CrackLean)
	for model, fall in falls do
		if not model.Parent then
			falls[model] = nil -- the server removed it
			continue
		end
		local t = now - fall.Started
		local angle: number
		local drop: number
		local slip = if fall.Split > 0 then timing.SlipDrop else 0
		if t < timing.CrackTime then
			-- It slips: the top sinks a little at the break and starts to lean, with a shudder.
			local u = t / timing.CrackTime
			angle = lean * u + CRACK_SHUDDER * math.sin(t * 60) * (1 - u)
			drop = slip * u * u
		elseif t < timing.CrackTime + timing.FallTime then
			-- It falls: slowly at first, then faster and faster.
			local u = (t - timing.CrackTime) / timing.FallTime
			angle = lean + (math.pi / 2 - lean) * u * u
			drop = slip + (math.max(fall.Drop, slip) - slip) * u * u
		else
			if not fall.Landed then
				fall.Landed = true
				land(model, fall)
			end
			local after = t - timing.CrackTime - timing.FallTime
			-- A little bounce off the ground...
			local bounce = math.min(after / timing.BounceTime, 1)
			angle = math.pi / 2 - math.rad(timing.BounceAngle) * math.sin(bounce * math.pi)
			drop = math.max(fall.Drop, slip)
			if bounce >= 1 then
				-- ...then the crown vanishes and the trunk turns into logs (the server puts them
				-- there now, see LogManager.spawnLogs), so the tree disappears.
				fadeTree(model, fall, 1)
				falls[model] = nil
				continue
			end
		end
		-- Turn around the break, and drop down as it tips so it lands flat on the ground.
		local hinge = fall.Start.Position + Vector3.yAxis * fall.Split
		local turn = CFrame.new(hinge - Vector3.yAxis * drop) * CFrame.fromAxisAngle(fall.Axis, angle) * CFrame.new(-hinge)
		model:PivotTo(turn * fall.Start)
	end
end

---------------------------------------------------------------------------
-- Logs popping out of a fallen tree
---------------------------------------------------------------------------

local function onLogAdded(log: Instance)
	if not log:IsA("BasePart") then
		return
	end
	local from = log:GetAttribute("PopFrom")
	local spawnedAt = log:GetAttribute("SpawnedAt")
	if typeof(from) ~= "Vector3" or typeof(spawnedAt) ~= "number" then
		return
	end
	-- Old logs (lying there since before you joined) stay where they are.
	if workspace:GetServerTimeNow() - spawnedAt > Config.Logs.PopTime or distanceTo(log.Position) > cfg.EffectsDistance then
		return
	end
	table.insert(pops, {
		Log = log,
		From = from,
		To = log.CFrame,
		Spin = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1)).Unit,
		Started = os.clock(),
	})
	log.CFrame = CFrame.new(from)
end

local function updatePops(now: number)
	local popTime = Config.Logs.PopTime
	local height = Config.Logs.PopHeight
	for index = #pops, 1, -1 do
		local pop = pops[index]
		local log = pop.Log
		local t = (now - pop.Started) / popTime
		if not log.Parent or log:GetAttribute("Pulling") then
			table.remove(pops, index) -- picked up, or the Log Vacuum has it: the server moves it now
		elseif t >= 1 then
			log.CFrame = pop.To -- exactly where the server put it
			table.remove(pops, index)
		elseif t < 0.8 then
			-- An arc out of the trunk, spinning, then landing in exactly the server's rotation.
			local u = t / 0.8
			local position = pop.From:Lerp(pop.To.Position, u) + Vector3.yAxis * height * 4 * u * (1 - u)
			log.CFrame = CFrame.new(position) * CFrame.fromAxisAngle(pop.Spin, (1 - u) * math.pi * 2) * pop.To.Rotation
		else
			-- A small hop where it lands.
			local v = (t - 0.8) / 0.2
			log.CFrame = pop.To + Vector3.yAxis * height * 0.15 * 4 * v * (1 - v)
		end
	end
end

---------------------------------------------------------------------------

-- Your own hit, drawn the moment your swing lands (called by ChopController), so you don't
-- wait for the server. It's drawn at `point` (where you aimed), where the server is about to
-- scoop out its hole.
function ChopEffectsController.showMyHit(tree: Model, toolId: string, point: Vector3)
	local trunk = getTrunk(tree)
	if not trunk then
		return
	end
	local now = os.clock()
	for other, shown in shownAt do
		if now - shown > cfg.ShownWindow then
			shownAt[other] = nil -- forget old ones, so this list stays short
		end
	end
	shownAt[tree] = now
	playHit(tree, trunk, point, ChopRules.sideFacing(trunk, point), toolId, player, false)
end

-- "TIMBER!" pops up over the cut in big orange-yellow letters, stays a moment and fades away
-- (Config.Timber). Only when Config.ShowTimberText is on.
local function timber(position: Vector3)
	local look = Config.Timber
	local anchor = plainPart("Timber", Vector3.one * 0.2, CFrame.new(position + Vector3.yAxis * look.Above), Color3.new(1, 1, 1))
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(look.Size.X, look.Size.Y)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = look.Text
	label.Font = Style.TitleFont
	label.TextScaled = true
	label.TextColor3 = look.Color
	local stroke = Instance.new("UIStroke")
	stroke.Color = look.StrokeColor
	stroke.Thickness = Style.TextStroke
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = label
	label.Parent = billboard
	anchor.Parent = folder

	-- Pop in (a little too big, then settling), stay, then fade.
	TweenService:Create(scale, TweenInfo.new(look.ScaleIn, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(look.ScaleIn + look.Hold, function()
		local fade = TweenInfo.new(look.FadeTime)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	end)
	Debris:AddItem(anchor, look.ScaleIn + look.Hold + look.FadeTime)
end

local function onTreeHit(target: unknown, position: unknown, outward: unknown, toolId: unknown, hitter: unknown, falling: unknown)
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Model") then
		return
	end
	if typeof(position) ~= "Vector3" or typeof(outward) ~= "Vector3" or typeof(toolId) ~= "string" then
		return
	end
	local tree = target :: Model
	local trunk = getTrunk(tree)
	if not trunk then
		return
	end
	local near = distanceTo(position) <= cfg.EffectsDistance
	local who: Player? = nil
	if typeof(hitter) == "Instance" and (hitter :: Instance):IsA("Player") then
		who = hitter :: Player
	end

	-- Your own hits were already drawn the moment your swing landed (see showMyHit).
	local isFalling = typeof(falling) == "Vector3"
	local shown = shownAt[tree]
	if near and not (who == player and shown and os.clock() - shown < cfg.ShownWindow) then
		playHit(tree, trunk, position, outward, toolId, who, isFalling)
	end
	-- Every player animates the fall, even far away, because the server doesn't move the tree.
	-- A carved tree first breaks at its deepest dent on this screen (see CarveController).
	if isFalling then
		local split = tree:GetAttribute("SplitHeight")
		task.spawn(function()
			if typeof(split) == "number" then
				CarveController.breakTree(tree, split)
			end
			startFall(tree, trunk, falling :: Vector3, near)
		end)
		if near and Config.ShowTimberText then
			timber(position)
		end
	end
end

function ChopEffectsController.init()
	folder = Instance.new("Folder")
	folder.Name = "ChopEffects"
	folder.Parent = workspace
end

function ChopEffectsController.start()
	Remotes.getEvent("TreeHit").OnClientEvent:Connect(onTreeHit)

	RunService.RenderStepped:Connect(updateWobbles)
	RunService:BindToRenderStep("ChopCameraShake", Enum.RenderPriority.Camera.Value + 1, updateShake)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		updateFalls(now)
		updatePops(now)
		updateFloaters(now)
	end)

	Players.PlayerRemoving:Connect(function(leaving: Player)
		lastSound[leaving] = nil
	end)

	-- Logs are made by the server (Server/Systems/LogManager) in this folder.
	local logs = workspace:WaitForChild("Logs")
	logs.ChildAdded:Connect(onLogAdded)

	-- Load the chop sounds now, so even the very first hit plays without a delay.
	-- PreloadAsync needs Sound objects: a plain id would be loaded as a picture, and fail.
	local names = { "TreeCrack", "TreeFall" }
	for _, feel in Config.ChopFeel do
		table.insert(names, feel.Sound)
	end
	local sounds: { Instance } = {}
	for _, name in names do
		local sound = Instance.new("Sound")
		sound.SoundId = Config.Sounds[name].Id
		table.insert(sounds, sound)
	end
	ContentProvider:PreloadAsync(sounds)
end

return ChopEffectsController
