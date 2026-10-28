--!strict
-- The fun part of chopping, only for looks (see STYLE_GUIDE.md). The server tells every
-- player about each hit (the TreeHit remote), and each player draws the effects on their own screen:
--   * the tool's chop sound, a little higher or lower each time
--   * little wood cubes fly out of the notch with a small puff and flash, and the crown wobbles
--   * your camera jolts a little on your own hits
--   * a puff of dust and a camera shake where a falling tree lands
-- How many chips and how hard things shake depends on the tool (Config.ChopFeel).
-- Your own hits don't wait for the server: ChopController calls showMyHit the moment your
-- swing lands, so chopping feels instant.
-- None of this changes the game, so it's fine that it runs on the client.
-- (The notch itself is built by the server, so every player sees the same one.)

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

local cfg = Config.ChopEffects
local Style = Config.Style

type Wobble = {
	Leaves: BasePart,
	Axis: Vector3,
	Angle: number, -- radians: how far it sways at most (bigger tools sway it more)
	Pivot: Vector3, -- the top of the trunk: the crown turns around this point
	Started: number,
	Applied: CFrame, -- the turn we added last frame, so we can take it off again
}

local ChopEffectsController = {}

local player = Players.LocalPlayer
local random = Random.new()
local folder: Folder -- everything we make here goes in this folder, which only this player has
local wobbles: { [Model]: Wobble } = {}
local chipCount = 0
local shakeUntil = 0
local shakeStrength = 0
local shakeTime = 1
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
	if now >= shakeUntil or not camera then
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
-- Every hit: sound, chips, puff, flash and wobble
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
	Fx.playSound(sound, position, 1 + random:NextNumber(-cfg.PitchJitter, cfg.PitchJitter))
end

-- Little wood cubes that fly out of the notch, bounce on the ground and fade away.
local function spawnChips(position: Vector3, outward: Vector3, barkColor: Color3, feel: Types.ChopFeelConfig)
	for index = 1, feel.Chips do
		if chipCount >= cfg.MaxChips then
			return
		end
		local size = feel.ChipSize * random:NextNumber(0.6, 1.3)
		local color = if index % 3 == 0 then barkColor else Style.InnerWood
		local chip = plainPart(
			"Chip",
			Vector3.one * size,
			CFrame.new(position + outward * 0.5) * CFrame.Angles(random:NextNumber(0, 6), random:NextNumber(0, 6), 0),
			color
		)
		chip.Material = Enum.Material.Wood
		-- Out of the notch, a bit up, spread out a little.
		local spread = Vector3.new(random:NextNumber(-0.7, 0.7), random:NextNumber(0.3, 1.1), random:NextNumber(-0.7, 0.7))
		chip.AssemblyLinearVelocity = (outward + spread).Unit * cfg.ChipSpeed * random:NextNumber(0.6, 1)
		chip.AssemblyAngularVelocity =
			Vector3.new(random:NextNumber(-15, 15), random:NextNumber(-15, 15), random:NextNumber(-15, 15))
		chip.Parent = folder
		chipCount += 1

		task.delay(cfg.ChipLifetime, function()
			TweenService:Create(chip, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end)
		-- Removed on a timer, not when the fade ends, so a chip can never be left behind.
		task.delay(cfg.ChipLifetime + 0.3, function()
			chip:Destroy()
			chipCount -= 1
		end)
	end
end

-- A small puff of light, dusty cubes where the swing hits.
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
		cube.Parent = folder

		local drift = (outward + Vector3.new(random:NextNumber(-0.8, 0.8), random:NextNumber(-0.2, 0.8), random:NextNumber(-0.8, 0.8)))
			* random:NextNumber(0.8, 1.8)
		local duration = cfg.PuffTime * random:NextNumber(0.7, 1.2)
		TweenService:Create(
			cube,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = cube.CFrame + drift, Size = cube.Size * 1.8, Transparency = 1 }
		):Play()
		Debris:AddItem(cube, duration)
	end
end

-- A quick white flash right where the swing hits.
local function hitFlash(position: Vector3)
	local flash = plainPart(
		"Flash",
		Vector3.one * cfg.FlashSize * 0.4,
		CFrame.new(position) * CFrame.Angles(random:NextNumber(0, 6), random:NextNumber(0, 6), 0),
		Color3.new(1, 1, 1)
	)
	flash.Anchored = true
	flash.CanCollide = false
	flash.Material = Enum.Material.Neon
	flash.Transparency = 0.3
	flash.Parent = folder
	TweenService:Create(
		flash,
		TweenInfo.new(cfg.FlashTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * cfg.FlashSize, Transparency = 1 }
	):Play()
	Debris:AddItem(flash, cfg.FlashTime)
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

