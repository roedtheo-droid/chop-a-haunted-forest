--!strict
-- The shop extras on the right of a sawmill's sell pad, like in Chop a Forest:
--   * a stump with a brown backpack on it: the Log Sack upgrade (carry more logs)
--   * a stump with a dark purple bag on it: the Infinite Bag (a Robux game pass), its name in
--     rainbow letters
--   * a wooden board with a big gold "2X" coin and a green BUY! button: 2X COINS (a game pass)
--   * a big blocky beaver with buck teeth next to the SELL LOGS sign (only a decoration for now)
-- Below, +Z is the side facing spawn (the sawmill's open front) and (0, 0, 0) is the middle of
-- the sawmill's floor plan at ground level, like in Build/SellYard.
-- Only for looks: Server/Systems/PerkManager puts the prompts on the stumps and the board.
-- It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Blocky = require(script.Parent.Blocky)

local ROBUX_GREEN = Color3.fromRGB(80, 210, 90)
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local TOOTH = Color3.fromRGB(250, 248, 235)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 50)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 235, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 220, 90)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 100, 255)),
})

local YardShop = {}

export type Spots = {
	Sack: BasePart, -- the Log Sack's stump
	Bag: BasePart, -- the Infinite Bag's stump
	Coins: BasePart, -- the 2X COINS board
}

-- Set at the start of build(): where the sawmill stands, the group the next parts go in, and
-- the wood colour (darker at the worn sawmills).
local origin: CFrame
local model: Model
local yard: Model
local wood: Color3

