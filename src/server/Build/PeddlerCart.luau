--!strict
-- The peddler's cart beside a sawmill's sell pad: a hand cart with a striped canvas roof, a hanging
-- sign and goods on it (a fat sack, two stacks of coins, crates). Its side that sells faces the pad.
-- Its "Open shop" prompt opens the SHOP menu (PerkManager puts it on, Client/MenusController opens it).
-- The model comes from Claude Design (design-system/src/models/PeddlerCart.tsx, models/PeddlerCart.gltf).
-- Until it's imported into Studio, plain parts stand in, in the same places. Colours are in
-- Config.Perks.Cart.Looks. Zones 2 and 3 get a darker, more worn cart.
-- It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Assets = require(script.Parent.Assets)
local Blocky = require(script.Parent.Blocky)
local Props = require(script.Parent.Props)

local cfg = Config.Perks.Cart

local PeddlerCart = {}

-- Set at the start of build(): where it stands (+Z is the side that sells), how worn it is, and the
-- Model its parts go in.
local origin: CFrame
local wear = 0
local cart: Model

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

local function add(name: string, size: Vector3, frame: CFrame): Part
	local part = Blocky.part(name, size, origin * frame, lookColor(name), cfg.Looks[name].Material, cart)
	settle(part)
	return part
end

local function addRound(name: string, width: number, diameter: number, frame: CFrame): Part
	local part = add(name, Vector3.new(width, diameter, diameter), frame)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function buildWheels()
	local facingOut = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder's axis is its X: point it along Z
	for _, z in { -2.95, 2.95 } do
		addRound("Rim", 0.42, 4.4, CFrame.new(0, 2.2, z) * facingOut)
		addRound("Spoke", 0.5, 3.4, CFrame.new(0, 2.2, z) * facingOut)
		addRound("Hub", 0.74, 1, CFrame.new(0, 2.2, z) * facingOut)
	end
	add("Hub", Vector3.new(0.34, 0.34, 5.9), CFrame.new(0, 2.2, 0))
end

local function buildBody()
	add("Deck", Vector3.new(9.4, 0.34, 4.8), CFrame.new(0, 2.23, 0))
	add("Board", Vector3.new(9.2, 1.1, 0.2), CFrame.new(0, 2.85, 2.3))
	add("Board", Vector3.new(9.2, 2.8, 0.2), CFrame.new(0, 3.7, -2.3))
	for _, side in { -1, 1 } do
		add("Board", Vector3.new(0.2, 1.6, 4.6), CFrame.new(side * 4.6, 3.1, 0))
		add("Post", Vector3.new(0.46, 5.9, 0.46), CFrame.new(side * 4.6, 4.85, 2.3))
		add("Post", Vector3.new(0.46, 7.4, 0.46), CFrame.new(side * 4.6, 5.6, -2.3))
		add("Shaft", Vector3.new(3.9, 0.32, 0.34), CFrame.new(-6.3, 1.65, side * 1.55) * CFrame.Angles(0, 0, math.rad(17)))
		add("Leg", Vector3.new(0.46, 2.2, 0.46), CFrame.new(3.85, 1.1, side * 1.6))
	end
	add("Post", Vector3.new(9.8, 0.36, 0.36), CFrame.new(0, 7.5, 2.3))
	add("Post", Vector3.new(9.8, 0.36, 0.36), CFrame.new(0, 9, -2.3))
	add("Shaft", Vector3.new(0.3, 0.3, 3.6), CFrame.new(-7.9, 1.2, 0))
	addRound("Log", 3.9, 0.96, CFrame.new(-7.2, 0.46, 0) * CFrame.Angles(0, math.pi / 2, 0))
end

-- The striped roof slopes down to the front, with a flap hanging off each stripe.
local function buildRoof()
	local stripes = 9
	local width = 10.4 / stripes
	local slope = CFrame.new(0, 8.375, 0.5) * CFrame.Angles(math.rad(19.1), 0, 0)
	for index = 1, stripes do
		local x = -5.2 + (index - 0.5) * width
		local name = if index % 2 == 1 then "Canvas" else "CanvasLight"
		add(name, Vector3.new(width, 0.14, 6.88), CFrame.new(x, 0, 0) * slope)
		add(name, Vector3.new(width, 0.7, 0.14), CFrame.new(x, 6.95, 3.75))
	end
end

