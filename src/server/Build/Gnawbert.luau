--!strict
-- Gnawbert, the game's mascot: a chained stump mimic that eats your logs at the sawmills. The whole
-- top of the stump is its lid, which lifts on a hinge at the back. It's made of three groups:
--   * Body: everything that stays still, with an invisible block to bump into
--   * Lid: the lid, tagged GnawbertLid, with a hinge part as its main part
--   * Pupils (inside Lid): they also shift a little on their own, to watch you
-- Every player's computer moves the lid and the pupils (see Client/Controllers/SellYardController).
-- The model comes from Claude Design (design-system/src/models/Gnawbert.tsx, models/Gnawbert.gltf).
-- Until it's imported into Studio, plain parts stand in, in the same places and with the same names.
-- Colours are in Config.Sawmill.Gnawbert.Looks. Zones 2 and 3 get a darker, more worn Gnawbert.
-- It's not a system, so it has no init()/start().

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Assets = require(script.Parent.Assets)
local Blocky = require(script.Parent.Blocky)

local cfg = Config.Sawmill.Gnawbert

local Gnawbert = {}

-- Set at the start of build(): where it stands (+Z is its front), and how worn it is.
local origin: CFrame
local wear = 0

local function lookColor(name: string): Color3
	local look = cfg.Looks[name]
	return if cfg.Wears[name] then Blocky.shade(look.Color, -wear) else look.Color
end

