--!strict
-- Little pictures for the HUD, drawn from coloured frames (no image uploads needed), in the
-- cartoony style: bright colours and a black outline. Every icon is a see-through square
-- holder; its pieces are placed in "scale" (0 to 1 across the holder), so set the holder's
-- Size to any size and the whole picture grows or shrinks with it.
-- It's not a controller, so it has no init()/start().
--
--   local coin = Icons.coin(parent, "Coin")
--   coin.Size = UDim2.fromOffset(80, 80)

local Icons = {}

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local OUTLINE = 2.5 -- pixels

type PieceOptions = {
	Round: number?, -- 0.5 makes a circle (or a pill), 0.2 a rounded square
	Rotation: number?,
	Outline: boolean?, -- false: no black outline
	Transparency: number?,
	Z: number?, -- higher numbers are drawn on top
}

-- One piece of a picture: a box centred at (x, y), w wide and h tall, all from 0 to 1.
local function piece(holder: Frame, name: string, x: number, y: number, w: number, h: number, color: Color3, options: PieceOptions?): Frame
	local opts: PieceOptions = options or {}
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = opts.Transparency or 0
	frame.BorderSizePixel = 0
	frame.Rotation = opts.Rotation or 0
	frame.ZIndex = opts.Z or 1
	if opts.Round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(opts.Round, 0)
		corner.Parent = frame
	end
	if opts.Outline ~= false then
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = BLACK
		stroke.Thickness = OUTLINE
		stroke.Parent = frame
	end
	frame.Parent = holder
	return frame
end

-- A ring: only an outline, in `color`.
local function ring(holder: Frame, name: string, x: number, y: number, w: number, h: number, color: Color3, thickness: number, z: number?): Frame
	local frame = piece(holder, name, x, y, w, h, color, { Round = 0.5, Outline = false, Transparency = 1, Z = z })
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = frame
	return frame
end

-- A symbol (like a star) written in the picture.
local function glyph(holder: Frame, text: string, x: number, y: number, size: number, color: Color3, z: number?)
	local label = Instance.new("TextLabel")
	label.Name = "Glyph"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(size, size)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.ZIndex = z or 3
	label.Parent = holder
end