local function buildGoods()
	add("Sack", Vector3.new(2.5, 2.2, 2.5), CFrame.new(-2.7, 3.5, 0.1))
	add("Rope", Vector3.new(1.2, 0.2, 1.2), CFrame.new(-2.7, 4.7, 0.1))
	add("Sack", Vector3.new(0.9, 0.4, 0.9), CFrame.new(-2.7, 5, 0.1))
	add("Crate", Vector3.new(1.9, 1.9, 1.9), CFrame.new(0.45, 3.35, 0.15))
	add("Crate", Vector3.new(2.4, 2.4, 2.4), CFrame.new(2.95, 3.6, -0.5))
	add("Crate", Vector3.new(1.2, 1.2, 1.2), CFrame.new(3, 5.4, -0.55))
	for _, x in { -0.03, 0.93 } do
		addRound("Coin", 1, 0.84, CFrame.new(x, 4.8, 0.15) * CFrame.Angles(0, 0, math.pi / 2))
	end
	add("Chain", Vector3.new(0.12, 1, 0.12), CFrame.new(-1.6, 7.1, 2.32))
	add("Chain", Vector3.new(0.12, 1, 0.12), CFrame.new(1.6, 7.1, 2.32))
	add("Sign", Vector3.new(cfg.SignSize.X, cfg.SignSize.Y, 0.22), CFrame.new(cfg.SignSpot - Vector3.new(0, 0, 0.12)))
	add("Lamp", Vector3.new(0.82, 1.3, 0.82), CFrame.new(3.55, 6.2, 2.32))
	add("Iron", Vector3.new(1.2, 0.3, 1.2), CFrame.new(3.55, 7, 2.32))
	add("Iron", Vector3.new(1.1, 0.2, 1.1), CFrame.new(3.55, 5.5, 2.32))
	add("Rope", Vector3.new(0.12, 0.62, 0.12), CFrame.new(-3.55, 7.1, 2.32))
	add("Bell", Vector3.new(0.9, 0.86, 0.9), CFrame.new(-3.55, 6.4, 2.32))
end

---------------------------------------------------------------------------

-- The Claude Design model, if it's imported.
local function buildFromModel(): boolean
	local skin = Assets.gltf(cart, cfg.Model, origin)
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
		end
	end
	return true
end

-- The word on the hanging sign, on a see-through board in front of it.
local function addSignWord()
	local board = Blocky.part("SignWord", Vector3.new(cfg.SignSize.X, cfg.SignSize.Y, 0.02), origin * CFrame.new(cfg.SignSpot), Color3.new(), Enum.Material.SmoothPlastic, cart)
	board.Transparency = 1
	settle(board)
	local gui = Blocky.face(board, Enum.NormalId.Back) -- the face pointing the way the cart sells
	gui.PixelsPerStud = cfg.SignSharpness
	local holder = Blocky.rect(gui, 0.08, 0.12, 0.84, 0.76, Color3.new())
	holder.BackgroundTransparency = 1
	Blocky.label(holder, Config.Perks.Text.CartSign, Config.Style.TitleFont, Config.Style.Gold)
end

-- The lantern's light, which flickers a little (see AmbientController).
local function addLight()
	local lamp = cart:FindFirstChild("Lamp", true)
	if not (lamp and lamp:IsA("BasePart")) then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = cfg.Looks.Lamp.Color
	light.Range = cfg.LightRange
	light.Brightness = cfg.LightBrightness
	light.Parent = lamp
	Props.flicker(light)
end

-- Builds the cart beside the sell pad of the sawmill whose floor plan's middle is at `ground`, into
-- `parent`. `worn` (0 to 1) makes it darker. `padZ` is how far out (Z) the pad's middle is and
-- `padRight` its right edge (X). Returns the part that gets the prompt.
function PeddlerCart.build(ground: Vector3, worn: number, padZ: number, padRight: number, parent: Model): BasePart
	origin = CFrame.new(ground + Vector3.new(padRight + cfg.Gap, 0, padZ + cfg.Along)) * CFrame.Angles(0, -math.pi / 2, 0)
	wear = worn
	cart = Instance.new("Model")
	cart.Name = "PeddlerCart"

	if not buildFromModel() then
		buildWheels()
		buildBody()
		buildRoof()
		buildGoods()
	end
	addSignWord()
	addLight()

	local solid = Blocky.part("Collider", cfg.ColliderSize, origin * CFrame.new(0, cfg.ColliderSize.Y / 2, 0), Color3.new(), Enum.Material.SmoothPlastic, cart)
	Blocky.collider(solid)
	solid.CanTouch = false

	local promptSpot = Blocky.part("PromptSpot", Vector3.new(0.2, 0.2, 0.2), origin * CFrame.new(cfg.PromptSpot), Color3.new(), Enum.Material.SmoothPlastic, cart)
	promptSpot.Transparency = 1
	settle(promptSpot)

	cart.Parent = parent
	return promptSpot
end

return PeddlerCart