local function group(name: string)
	model = Instance.new("Model")
	model.Name = name
	model.Parent = yard
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function piece(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return Blocky.part(name, size, origin * cframe, color, material, model)
end

local function decor(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = piece(name, size, cframe, color, material)
	part.CanCollide = false
	return part
end

-- A floating label `height` studs above `part` that always faces you. Returns the box its
-- lines go in (each line is a TextLabel stacked under the last, see line()).
local function floatingLabel(part: BasePart, height: number, lines: number): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(6, 1.1 * lines)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = part
	local box = Instance.new("Frame")
	box.Name = "Lines"
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundTransparency = 1
	box.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = box
	return box
end

-- One line of a floating label: `share` is how much of its height it takes (0 to 1).
local function line(box: Frame, name: string, text: string, share: number, color: Color3?, font: Enum.Font?): TextLabel
	local label = Blocky.label(box, text, font or Config.Style.TitleFont, color)
	label.Name = name
	label.Size = UDim2.fromScale(1, share)
	label.LayoutOrder = #box:GetChildren()
	return label
end

-- A price line with a coin in front: "[coin] 30". The text is called "Price", so each player's
-- computer can show their own next price (see Client/ShopController).
local function coinLine(box: Frame, price: number, share: number)
	local row = Instance.new("Frame")
	row.Name = "PriceRow"
	row.Size = UDim2.fromScale(1, share)
	row.BackgroundTransparency = 1
	row.LayoutOrder = #box:GetChildren()
	row.Parent = box
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.AnchorPoint = Vector2.new(1, 0.5)
	coin.Position = UDim2.fromScale(0.36, 0.5)
	coin.Size = UDim2.fromScale(0.8, 0.8)
	coin.SizeConstraint = Enum.SizeConstraint.RelativeYY
	coin.BackgroundColor3 = Config.Style.Gold
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = coin
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = coin
	coin.Parent = row
	local label = Blocky.label(row, Format.number(price), Config.Style.TitleFont, Config.Style.Gold)
	label.Name = "Price"
	label.Position = UDim2.fromScale(0.4, 0)
	label.Size = UDim2.fromScale(0.5, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
end

-- A stump to put an item on, with its top `height` above the ground.
local function stump(x: number, z: number, height: number): BasePart
	local block = Blocky.block(Config.Models.Stump, "Stump", Vector3.new(2.6, height, 2.6), origin * at(x, height / 2, z), wood, Enum.Material.Wood, model)
	Blocky.rings(block, Enum.NormalId.Top)
	return block
end

-- The Log Sack's stump with a brown backpack on it.
local function buildSackStump(x: number, z: number): BasePart
	group("LogSackStump")
	local cfg = Config.Perks
	local text = cfg.Text
	local top = 2
	local base = stump(x, z, top)
	local turn = at(x, 0, z) * CFrame.Angles(0, math.rad(15), 0)
	local leather = cfg.SackColor
	decor("Backpack", Vector3.new(1.6, 1.8, 1.1), turn * at(0, top + 0.9, 0), leather, Enum.Material.Fabric)
	decor("BackpackFlap", Vector3.new(1.7, 0.6, 1.2), turn * at(0, top + 1.6, 0.05), Blocky.shade(leather, -0.25), Enum.Material.Fabric)
	decor("BackpackPocket", Vector3.new(1.1, 0.7, 0.2), turn * at(0, top + 0.6, 0.6), Blocky.shade(leather, 0.1), Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		decor("BackpackStrap", Vector3.new(0.2, 1.5, 0.15), turn * at(side * 0.45, top + 0.9, -0.62), Blocky.shade(leather, -0.4), Enum.Material.Fabric)
	end
	local item = Shop.getItem("CarryLimit")
	local box = floatingLabel(base, 4.6, 2)
	line(box, "Name", if item then item.Name else text.SackName, 0.5)
	coinLine(box, Config.Upgrades.CarryLimit.Prices[1], 0.5)
	return base
end

-- The Infinite Bag's stump with a dark purple bag on it, and its name in rainbow letters.
local function buildBagStump(x: number, z: number): BasePart
	group("InfiniteBagStump")
	local cfg = Config.Perks
	local text = cfg.Text
	local top = 2
	local base = stump(x, z, top)
	local bag = cfg.BagColor
	decor("Bag", Vector3.new(1.8, 1.7, 1.8), at(x, top + 0.85, z) * CFrame.Angles(0, math.rad(-10), 0), bag, Enum.Material.Fabric)
	decor("BagNeck", Vector3.new(0.9, 0.6, 0.9), at(x, top + 1.95, z), Blocky.shade(bag, -0.2), Enum.Material.Fabric)
	decor("BagTie", Vector3.new(1.05, 0.15, 1.05), at(x, top + 1.8, z), Config.Style.Gold, Enum.Material.SmoothPlastic)
	local box = floatingLabel(base, 4.6, if cfg.InfiniteBag.GamePassId == 0 then 3 else 2)
	local name = line(box, "Name", text.InfiniteBag, 0.4, WHITE)
	local rainbow = Instance.new("UIGradient")
	rainbow.Color = RAINBOW
	rainbow.Parent = name
	line(box, "Robux", string.format(text.Robux, tostring(cfg.InfiniteBag.RobuxPrice)), 0.35, ROBUX_GREEN)
	if cfg.InfiniteBag.GamePassId == 0 then
		line(box, "Soon", text.ComingSoon, 0.25, Config.Style.Cream, Config.Style.BodyFont)
	end
	return base
end

-- The 2X COINS board: a big gold coin with "2X" on it, the price, and a green BUY! button.
local function buildCoinsBoard(x: number, z: number): BasePart
	group("DoubleCoinsBoard")
	local cfg = Config.Perks
	local text = cfg.Text
	local style = Config.Style
	local width, height, boardY = 6.4, 4.4, 3.6
	for _, side in { -1, 1 } do
		piece("BoardPost", Vector3.new(0.5, boardY + height / 2, 0.5), at(x + side * (width / 2 - 0.3), (boardY + height / 2) / 2, z - 0.35), style.DarkWood, Enum.Material.Wood)
	end
	local board = piece("Board", Vector3.new(width, height, 0.4), at(x, boardY, z), style.Wood, Enum.Material.WoodPlanks)
	local gui = Blocky.face(board, Enum.NormalId.Back, style.Wood) -- the side facing spawn (+Z)
	local frame = Blocky.rect(gui, 0, 0, 1, 1, style.Wood)
	local border = Instance.new("UIStroke")
	border.Thickness = 8
	border.Color = style.DarkWood
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = frame

	-- The coin on the left with "2X" on it.
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Position = UDim2.fromScale(0.25, 0.5)
	coin.Size = UDim2.fromScale(0.75, 0.75)
	coin.SizeConstraint = Enum.SizeConstraint.RelativeYY
	coin.BackgroundColor3 = style.Gold
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = coin
	local rim = Instance.new("UIStroke")
	rim.Thickness = 6
	rim.Color = Color3.fromRGB(205, 150, 30)
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = coin
	coin.Parent = frame
	local twoX = Blocky.label(coin, text.TwoX, style.TitleFont)
	twoX.AnchorPoint = Vector2.new(0.5, 0.5)
	twoX.Position = UDim2.fromScale(0.5, 0.5)
	twoX.Size = UDim2.fromScale(0.7, 0.55)

	-- On the right: the name, the price and the button.
	local title = Blocky.label(frame, text.DoubleCoins, style.TitleFont)
	title.Position = UDim2.fromScale(0.48, 0.1)
	title.Size = UDim2.fromScale(0.48, 0.28)
	local price = Blocky.label(frame, string.format(text.Robux, tostring(cfg.DoubleCoins.RobuxPrice)), style.TitleFont, ROBUX_GREEN)
	price.Position = UDim2.fromScale(0.52, 0.4)
	price.Size = UDim2.fromScale(0.4, 0.2)
	local button = Blocky.rect(frame, 0.53, 0.65, 0.38, 0.24, style.Green)
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0.25, 0)
	buttonCorner.Parent = button
	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Thickness = 3
	buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	buttonStroke.Parent = button
	local buy = Blocky.label(button, if cfg.DoubleCoins.GamePassId == 0 then text.ComingSoon else text.Buy, style.TitleFont)
	buy.AnchorPoint = Vector2.new(0.5, 0.5)
	buy.Position = UDim2.fromScale(0.5, 0.5)
	buy.Size = UDim2.fromScale(0.85, 0.7)
	return board
end

-- A big blocky beaver with buck teeth, facing +Z, with a floating "Big Beaver" label.
local function buildBeaver(x: number, z: number)
	group("BigBeaver")
	local cfg = Config.Perks
	local text = cfg.Text
	local fur = cfg.BeaverColor
	local belly = Blocky.shade(fur, 0.35)
	local dark = Blocky.shade(fur, -0.45)
	local spot = at(x, 0, z) * CFrame.Angles(0, math.rad(-20), 0) -- turned a little towards the pad
	for _, side in { -1, 1 } do
		decor("Foot", Vector3.new(1, 0.5, 1.4), spot * at(side * 0.8, 0.25, 0.3), dark, Enum.Material.SmoothPlastic)
	end
	local body = piece("Body", Vector3.new(3, 3.4, 2.6), spot * at(0, 2.2, 0), fur, Enum.Material.SmoothPlastic)
	decor("Belly", Vector3.new(2, 2.4, 0.2), spot * at(0, 2, 1.35), belly, Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		decor("Arm", Vector3.new(0.6, 1.4, 0.7), spot * at(side * 1.2, 2.6, 1.3) * CFrame.Angles(math.rad(30), 0, 0), fur, Enum.Material.SmoothPlastic)
	end
	decor("Tail", Vector3.new(1.8, 0.35, 3), spot * at(0, 0.6, -2.2) * CFrame.Angles(math.rad(-15), 0, 0), dark, Enum.Material.SmoothPlastic)
	decor("Head", Vector3.new(2.4, 2, 2.2), spot * at(0, 4.9, 0.2), fur, Enum.Material.SmoothPlastic)
	decor("Snout", Vector3.new(1.4, 0.9, 0.6), spot * at(0, 4.5, 1.5), belly, Enum.Material.SmoothPlastic)
	decor("Nose", Vector3.new(0.5, 0.35, 0.2), spot * at(0, 4.85, 1.85), BLACK, Enum.Material.SmoothPlastic)
	decor("Teeth", Vector3.new(0.6, 0.55, 0.15), spot * at(0, 3.9, 1.72), TOOTH, Enum.Material.SmoothPlastic)
	decor("TeethGap", Vector3.new(0.06, 0.55, 0.16), spot * at(0, 3.9, 1.73), Color3.fromRGB(180, 175, 160), Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		decor("Eye", Vector3.new(0.3, 0.35, 0.1), spot * at(side * 0.55, 5.35, 1.32), BLACK, Enum.Material.SmoothPlastic)
		decor("Ear", Vector3.new(0.5, 0.5, 0.3), spot * at(side * 0.95, 6, 0), dark, Enum.Material.SmoothPlastic)
	end
	local box = floatingLabel(body, 5.2, 3)
	line(box, "Name", text.BigBeaver, 0.4)
	line(box, "Robux", string.format(text.Robux, tostring(cfg.BigBeaverPrice)), 0.35, ROBUX_GREEN)
	line(box, "Soon", text.ComingSoon, 0.25, Config.Style.Cream, Config.Style.BodyFont)
end

-- Builds the extras beside the sell pad of the sawmill whose floor plan's middle is at
-- `ground`, into `parent`. `padZ` is how far out (Z) the pad's middle is and `padRight` its
-- right edge (X, with the striped edge). Returns the stumps and the board.
function YardShop.build(ground: Vector3, wear: number, padZ: number, padRight: number, parent: Model): Spots
	origin = CFrame.new(ground)
	yard = parent
	wood = Blocky.shade(Color3.fromRGB(125, 80, 48), -wear)
	local x = padRight + 4.2
	local sack = buildSackStump(x, padZ - 2.5)
	local bag = buildBagStump(x, padZ + 2.5)
	local coins = buildCoinsBoard(x + 5.5, padZ)
	-- Level with the pad's front edge: any further out, it stands in Fog Hollow's border rocks.
	buildBeaver(x + 3.5, padZ + Config.Sawmill.PadSize.Y / 2 - 0.2)
	return { Sack = sack, Bag = bag, Coins = coins }
end

return YardShop