local function holder(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(64, 64)
	frame.Parent = parent
	return frame
end

-- A gold coin with a darker rim, a star stamped in the middle and a shine.
function Icons.coin(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	piece(h, "Edge", 0.5, 0.54, 0.92, 0.88, Color3.fromRGB(205, 140, 20), { Round = 0.5 })
	piece(h, "Face", 0.5, 0.5, 0.92, 0.88, Color3.fromRGB(255, 200, 40), { Round = 0.5, Z = 2 })
	ring(h, "Rim", 0.5, 0.5, 0.66, 0.62, Color3.fromRGB(215, 150, 25), 3, 3)
	glyph(h, "★", 0.5, 0.5, 0.46, Color3.fromRGB(215, 150, 25), 4)
	piece(h, "Shine", 0.3, 0.28, 0.2, 0.09, WHITE, { Round = 0.5, Rotation = -40, Outline = false, Transparency = 0.25, Z = 5 })
	return h
end

-- An Ember: a glowing orange crystal with a yellow core and a sparkle.
function Icons.ember(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	piece(h, "Glow", 0.5, 0.5, 0.95, 0.95, Color3.fromRGB(255, 150, 60), { Round = 0.5, Outline = false, Transparency = 0.75 })
	piece(h, "Crystal", 0.5, 0.5, 0.6, 0.6, Color3.fromRGB(255, 120, 45), { Round = 0.12, Rotation = 45, Z = 2 })
	piece(h, "Core", 0.5, 0.5, 0.32, 0.32, Color3.fromRGB(255, 215, 80), { Round = 0.12, Rotation = 45, Outline = false, Z = 3 })
	piece(h, "Shine", 0.38, 0.36, 0.1, 0.1, WHITE, { Round = 0.5, Outline = false, Z = 4 })
	glyph(h, "✦", 0.82, 0.18, 0.28, Color3.fromRGB(255, 240, 170), 5)
	return h
end

-- A brown backpack with a flap, a buckle, a pocket and a handle.
function Icons.backpack(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	ring(h, "Handle", 0.5, 0.16, 0.34, 0.24, Color3.fromRGB(95, 60, 30), 4)
	piece(h, "Body", 0.5, 0.58, 0.74, 0.72, Color3.fromRGB(160, 100, 55), { Round = 0.25, Z = 2 })
	piece(h, "Flap", 0.5, 0.36, 0.78, 0.3, Color3.fromRGB(125, 75, 38), { Round = 0.35, Z = 3 })
	piece(h, "Buckle", 0.5, 0.5, 0.14, 0.12, Color3.fromRGB(255, 205, 60), { Round = 0.2, Z = 4 })
	piece(h, "Pocket", 0.5, 0.76, 0.46, 0.22, Color3.fromRGB(135, 85, 45), { Round = 0.3, Z = 3 })
	piece(h, "Stitch", 0.5, 0.76, 0.32, 0.03, Color3.fromRGB(230, 190, 140), { Outline = false, Z = 4 })
	return h
end

-- A stopwatch: a white face with a red hand and a button on top.
function Icons.stopwatch(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	piece(h, "Button", 0.5, 0.1, 0.2, 0.12, Color3.fromRGB(200, 60, 50), { Round = 0.2 })
	piece(h, "Knob", 0.8, 0.22, 0.14, 0.1, Color3.fromRGB(170, 170, 180), { Round = 0.3, Rotation = 45 })
	piece(h, "Case", 0.5, 0.58, 0.84, 0.8, Color3.fromRGB(170, 175, 190), { Round = 0.5, Z = 2 })
	piece(h, "Face", 0.5, 0.58, 0.66, 0.63, WHITE, { Round = 0.5, Outline = false, Z = 3 })
	for index, angle in { 0, 90, 180, 270 } do
		local radians = math.rad(angle)
		piece(h, `Tick{index}`, 0.5 + 0.25 * math.sin(radians), 0.58 - 0.24 * math.cos(radians), 0.05, 0.05, Color3.fromRGB(60, 60, 70), { Round = 0.5, Outline = false, Z = 4 })
	end
	piece(h, "Hand", 0.56, 0.5, 0.05, 0.22, Color3.fromRGB(220, 50, 50), { Round = 0.5, Rotation = 35, Outline = false, Z = 5 })
	piece(h, "Middle", 0.5, 0.58, 0.09, 0.09, Color3.fromRGB(40, 40, 45), { Round = 0.5, Outline = false, Z = 6 })
	return h
end

-- A red map pin with a white hole.
function Icons.pin(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	piece(h, "Shadow", 0.5, 0.95, 0.36, 0.08, BLACK, { Round = 0.5, Outline = false, Transparency = 0.6 })
	piece(h, "Point", 0.5, 0.6, 0.42, 0.42, Color3.fromRGB(205, 40, 40), { Rotation = 45, Round = 0.1 })
	piece(h, "Head", 0.5, 0.38, 0.72, 0.68, Color3.fromRGB(235, 55, 50), { Round = 0.5, Z = 2 })
	piece(h, "Hole", 0.5, 0.38, 0.28, 0.27, WHITE, { Round = 0.5, Z = 3 })
	piece(h, "Shine", 0.32, 0.24, 0.12, 0.08, WHITE, { Round = 0.5, Rotation = -40, Outline = false, Transparency = 0.3, Z = 4 })
	return h
end

-- The Elder Hollow's face: a square of dark bark with glowing eyes and a jagged mouth.
function Icons.bossFace(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	piece(h, "Bark", 0.5, 0.5, 0.92, 0.92, Color3.fromRGB(85, 55, 35), { Round = 0.2 })
	piece(h, "Groove1", 0.24, 0.5, 0.05, 0.7, Color3.fromRGB(60, 38, 24), { Outline = false, Z = 2 })
	piece(h, "Groove2", 0.78, 0.46, 0.05, 0.6, Color3.fromRGB(60, 38, 24), { Outline = false, Z = 2 })
	for _, x in { 0.34, 0.66 } do
		piece(h, "EyeHole", x, 0.38, 0.22, 0.18, Color3.fromRGB(25, 15, 10), { Round = 0.4, Outline = false, Z = 3 })
		piece(h, "Eye", x, 0.39, 0.12, 0.1, Color3.fromRGB(255, 190, 60), { Round = 0.5, Outline = false, Z = 4 })
	end
	piece(h, "Mouth", 0.5, 0.7, 0.52, 0.16, Color3.fromRGB(25, 15, 10), { Round = 0.3, Outline = false, Z = 3 })
	for index, x in { 0.36, 0.5, 0.64 } do
		piece(h, `Tooth{index}`, x, 0.65, 0.07, 0.07, Color3.fromRGB(235, 220, 180), { Rotation = 45, Outline = false, Z = 4 })
	end
	return h
end

-- A small axe with a flame (the tool trial).
function Icons.flameTool(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	piece(h, "Handle", 0.42, 0.58, 0.12, 0.72, Color3.fromRGB(150, 95, 50), { Round = 0.4, Rotation = -35 })
	piece(h, "Blade", 0.3, 0.34, 0.36, 0.26, Color3.fromRGB(190, 195, 205), { Round = 0.25, Rotation = -35, Z = 2 })
	piece(h, "Flame", 0.74, 0.32, 0.36, 0.36, Color3.fromRGB(255, 120, 30), { Round = 0.5, Rotation = 45, Z = 3 })
	piece(h, "FlameTip", 0.82, 0.2, 0.2, 0.2, Color3.fromRGB(255, 120, 30), { Round = 0.2, Rotation = 45, Outline = false, Z = 3 })
	piece(h, "FlameCore", 0.74, 0.36, 0.17, 0.17, Color3.fromRGB(255, 225, 80), { Round = 0.5, Outline = false, Z = 4 })
	return h
end

-- A fist (slot 1 of the tool bar: no tool).
function Icons.fist(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	local skin = Color3.fromRGB(234, 184, 146)
	local line = Color3.fromRGB(190, 135, 100)
	piece(h, "Hand", 0.52, 0.56, 0.7, 0.6, skin, { Round = 0.3 })
	piece(h, "Thumb", 0.32, 0.68, 0.36, 0.2, skin, { Round = 0.5, Rotation = -20, Z = 2 })
	for index, x in { 0.42, 0.57, 0.72 } do
		piece(h, `Finger{index}`, x, 0.4, 0.03, 0.22, line, { Outline = false, Z = 3 })
	end
	piece(h, "Cuff", 0.6, 0.9, 0.46, 0.14, Color3.fromRGB(70, 110, 190), { Round = 0.3 })
	return h
end

-- A red shopping basket with a handle (the SHOP button).
function Icons.basket(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	ring(h, "Handle", 0.5, 0.36, 0.5, 0.46, Color3.fromRGB(150, 30, 30), 5)
	piece(h, "Body", 0.5, 0.66, 0.74, 0.44, Color3.fromRGB(220, 55, 50), { Round = 0.2, Z = 2 })
	piece(h, "Rim", 0.5, 0.45, 0.86, 0.12, Color3.fromRGB(180, 35, 35), { Round = 0.4, Z = 3 })
	for index, x in { 0.34, 0.5, 0.66 } do
		piece(h, `Slot{index}`, x, 0.68, 0.07, 0.24, Color3.fromRGB(160, 30, 30), { Round = 0.5, Outline = false, Z = 3 })
	end
	return h
end

-- A thick green arrow pointing up (the UPGRADES button).
function Icons.upArrow(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	local green = Color3.fromRGB(80, 200, 70)
	piece(h, "Head", 0.5, 0.42, 0.52, 0.52, green, { Rotation = 45, Round = 0.12 })
	piece(h, "Stem", 0.5, 0.7, 0.3, 0.42, green, { Round = 0.15 })
	-- Cover the outline where the head and the stem overlap.
	piece(h, "Join", 0.5, 0.56, 0.26, 0.22, green, { Outline = false, Z = 2 })
	piece(h, "Shine", 0.44, 0.38, 0.08, 0.2, WHITE, { Round = 0.5, Outline = false, Transparency = 0.4, Z = 3 })
	return h
end

-- A pink paw (the PETS button).
function Icons.paw(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	local pink = Color3.fromRGB(240, 130, 175)
	piece(h, "Pad", 0.5, 0.68, 0.5, 0.42, pink, { Round = 0.5 })
	piece(h, "Toe1", 0.2, 0.42, 0.2, 0.24, pink, { Round = 0.5 })
	piece(h, "Toe2", 0.38, 0.24, 0.2, 0.24, pink, { Round = 0.5 })
	piece(h, "Toe3", 0.62, 0.24, 0.2, 0.24, pink, { Round = 0.5 })
	piece(h, "Toe4", 0.8, 0.42, 0.2, 0.24, pink, { Round = 0.5 })
	return h
end

-- A little white ghost (next to the courage bar).
function Icons.ghost(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	local white = Color3.fromRGB(240, 240, 250)
	piece(h, "Head", 0.5, 0.42, 0.7, 0.66, white, { Round = 0.5 })
	piece(h, "Body", 0.5, 0.66, 0.7, 0.42, white, { Round = 0.15, Z = 2 })
	piece(h, "Join", 0.5, 0.5, 0.66, 0.2, white, { Outline = false, Z = 3 })
	for index, x in { 0.27, 0.5, 0.73 } do
		piece(h, `Tail{index}`, x, 0.88, 0.2, 0.16, white, { Round = 0.5, Z = 1 })
	end
	for _, x in { 0.38, 0.62 } do
		piece(h, "Eye", x, 0.42, 0.1, 0.16, Color3.fromRGB(30, 30, 40), { Round = 0.5, Outline = false, Z = 4 })
	end
	piece(h, "Mouth", 0.5, 0.6, 0.12, 0.12, Color3.fromRGB(30, 30, 40), { Round = 0.5, Outline = false, Z = 4 })
	return h
end

-- A scroll with a "!" (next to the quest).
function Icons.quest(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	piece(h, "Paper", 0.5, 0.5, 0.64, 0.74, Color3.fromRGB(245, 225, 175), { Round = 0.12 })
	piece(h, "RollTop", 0.5, 0.15, 0.8, 0.14, Color3.fromRGB(215, 175, 115), { Round = 0.5, Z = 2 })
	piece(h, "RollBottom", 0.5, 0.86, 0.8, 0.14, Color3.fromRGB(215, 175, 115), { Round = 0.5, Z = 2 })
	glyph(h, "!", 0.5, 0.5, 0.5, Color3.fromRGB(200, 60, 40), 3)
	return h
end

-- An axe (the Chop Damage upgrade).
function Icons.axe(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	piece(h, "Handle", 0.4, 0.58, 0.13, 0.85, Color3.fromRGB(150, 95, 50), { Round = 0.4, Rotation = 35 })
	piece(h, "Head", 0.71, 0.28, 0.38, 0.28, Color3.fromRGB(190, 195, 205), { Round = 0.2, Rotation = 35, Z = 2 })
	piece(h, "Edge", 0.85, 0.38, 0.08, 0.3, Color3.fromRGB(240, 245, 255), { Round = 0.4, Rotation = 35, Outline = false, Z = 3 })
	return h
end

-- A blue running shoe with speed lines (the Walk Speed upgrade).
function Icons.boot(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	local blue = Color3.fromRGB(70, 130, 230)
	for index, y in { 0.42, 0.56, 0.7 } do
		piece(h, `Speed{index}`, 0.12, y, 0.16, 0.06, WHITE, { Round = 0.5, Outline = false, Transparency = 0.2 })
	end
	piece(h, "Leg", 0.46, 0.36, 0.3, 0.46, blue, { Round = 0.15 })
	piece(h, "Foot", 0.6, 0.66, 0.64, 0.26, blue, { Round = 0.4, Z = 2 })
	piece(h, "Join", 0.46, 0.58, 0.26, 0.14, blue, { Outline = false, Z = 3 })
	piece(h, "Sole", 0.6, 0.8, 0.7, 0.1, WHITE, { Round = 0.5, Z = 3 })
	piece(h, "Lace", 0.5, 0.56, 0.16, 0.05, WHITE, { Outline = false, Z = 4 })
	return h
end

-- A glowing lantern (the Lantern Radius upgrade).
function Icons.lantern(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	local metal = Color3.fromRGB(70, 70, 80)
	piece(h, "Glow", 0.5, 0.55, 0.95, 0.95, Color3.fromRGB(255, 220, 90), { Round = 0.5, Outline = false, Transparency = 0.8 })
	ring(h, "Handle", 0.5, 0.14, 0.3, 0.2, metal, 4)
	piece(h, "Cap", 0.5, 0.27, 0.52, 0.1, metal, { Round = 0.3, Z = 2 })
	piece(h, "Glass", 0.5, 0.55, 0.46, 0.48, Color3.fromRGB(255, 215, 90), { Round = 0.2, Z = 2 })
	piece(h, "Flame", 0.5, 0.57, 0.14, 0.22, Color3.fromRGB(255, 130, 40), { Round = 0.5, Outline = false, Z = 3 })
	piece(h, "Base", 0.5, 0.83, 0.58, 0.1, metal, { Round = 0.3, Z = 3 })
	return h
end

-- A big brown beaver with buck teeth (the Big Beaver in the SHOP).
function Icons.beaver(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	local fur = Color3.fromRGB(150, 95, 55)
	local dark = Color3.fromRGB(50, 30, 20)
	piece(h, "Tail", 0.78, 0.74, 0.34, 0.22, Color3.fromRGB(90, 60, 35), { Round = 0.5, Rotation = -20 })
	piece(h, "Body", 0.48, 0.68, 0.56, 0.48, fur, { Round = 0.5, Z = 2 })
	piece(h, "Ear1", 0.26, 0.2, 0.12, 0.12, fur, { Round = 0.5, Z = 2 })
	piece(h, "Ear2", 0.58, 0.2, 0.12, 0.12, fur, { Round = 0.5, Z = 2 })
	piece(h, "Head", 0.42, 0.38, 0.46, 0.42, fur, { Round = 0.5, Z = 3 })
	for _, x in { 0.34, 0.5 } do
		piece(h, "Eye", x, 0.33, 0.07, 0.09, dark, { Round = 0.5, Outline = false, Z = 4 })
	end
	piece(h, "Nose", 0.42, 0.45, 0.12, 0.08, dark, { Round = 0.5, Outline = false, Z = 4 })
	piece(h, "Teeth", 0.42, 0.54, 0.1, 0.09, WHITE, { Round = 0.15, Z = 4 })
	return h
end

-- A yellow sun with orange rays (the day bar).
function Icons.sun(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	local ray = Color3.fromRGB(255, 150, 30)
	for index = 0, 7 do
		local angle = index * 45
		local radians = math.rad(angle)
		piece(h, `Ray{index}`, 0.5 + 0.36 * math.sin(radians), 0.5 - 0.36 * math.cos(radians), 0.12, 0.22, ray, { Round = 0.4, Rotation = angle })
	end
	piece(h, "Sun", 0.5, 0.5, 0.58, 0.58, Color3.fromRGB(255, 210, 50), { Round = 0.5, Z = 2 })
	piece(h, "Shine", 0.38, 0.36, 0.14, 0.08, WHITE, { Round = 0.5, Rotation = -40, Outline = false, Transparency = 0.3, Z = 3 })
	return h
end

-- A pale full moon with craters (the night bar).
function Icons.moon(parent: Instance, name: string): Frame
	local h = holder(parent, name)
	local crater = Color3.fromRGB(190, 195, 215)
	piece(h, "Glow", 0.5, 0.5, 0.95, 0.95, Color3.fromRGB(200, 210, 255), { Round = 0.5, Outline = false, Transparency = 0.75 })
	piece(h, "Moon", 0.5, 0.5, 0.66, 0.66, Color3.fromRGB(235, 238, 250), { Round = 0.5, Z = 2 })
	piece(h, "Crater1", 0.4, 0.4, 0.16, 0.16, crater, { Round = 0.5, Outline = false, Z = 3 })
	piece(h, "Crater2", 0.62, 0.58, 0.12, 0.12, crater, { Round = 0.5, Outline = false, Z = 3 })
	piece(h, "Crater3", 0.44, 0.66, 0.08, 0.08, crater, { Round = 0.5, Outline = false, Z = 3 })
	return h
end

return Icons