local function updateWobbles()
	local now = os.clock()
	for tree, state in wobbles do
		local leaves = state.Leaves
		if not leaves.Parent or tree:GetAttribute("Felled") then
			wobbles[tree] = nil -- it's falling: the server moves it now, so let go
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

-- Draw one hit. `position` is where the notch opens on the bark, `outward` the way it faces.
-- `hitter` is the player who swung (nil if they just left the game).
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
	playChopSound(feel, position, hitter)
	spawnChips(position, outward, trunk.Color, feel)
	hitPuff(position, outward)
	hitFlash(position + outward * 0.2)
	if not falling then
		wobble(tree, trunk, outward, feel.Wobble)
	end
	if hitter == player then
		shakeCamera(feel.CameraKick, cfg.KickTime)
	end
end

---------------------------------------------------------------------------
-- Dust and camera shake (when a tree falls)
---------------------------------------------------------------------------

-- A puff of grey-brown cubes that grow, drift out and fade where the tree lands.
local function dustPuff(position: Vector3)
	for _ = 1, cfg.DustCubes do
		local size = cfg.DustSize * random:NextNumber(0.6, 1.2)
		local cube = plainPart(
			"Dust",
			Vector3.one * size,
			CFrame.new(position + Vector3.new(random:NextNumber(-1, 1), size / 2, random:NextNumber(-1, 1)))
				* CFrame.Angles(0, random:NextNumber(0, 6), 0),
			cfg.DustColor:Lerp(Color3.new(1, 1, 1), random:NextNumber(0, 0.25))
		)
		cube.Anchored = true
		cube.CanCollide = false
		cube.Material = Enum.Material.SmoothPlastic
		cube.Parent = folder

		local angle = random:NextNumber(0, math.pi * 2)
		local drift = Vector3.new(math.cos(angle), 0, math.sin(angle)) * random:NextNumber(2, 6)
			+ Vector3.new(0, random:NextNumber(0.5, 2.5), 0)
		local duration = cfg.DustTime * random:NextNumber(0.7, 1.2)
		TweenService:Create(cube, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = cube.CFrame + drift,
			Size = cube.Size * 2,
			Transparency = 1,
		}):Play()
		Debris:AddItem(cube, duration) -- removed on a timer, so it can never be left behind
	end
end

local function onTreeFalling(tree: Model, trunk: BasePart, away: Vector3)
	local base = tree:GetPivot().Position
	local height = trunk.Size.Y -- the trunk is a block: Size.Y is its height
	-- The same spot the server uses for the crash sound.
	local landing = base + away * height * 0.6
	task.delay(Config.Tree.FallTime, function()
		dustPuff(landing)
		local distance = distanceTo(landing)
		if distance <= cfg.ShakeDistance then
			-- Stronger the closer you are.
			shakeCamera(cfg.ShakeStrength * (1 - distance / cfg.ShakeDistance * 0.6), cfg.ShakeTime)
		end
	end)
end

---------------------------------------------------------------------------

-- Your own hit, drawn the moment your swing lands (called by ChopController), so you don't
-- wait for the server. It's drawn right where the server is about to cut the notch.
function ChopEffectsController.showMyHit(tree: Model, toolId: string, from: Vector3)
	local trunk = getTrunk(tree)
	if not trunk then
		return
	end
	local opening = ChopRules.notchOpening(trunk, ChopRules.notchFace(tree, trunk, from - trunk.Position))
	local now = os.clock()
	for other, shown in shownAt do
		if now - shown > cfg.ShownWindow then
			shownAt[other] = nil -- forget old ones, so this list stays short
		end
	end
	shownAt[tree] = now
	playHit(tree, trunk, opening.Position, opening.LookVector, toolId, player, false)
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
	if not trunk or distanceTo(position) > cfg.EffectsDistance then
		return
	end
	local who: Player? = nil
	if typeof(hitter) == "Instance" and (hitter :: Instance):IsA("Player") then
		who = hitter :: Player
	end

	-- Your own hits were already drawn the moment your swing landed (see showMyHit).
	local shown = shownAt[tree]
	if not (who == player and shown and os.clock() - shown < cfg.ShownWindow) then
		playHit(tree, trunk, position, outward, toolId, who, typeof(falling) == "Vector3")
	end
	if typeof(falling) == "Vector3" then
		onTreeFalling(tree, trunk, falling)
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

	Players.PlayerRemoving:Connect(function(leaving: Player)
		lastSound[leaving] = nil
	end)

	-- Load the chop sounds now, so even the very first hit plays without a delay.
	local sounds: { string } = {}
	for _, feel in Config.ChopFeel do
		table.insert(sounds, Config.Sounds[feel.Sound].Id)
	end
	ContentProvider:PreloadAsync(sounds)
end

return ChopEffectsController
