--!strict
-- The tool stumps in the Tool Shed, one per tool: a tree stump with a lantern hanging over it from a
-- post, and the tool floating above it, turning slowly (tagged Spinner, so every player's computer
-- turns it, see Client/SpinnerController). A plate on the stump's front has the tool's name and price.
-- The stump comes from Claude Design (design-system/src/models/ToolStump.tsx, models/ToolStump.gltf).
-- Until it's imported into Studio, plain parts stand in, in the same places.
-- Which tool goes where is Config.Shop.Displays. Only for looks: ShopManager puts the "Buy" prompts on
-- the plates. It's not a system, so it has no init()/start().

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Types = require(ReplicatedStorage.Shared.Types)
local Assets = require(script.Parent.Assets)
local Blocky = require(script.Parent.Blocky)
local Props = require(script.Parent.Props)

local WALL = 1 -- the shed's walls are this thick (see Build/ToolShed)
local PLATE_COLOR = Color3.fromRGB(55, 36, 22)

local cfg = Config.Shop.ToolStump

local ShedDisplays = {}

-- Only for looks: nothing bumps into these parts, and clicks and raycasts go through them.
local function settle(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- A spot on `wall`: on the inside of the wall, at ground level, `along` studs from the wall's middle.
-- Its +Z points out of the wall, into the room.
function ShedDisplays.wallFrame(origin: CFrame, wall: string, along: number): CFrame
	local size = Config.Shop.BuildingSize
	if wall == "Left" then
		return origin * CFrame.new(-size.X / 2 + WALL, 0, along) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return origin * CFrame.new(along, 0, -size.Z / 2 + WALL)
end

-- The plate on the stump's front: the tool's name, then a coin and its price. The price is called
-- "Price", so each player's computer can write OWNED on it (see Client/ShopController).
local function addPlate(spot: CFrame, scale: number, item: Types.ShopItem, parent: Instance): Part
	local style = Config.Style
	local height = cfg.PlateSize.Y * scale
	local frame = spot * CFrame.new(cfg.PlateSpot * scale) * CFrame.Angles(math.rad(-cfg.PlateLean), 0, 0)
	local plate = Blocky.part("PricePlate", Vector3.new(cfg.PlateSize.X * scale, height, 0.2), frame, PLATE_COLOR, Enum.Material.Wood, parent)
	settle(plate)
	local gui = Blocky.face(plate, Enum.NormalId.Back) -- the face pointing into the room
	gui.PixelsPerStud = cfg.PlateSharpness
	local border = Blocky.rect(gui, 0, 0, 1, 1, PLATE_COLOR)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = style.DarkWood
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = border

	local nameBox = Blocky.rect(border, 0.06, 0.07, 0.88, 0.4, PLATE_COLOR)
	nameBox.BackgroundTransparency = 1
	Blocky.label(nameBox, item.Name:upper(), style.TitleFont, style.Cream)

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.Position = UDim2.fromScale(0, 0.5)
	row.Size = UDim2.fromScale(1, 0.46)
	row.BackgroundTransparency = 1
	row.Parent = border
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row

	local pixels = height * gui.PixelsPerStud * 0.46
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.Size = UDim2.fromOffset(pixels * 0.66, pixels * 0.66)
	coin.BackgroundColor3 = style.Gold
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = coin
	local coinStroke = Instance.new("UIStroke")
	coinStroke.Thickness = 3
	coinStroke.Color = Color3.new(0, 0, 0)
	coinStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	coinStroke.Parent = coin
	coin.Parent = row

	local label = Blocky.label(row, Format.number(Shop.priceOf(item, 0) or 0), style.TitleFont, style.Gold)
	label.Name = "Price"
	label.TextScaled = false
	label.TextSize = pixels * 0.82
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, pixels * 0.9)
	return plate
end