-- Only for looks: nothing bumps into these parts, and clicks and raycasts go through them.
local function settle(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

---------------------------------------------------------------------------
-- The plain parts version
---------------------------------------------------------------------------

local function add(name: string, size: Vector3, frame: CFrame, parent: Instance): Part
	local part = Blocky.part(name, size, origin * frame, lookColor(name), cfg.Looks[name].Material, parent)
	settle(part)
	return part
end

-- A tooth seen from the front: a wedge turned sideways. `y` is its root.
local function addTooth(name: string, x: number, y: number, z: number, width: number, length: number, down: boolean, parent: Instance)
	local middle = CFrame.new(x, if down then y - length / 2 else y + length / 2, z)
	local turn = if down then CFrame.Angles(0, 0, math.pi) * CFrame.Angles(0, math.pi / 2, 0) else CFrame.Angles(0, math.pi / 2, 0)
	local tooth = Blocky.wedge(name, Vector3.new(0.6, length, width), origin * middle * turn, lookColor(name), cfg.Looks[name].Material, parent)
	settle(tooth)
end

-- A flat round eye on the lid's front, its round face looking out along +Z.
local function addEye(x: number, y: number, radius: number, parent: Instance)
	local eye = add("Eye", Vector3.new(0.4, radius * 2, radius * 2), CFrame.new(x, y, 3.7) * CFrame.Angles(0, math.pi / 2, 0), parent)
	eye.Shape = Enum.PartType.Cylinder
	add("LidGum", Vector3.new(radius * 2.5, radius * 2.5, 0.1), CFrame.new(x, y, 3.62), parent)
end

local function buildBodyParts(body: Instance)
	add("Trunk", Vector3.new(8.2, 4.4, 7.4), CFrame.new(0, 2.2, 0), body)
	for _, x in { -3, 3 } do
		for _, z in { -1, 1 } do
			add("Ridge", Vector3.new(0.6, 3.4, 0.2), CFrame.new(x, 1.9, z * 3.75), body)
			add("Ridge", Vector3.new(0.2, 3.4, 0.6), CFrame.new(x * 1.38, 1.9, z * 2.6), body)
		end
	end
	for _, angle in { 45, 135, 225, 315 } do
		local turn = CFrame.Angles(0, math.rad(angle), 0)
		local root = Blocky.wedge(
			"Root",
			Vector3.new(1.9, 2, 3.2),
			origin * turn * CFrame.new(0, 1, 5.6) * CFrame.Angles(0, math.pi, 0),
			lookColor("Root"),
			cfg.Looks.Root.Material,
			body
		)
		settle(root)
	end
	add("Gum", Vector3.new(6.8, 0.1, 6), CFrame.new(0, 4.42, 0), body)
	add("Throat", Vector3.new(5.8, 2.6, 1.9), CFrame.new(0, 5.7, -2.1), body)
	add("Tongue", Vector3.new(2.8, 0.4, 4.2), CFrame.new(0.2, 4.65, 0.7), body)
	add("Tongue", Vector3.new(1.2, 1, 0.3), CFrame.new(1.6, 4, 3.5), body)
	for index, x in { -3, -1.8, -0.6, 0.6, 2.9 } do
		addTooth("Teeth", x, 4.4, 2.9, 1, if index % 2 == 0 then 1.3 else 1, false, body)
	end
	add("Collar", Vector3.new(8.8, 0.9, 0.3), CFrame.new(0, 2.35, 3.85), body)
	add("Collar", Vector3.new(8.8, 0.9, 0.3), CFrame.new(0, 2.35, -3.85), body)
	add("Collar", Vector3.new(0.3, 0.9, 7.9), CFrame.new(4.25, 2.35, 0), body)
	add("Collar", Vector3.new(0.3, 0.9, 7.9), CFrame.new(-4.25, 2.35, 0), body)
	add("Tag", Vector3.new(1, 1.1, 0.12), CFrame.new(-2.1, 1.2, 3.9), body)
	-- The chain sags from the collar to a post, with its links turned against each other.
	local from, to = Vector3.new(-4.6, 2.3, 0.6), Vector3.new(-8.1, 2.5, 1.2)
	local links = 6
	for index = 1, links do
		local t = (index - 0.5) / links
		local point = from:Lerp(to, t) - Vector3.yAxis * (4 * 1.05 * t * (1 - t))
		local long = (to - from).Magnitude / links + 0.1
		local size = if index % 2 == 0 then Vector3.new(0.24, 0.5, long) else Vector3.new(0.5, 0.24, long)
		add("Chain", size, CFrame.lookAt(point, point + (to - from)), body)
	end
	add("Trunk", Vector3.new(1.1, 3.6, 1.1), CFrame.new(-8.75, 1.8, 1.25), body)
	add("Collar", Vector3.new(1.2, 0.34, 1.2), CFrame.new(-8.75, 2.55, 1.25), body)
	add("Root", Vector3.new(2.6, 0.4, 2.6), CFrame.new(-8.75, 0.2, 1.25), body)
end

local function buildLidParts(lid: Instance, pupils: Instance)
	add("Lid", Vector3.new(8, 4.2, 7.2), CFrame.new(0, 6.7, 0), lid)
	add("LidGum", Vector3.new(7.2, 0.1, 6.5), CFrame.new(0, 4.57, 0.1), lid)
	for _, x in { -2.9, 2.9 } do
		add("LidRidge", Vector3.new(0.6, 3.6, 0.2), CFrame.new(x, 6.6, -3.65), lid)
		add("LidRidge", Vector3.new(0.2, 3.6, 0.6), CFrame.new(x * 1.42, 6.6, 1.4), lid)
		add("LidRidge", Vector3.new(0.2, 3.6, 0.6), CFrame.new(x * 1.42, 6.6, -1.4), lid)
	end
	add("Rings", Vector3.new(6, 0.12, 5.4), CFrame.new(0, 8.84, 0), lid)
	add("Moss", Vector3.new(2.6, 0.28, 2.3), CFrame.new(-1.6, 8.95, -1.4) * CFrame.Angles(0, math.rad(14), 0), lid)
	add("LidRidge", Vector3.new(0.7, 2.4, 0.7), CFrame.new(2.6, 9.9, 1.3) * CFrame.Angles(0, 0, math.rad(-20)), lid)
	add("Moss", Vector3.new(0.9, 0.3, 0.7), CFrame.new(3.1, 11.1, 1.3), lid)
	add("LidRidge", Vector3.new(2.9, 0.66, 0.8), CFrame.new(-1.75, 8.35, 3.75) * CFrame.Angles(0, 0, math.rad(-15)), lid)
	add("LidRidge", Vector3.new(2.3, 0.58, 0.8), CFrame.new(1.9, 8.3, 3.75) * CFrame.Angles(0, 0, math.rad(19)), lid)
	for index, x in { -3.4, -2.38, -1.3, -0.18, 2.1, 3.3 } do
		local big = index == 2 or index == 5
		addTooth("Fangs", x, 4.6, 3.3, if big then 1.2 else 0.98, if big then 1.9 else 1.05, true, lid)
	end
	addEye(-1.75, 7.1, 1.1, lid)
	addEye(1.85, 7, 0.86, lid)
	for _, eye in { { X = -1.75, Y = 7.1, Size = 1.1 }, { X = 1.85, Y = 7, Size = 0.86 } } do
		add("Pupil", Vector3.new(eye.Size * 0.62, eye.Size * 1.02, 0.12), CFrame.new(eye.X, eye.Y, 3.95), pupils)
		add("Glint", Vector3.new(eye.Size * 0.2, eye.Size * 0.24, 0.06), CFrame.new(eye.X - eye.Size * 0.12, eye.Y + eye.Size * 0.26, 4.03), pupils)
	end
end

---------------------------------------------------------------------------

-- The Claude Design model, sorted into the three groups. False if it isn't imported.
local function buildFromModel(body: Instance, lid: Instance, pupils: Instance): boolean
	local skin = Assets.gltf(body, cfg.Model, origin)
	if not skin then
		return false
	end
	for _, part in skin:GetChildren() do
		if part:IsA("BasePart") then
			local look = cfg.Looks[part.Name]
			if look then
				part.Color = lookColor(part.Name)
				part.Material = look.Material
			end
			settle(part)
			part.Parent = if cfg.PupilParts[part.Name] then pupils elseif cfg.LidParts[part.Name] then lid else body
		end
	end
	skin:Destroy()
	return true
end

-- Builds Gnawbert standing at `frame` (a spot on the ground, with its front along the frame's +Z)
-- into `parent`. `worn` (0 to 1) makes it darker. Returns the spot in its mouth where logs disappear.
function Gnawbert.build(frame: CFrame, worn: number, parent: Instance): Vector3
	origin = frame
	wear = worn

	local model = Instance.new("Model")
	model.Name = "Gnawbert"
	local body = Instance.new("Model")
	body.Name = "Body"
	body.Parent = model
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	local pupils = Instance.new("Model")
	pupils.Name = "Pupils"

	if not buildFromModel(body, lid, pupils) then
		buildBodyParts(body)
		buildLidParts(lid, pupils)
	end

	local solid = Blocky.part("Collider", cfg.ColliderSize, origin * CFrame.new(0, cfg.ColliderSize.Y / 2, 0), Color3.new(), Enum.Material.SmoothPlastic, body)
	Blocky.collider(solid)
	solid.CanTouch = false

	-- The lid and the pupils turn around their main parts on every player's computer. The hinge is
	-- invisible and lines up with the lid's frame, so "lifting" is one turn around its X axis.
	local hinge = Blocky.part("Hinge", Vector3.new(0.2, 0.2, 0.2), origin * CFrame.new(cfg.Hinge), Color3.new(), Enum.Material.SmoothPlastic, lid)
	hinge.Transparency = 1
	settle(hinge)
	lid.PrimaryPart = hinge
	pupils.PrimaryPart = pupils:FindFirstChild("Pupil") :: BasePart?
	pupils.Parent = lid

	local mouth = (origin * CFrame.new(cfg.Mouth)).Position
	lid:SetAttribute("Mouth", mouth)
	lid.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- it arrives whole, see SellYardController
	CollectionService:AddTag(lid, Tags.GnawbertLid)
	lid.Parent = model
	model.Parent = parent
	return mouth
end

return Gnawbert
