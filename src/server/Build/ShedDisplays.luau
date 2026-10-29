--!strict
-- The framed boards on the Tool Shed's walls, one per tool (like the shop in Chop a Forest):
-- a wooden name sign on top, the tool itself in the middle and a big price plate under it,
-- readable from across the room. The best tool gets the big board on dark planks with gold
-- sunburst rays slowly turning behind it (tagged Spinner, so every player's computer turns
-- it, see Client/SpinnerController). Which tool goes where is Config.Shop.Displays.
-- Only for looks: ShopManager puts the "Buy" prompts on the price plates.
-- It's not a system, so it has no init()/start().

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Types = require(ReplicatedStorage.Shared.Types)
local Blocky = require(script.Parent.Blocky)

local WALL = 1 -- the shed's walls are this thick (see Build/ToolShed)
local FRAME = 0.6 -- how thick the dark frame around a board is
local PLATE_COLOR = Color3.fromRGB(55, 36, 22)

local ShedDisplays = {}

local function decor(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local part = Blocky.part(name, size, cframe, color, material, parent)
	part.CanCollide = false
	return part
end

-- Where a board on `wall` hangs: on the inside of the wall, at floor level, `along` studs from
-- the wall's middle. Its +Z points out of the wall, into the room.
local function wallFrame(origin: CFrame, wall: string, along: number): CFrame
	local size = Config.Shop.BuildingSize
	if wall == "Left" then
		return origin * CFrame.new(-size.X / 2 + WALL, 0, along) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return origin * CFrame.new(along, 0, -size.Z / 2 + WALL)
end

-- The price plate: a coin and the price in gold, big. The text is called "Price", so each
-- player's computer can write OWNED on it (see Client/ShopController).
local function pricePlate(cframe: CFrame, width: number, height: number, price: number, parent: Instance): Part
	local plate = decor("PricePlate", Vector3.new(width, height, 0.3), cframe, PLATE_COLOR, Enum.Material.Wood, parent)
	local gui = Blocky.face(plate, Enum.NormalId.Back) -- the face pointing into the room
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Config.Style.DarkWood
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local border = Blocky.rect(gui, 0, 0, 1, 1, PLATE_COLOR)
	stroke.Parent = border

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundTransparency = 1
	row.Parent = border
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row

	local pixels = height * gui.PixelsPerStud
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.Size = UDim2.fromOffset(pixels * 0.6, pixels * 0.6)
	coin.BackgroundColor3 = Config.Style.Gold
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = coin
	local coinStroke = Instance.new("UIStroke")
	coinStroke.Thickness = 3
	coinStroke.Color = Color3.new(0, 0, 0)
	coinStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	coinStroke.Parent = coin
	coin.Parent = row

	local label = Blocky.label(row, Format.number(price), Config.Style.TitleFont, Config.Style.Gold)
	label.Name = "Price"
	label.TextScaled = false
	label.TextSize = pixels * 0.72
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, pixels * 0.8)
	return plate
end

-- Gold rays around a hub, behind the tool on the big board. They turn around the hub's X axis,
-- which points out of the board.
local function sunburst(center: CFrame, radius: number, parent: Instance)
	local cfg = Config.Shop
	local gold = Config.Style.Gold
	local burst = Instance.new("Model")
	burst.Name = "Sunburst"
	local hubFrame = center * CFrame.Angles(0, -math.pi / 2, 0)
	local hub = decor("Hub", Vector3.new(0.2, 1.8, 1.8), hubFrame, gold, Enum.Material.SmoothPlastic, burst)
	hub.Shape = Enum.PartType.Cylinder
	local step = 2 * math.pi / cfg.SunburstRays
	local length = radius - 0.9
	for index = 1, cfg.SunburstRays do
		local wide = index % 2 == 0
		local ray = decor(
			"Ray",
			Vector3.new(0.1, length, if wide then 0.9 else 0.5),
			hubFrame * CFrame.Angles(index * step, 0, 0) * CFrame.new(0, 0.9 + length / 2, 0),
			if wide then gold else Blocky.shade(gold, 0.35),
			Enum.Material.SmoothPlastic,
			burst
		)
		ray.CastShadow = false
	end
	burst.PrimaryPart = hub
	burst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- see Client/SpinnerController
	burst:SetAttribute("SpinSpeed", cfg.SunburstSpeed)
	burst.Parent = parent
	CollectionService:AddTag(burst, Tags.Spinner)