-- The Claude Design model, if it's imported.
local function addStumpModel(spot: CFrame, scale: number, parent: Instance): boolean
	local skin = Assets.gltf(parent, cfg.Model, spot, scale)
	if not skin then
		return false
	end
	for _, part in skin:GetChildren() do
		if part:IsA("BasePart") then
			local look = cfg.Looks[part.Name]
			if look then
				part.Color = look.Color
				part.Material = look.Material
			end
			settle(part)
		end
	end
	return true
end

-- The plain parts that stand in until the model is imported.
local function addStumpParts(spot: CFrame, scale: number, parent: Instance)
	local function add(name: string, size: Vector3, position: Vector3, turn: CFrame?): Part
		local look = cfg.Looks[name]
		local frame = spot * CFrame.new(position * scale) * (turn or CFrame.identity)
		local part = Blocky.part(name, size * scale, frame, look.Color, look.Material, parent)
		settle(part)
		return part
	end
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is its X: point it up
	add("Trunk", Vector3.new(3.4, 5.6, 5.6), Vector3.new(0, 1.7, 0), upright).Shape = Enum.PartType.Cylinder
	add("Rings", Vector3.new(0.12, 4.8, 4.8), Vector3.new(0, 3.45, 0), upright).Shape = Enum.PartType.Cylinder
	add("RingLines", Vector3.new(0.12, 3, 3), Vector3.new(0, 3.48, 0), upright).Shape = Enum.PartType.Cylinder
	for _, angle in { 40, 110, 180, 250, 320 } do
		local turn = CFrame.Angles(0, math.rad(angle), 0)
		add("Root", Vector3.new(1.4, 0.8, 2.4), (turn * CFrame.new(0, 0.4, 3.2)).Position, turn)
	end
	add("Moss", Vector3.new(1.6, 0.26, 1.1), Vector3.new(-1.5, 3.5, 1), CFrame.Angles(0, math.rad(28), 0))
	add("Post", Vector3.new(0.9, cfg.PostSize.Y, 0.9), cfg.PostSpot + Vector3.new(0, cfg.PostSize.Y / 2, 0))
	add("Arm", Vector3.new(0.6, 0.6, 3.95), Vector3.new(0, 12.75, -1.5))
	add("Chain", Vector3.new(0.2, 0.7, 0.2), Vector3.new(0, 12.1, 0))
	add("Iron", Vector3.new(1.2, 0.4, 1.2), Vector3.new(0, 11.6, 0))
	add("Iron", Vector3.new(1.1, 0.2, 1.1), Vector3.new(0, 10, 0))
	add("Lamp", Vector3.new(0.82, 1.3, 0.82), Vector3.new(0, 10.8, 0))
end

-- The invisible blocks you bump into: the stump, and the post behind it.
local function addColliders(spot: CFrame, scale: number, parent: Instance)
	local boxes = {
		{ Size = cfg.ColliderSize, Spot = Vector3.new(0, cfg.ColliderSize.Y / 2, 0) },
		{ Size = cfg.PostSize, Spot = cfg.PostSpot + Vector3.new(0, cfg.PostSize.Y / 2, 0) },
	}
	for _, box in boxes do
		local solid = Blocky.part("Collider", box.Size * scale, spot * CFrame.new(box.Spot * scale), Color3.new(), Enum.Material.SmoothPlastic, parent)
		Blocky.collider(solid)
		solid.CanTouch = false
	end
end

-- The lantern's light, which flickers a little (see AmbientController).
local function addLight(parent: Instance, scale: number)
	local lamp = parent:FindFirstChild("Lamp", true)
	if not (lamp and lamp:IsA("BasePart")) then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = cfg.Looks.Lamp.Color
	light.Range = cfg.LightRange * scale
	light.Brightness = cfg.LightBrightness
	light.Parent = lamp
	Props.flicker(light)
end

