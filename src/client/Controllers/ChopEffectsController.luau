--!strict
-- The fun part of chopping, only for looks (see STYLE_GUIDE.md). The server tells every
-- player about each hit (the TreeHit remote), and each player draws the effects on their own screen:
--   * little wood cubes fly out of the notch, and the crown of leaves wobbles
--   * a puff of dust and a camera shake where a falling tree lands
-- None of this changes the game, so it's fine that it runs on the client.
-- (The notch itself is built by the server, so every player sees the same one.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local cfg = Config.ChopEffects
local Style = Config.Style

type Wobble = {
	Leaves: BasePart,
	Axis: Vector3,
	Pivot: Vector3, -- the top of the trunk: the crown turns around this point
	Started: number,
	Applied: CFrame, -- the turn we added last frame, so we can take it off again
}

local ChopEffectsController = {}

local player = Players.LocalPlayer
local random = Random.new()
local folder: Folder -- everything we make here goes in this folder, which only this player has
local wobbles: { [Model]: Wobble } = {}
local shakeUntil = 0
local shakeStrength = 0

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

---------------------------------------------------------------------------
-- Chips and wobble (every hit)
---------------------------------------------------------------------------

-- Little wood cubes that fly out of the notch, bounce on the ground and fade away.
local function spawnChips(position: Vector3, outward: Vector3, barkColor: Color3)
	for index = 1, Config.Tree.ChipsPerHit do
		local size = cfg.ChipSize * random:NextNumber(0.6, 1.3)
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

		task.delay(cfg.ChipLifetime, function()
			local fade = TweenService:Create(chip, TweenInfo.new(0.3), { Transparency = 1 })
			fade.Completed:Connect(function()
				chip:Destroy()
			end)
			fade:Play()
		end)
	end
end

-- The crown of leaves sways for a moment. We only move it on our own screen, and only the
-- leaves (the server never moves a standing tree's leaves, so we can't fight with it).
local function wobble(tree: Model, trunk: BasePart, outward: Vector3)
	local leaves = tree:FindFirstChild("Leaves")
	if not (leaves and leaves:IsA("BasePart")) then
		return -- dead trees without leaves don't wobble
	end
	local existing = wobbles[tree]
	if existing then
		existing.Started = os.clock() -- hit again while wobbling: start over
		return
	end
	wobbles[tree] = {
		Leaves = leaves,
		-- Turning around this axis tips the top towards (and away from) the player.
		Axis = Vector3.yAxis:Cross(outward).Unit,
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
		local angle = math.sin(t * math.pi * 3) * (1 - t) * math.rad(cfg.WobbleAngle)
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
		local tween = TweenService:Create(
			cube,
			TweenInfo.new(cfg.DustTime * random:NextNumber(0.7, 1.2), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				CFrame = cube.CFrame + drift,
				Size = cube.Size * 2,
				Transparency = 1,
			}
		)
		tween.Completed:Connect(function()
			cube:Destroy()
		end)
		tween:Play()
	end
end

local function shakeCamera(distance: number)
	-- Stronger the closer you are.
	local strength = cfg.ShakeStrength * (1 - distance / cfg.ShakeDistance * 0.6)
	shakeStrength = math.max(strength, if os.clock() < shakeUntil then shakeStrength else 0)
	shakeUntil = os.clock() + cfg.ShakeTime
end

-- Runs right after the camera scripts have placed the camera this frame, so we just nudge it.
local function updateShake()
	local now = os.clock()
	local camera = workspace.CurrentCamera
	if now >= shakeUntil or not camera then
		return
	end
	local amount = shakeStrength * (shakeUntil - now) / cfg.ShakeTime
	camera.CFrame *= CFrame.new(
		random:NextNumber(-amount, amount),
		random:NextNumber(-amount, amount),
		random:NextNumber(-amount, amount) * 0.5
	)
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
			shakeCamera(distance)
		end
	end)
end

---------------------------------------------------------------------------

local function onTreeHit(target: unknown, position: unknown, outward: unknown, falling: unknown)
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Model") then
		return
	end
	if typeof(position) ~= "Vector3" or typeof(outward) ~= "Vector3" then
		return
	end
	local tree = target :: Model
	local trunk = getTrunk(tree)
	if not trunk or distanceTo(position) > cfg.EffectsDistance then
		return
	end

	spawnChips(position, outward, trunk.Color)
	if typeof(falling) == "Vector3" then
		onTreeFalling(tree, trunk, falling)
	else
		wobble(tree, trunk, outward)
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
end

return ChopEffectsController