end

-- How wide (X) and tall (Y) a model is, seen from the front of a board at `frame`.
local function extents(display: Model, frame: CFrame): Vector2
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in display:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, corner in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1) } do
				for _, sign in { 1, -1 } do
					local point = frame:PointToObjectSpace(part.CFrame:PointToWorldSpace(half * corner * sign))
					low = low:Min(point)
					high = high:Max(point)
				end
			end
		end
	end
	return Vector2.new(high.X - low.X, high.Y - low.Y)
end

-- One framed board on the wall at `frame`, for `item`. Returns its price plate.
local function board(
	frame: CFrame,
	floorTop: number,
	item: Types.ShopItem,
	tilt: number,
	big: boolean,
	makeDisplay: (toolId: string) -> Model,
	parent: Model
): Part
	local cfg = Config.Shop
	local style = Config.Style
	local size = if big then cfg.BigBoardSize else cfg.BoardSize
	local w, h = size.X, size.Y
	local middle = floorTop + cfg.BoardHeight + (if big then 0.6 else 0)
	local top, bottom = middle + h / 2, middle - h / 2

	local backing = decor(
		"Board",
		Vector3.new(w, h, 0.3),
		frame * CFrame.new(0, middle, 0.15),
		if big then Blocky.shade(style.DarkWood, -0.25) else style.Wood,
		Enum.Material.WoodPlanks,
		parent
	)
	if big then
		Blocky.logLines(backing, { Enum.NormalId.Back }) -- dark lines between the planks
	end
	for _, side in { -1, 1 } do
		decor("Frame", Vector3.new(w + FRAME * 2, FRAME, FRAME), frame * CFrame.new(0, middle + side * (h / 2 + FRAME / 2), 0.3), style.DarkWood, Enum.Material.Wood, parent)
		decor("Frame", Vector3.new(FRAME, h, FRAME), frame * CFrame.new(side * (w / 2 + FRAME / 2), middle, 0.3), style.DarkWood, Enum.Material.Wood, parent)
	end

	local signHeight = if big then 2.6 else 2
	Blocky.sign(item.Name:upper(), frame * CFrame.new(0, top + FRAME + signHeight / 2, 0.35), w * 0.8, signHeight, nil, parent)

	local plateHeight = if big then 2.6 else 2.2
	local plate = pricePlate(
		frame * CFrame.new(0, bottom + plateHeight / 2 + 0.5, 0.45),
		w * 0.7,
		plateHeight,
		Shop.priceOf(item, 0) or 0,
		parent
	)

	-- The tool, standing up and leaning `tilt` degrees, in the space above the plate.
	local toolY = (top + bottom + plateHeight + 0.5) / 2
	local toolCenter = frame * CFrame.new(0, toolY, 0)
	if big then
		sunburst(toolCenter * CFrame.new(0, 0, 0.4), math.min(w, h) / 2 - 0.4, parent)
	end
	local display = makeDisplay(item.Id)
	display:PivotTo(toolCenter * CFrame.new(0, 0, 1) * CFrame.Angles(0, 0, math.rad(-tilt)) * CFrame.Angles(math.pi / 2, 0, 0))
	display:ScaleTo(if big then cfg.BigToolScale else cfg.ToolScale)
	-- A long tool leaning over might not fit between the frame and the plate: then make it smaller.
	local room = Vector2.new(w - 1.2, top - (bottom + plateHeight + 0.5) - 0.6)
	local reach = extents(display, toolCenter)
	local shrink = math.min(1, room.X / reach.X, room.Y / reach.Y)
	if shrink < 1 then
		display:ScaleTo(display:GetScale() * shrink)
	end
	-- Its pivot is the handle, so move it until the middle of the whole tool is on the board's middle.
	local boxFrame = display:GetBoundingBox()
	local target = toolCenter * CFrame.new(0, 0, 1)
	display:PivotTo(display:GetPivot() + (target.Position - boxFrame.Position))
	display.Parent = parent
	return plate
end

-- Builds every board in Config.Shop.Displays into `parent`, for the shed whose floor plan's
-- middle (at ground level) is `origin` and whose floor is `floorTop` above the ground.
-- Returns the price plates by item Id.
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
		plates[item.Id] = board(wallFrame(origin, spot.Wall, spot.Along), floorTop, item, spot.Tilt, spot.Big == true, makeDisplay, group)
	end
	return plates
end

return ShedDisplays