-- How far a tool reaches out from the upright line through `middle`, and how tall it is.
local function toolReach(display: Model, middle: Vector3): (number, number)
	local radius, low, high = 0, math.huge, -math.huge
	for _, part in display:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, x in { 1, -1 } do
				for _, y in { 1, -1 } do
					for _, z in { 1, -1 } do
						local point = part.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z))
						radius = math.max(radius, Vector2.new(point.X - middle.X, point.Z - middle.Z).Magnitude)
						low = math.min(low, point.Y)
						high = math.max(high, point.Y)
					end
				end
			end
		end
	end
	return radius, high - low
end

-- The tool, floating above the stump and leaning `tilt` degrees. It's as big as Config says, or
-- smaller if it wouldn't fit under the lantern or would hit the post as it turns.
local function addFloatingTool(spot: CFrame, scale: number, big: boolean, item: Types.ShopItem, tilt: number, makeDisplay: (toolId: string) -> Model, parent: Instance)
	local middle = (spot * CFrame.new(0, cfg.ToolMiddle * scale, 0)).Position
	local display = makeDisplay(item.Id)
	-- Its pivot is the handle, so move it until the middle of the whole tool is on `middle`.
	local function centre()
		local box = display:GetBoundingBox()
		display:PivotTo(display:GetPivot() + (middle - box.Position))
	end
	display:PivotTo(CFrame.new(middle) * spot.Rotation * CFrame.Angles(0, 0, math.rad(-tilt)) * CFrame.Angles(math.pi / 2, 0, 0))
	display:ScaleTo(if big then cfg.BigToolScale else cfg.ToolScale)
	centre()
	local radius, height = toolReach(display, middle)
	local shrink = math.min(1, cfg.ToolRoom.X * scale / (radius * 2), cfg.ToolRoom.Y * scale / height)
	if shrink < 1 then
		display:ScaleTo(display:GetScale() * shrink)
		centre()
	end
	for _, part in display:GetDescendants() do
		if part:IsA("BasePart") then
			settle(part)
		end
	end

	-- It turns around the hub's X axis, which points up.
	local spinner = Instance.new("Model")
	spinner.Name = "FloatingTool"
	local hub = Blocky.part("Hub", Vector3.new(0.2, 0.2, 0.2), CFrame.new(middle) * CFrame.Angles(0, 0, math.pi / 2), Color3.new(), Enum.Material.SmoothPlastic, spinner)
	hub.Transparency = 1
	settle(hub)
	display.Parent = spinner
	spinner.PrimaryPart = hub
	spinner.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- see Client/SpinnerController
	spinner:SetAttribute("SpinSpeed", cfg.ToolSpin)
	spinner:SetAttribute("Bob", cfg.ToolBob)
	spinner.Parent = parent
	CollectionService:AddTag(spinner, Tags.Spinner)
end

-- Builds every stump in Config.Shop.Displays into `parent`, for the shed whose floor plan's middle
-- (at ground level) is `origin` and whose floor is `floorTop` above the ground.
-- Returns the plates by item Id.
function ShedDisplays.build(origin: CFrame, floorTop: number, makeDisplay: (toolId: string) -> Model, parent: Model): { [string]: BasePart }
	local plates: { [string]: BasePart } = {}
	for _, spot in Config.Shop.Displays do
		local item = Shop.getItem(spot.Item)
		if not item then
			warn(`[ShedDisplays] Config.Shop.Displays has "{spot.Item}", which isn't in Shared/Shop`)
			continue
		end
		local group = Instance.new("Model")
		group.Name = `Display_{item.Id}`
		group.Parent = parent
		local big = spot.Big == true
		local scale = if big then cfg.BigScale else 1
		local stump = ShedDisplays.wallFrame(origin, spot.Wall, spot.Along) * CFrame.new(0, floorTop, cfg.WallGap * scale)
		if not addStumpModel(stump, scale, group) then
			addStumpParts(stump, scale, group)
		end
		addColliders(stump, scale, group)
		addLight(group, scale)
		addFloatingTool(stump, scale, big, item, spot.Tilt, makeDisplay, group)
		plates[item.Id] = addPlate(stump, scale, item, group)
	end
	return plates
end

return ShedDisplays
