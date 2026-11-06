--!strict
-- Building blocks for the timber UI (see STYLE_GUIDE.md), so every screen looks the same:
--   * text: cream (or coloured) with a thick dark outline, in Fredoka One
--   * ink: dark text without an outline, for writing on parchment
--   * plank: boards nailed together, with rough ends, grain and a bit of moss (the HUD's signs)
--   * panel: a big plank for menus; card: a dark board inside it; box: a plain dark board
--   * button: a chunky coloured block that squishes a little when pressed
--   * bar: a progress bar in a dark groove, with text on top
--   * logSlice: a round slice of a log (the tool slots, the phone buttons)
--   * paper: a parchment note with a pin; rope: a piece of rope for hanging signs
--   * coin / ember: small round icons made from frames (no images needed)
--   * screen / hudScale / keyBadge: the HUD (Config.Hud); its icons are drawn in Client/Icons
-- Colours and sizes are in Config.Style and Config.TimberUi. It's not a controller, so it has no
-- init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local Style = Config.Style
local Timber = Config.TimberUi
local Hud = Config.Hud
local OUTLINE = Timber.Outline
local PRESS_SCALE = 0.9 -- how small a button gets while it's pressed
local BASE_THICKNESS = "BaseThickness" -- remembers a line's size on a 1080p screen

local UiKit = {}

function UiKit.corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Style.Corner)
	corner.Parent = parent
end

-- A border around a frame. (On a TextLabel, a UIStroke outlines the text instead.)
function UiKit.border(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or OUTLINE
	stroke.Thickness = thickness or Style.BoxStroke
	stroke.Parent = parent
	return stroke
end

-- Light from above: the thing gets darker towards its bottom. A UIGradient multiplies with the
-- background colour, so changing that colour later still works. `dark` is 0 (black) to 1 (no change).
local function shade(object: GuiObject, dark: number)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(dark, dark, dark))
	gradient.Parent = object
end

-- A label that fills its size. The line's size has to be set before the label gets its parent
-- (see hudScale).
local function makeText(parent: Instance, name: string, text: string, color: Color3?, font: Enum.Font?, thickness: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Timber.Text
	label.Font = font or Style.BodyFont
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = thickness
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- Text that fills its size, with a dark outline so it's easy to read on anything.
function UiKit.text(parent: Instance, name: string, text: string, color: Color3?, font: Enum.Font?): TextLabel
	return makeText(parent, name, text, color, font, Style.TextStroke)
end

-- Smaller text (like descriptions) with a thinner outline, so it doesn't look blobby.
function UiKit.smallText(parent: Instance, name: string, text: string, color: Color3?): TextLabel
	return makeText(parent, name, text, color, nil, Style.TextStroke / 2)
end

-- Dark writing without an outline, for parchment.
function UiKit.ink(parent: Instance, name: string, text: string, color: Color3?, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Timber.Ink
	label.Font = font or Style.BodyFont
	label.TextScaled = true
	label.Parent = parent
	return label
end

-- A plain dark board (the boss bar, the dialogue box). It has no pieces inside, so you can put a
-- layout straight in it.
function UiKit.box(parent: Instance, name: string): Frame
	local box = Instance.new("Frame")
	box.Name = name
	box.BackgroundColor3 = Style.Box
	box.BackgroundTransparency = Style.BoxTransparency
	UiKit.corner(box)
	UiKit.border(box, Timber.Edge, Timber.BoardStroke)
	shade(box, 0.75)
	box.Parent = parent
	return box
end

-- Thin grain lines and sometimes a knot, scattered over a board. `random` picks the spots, so the
-- same board always looks the same. They stay behind anything else you put on the board, as long
-- as the screen uses UiKit.screen (or ZIndexBehavior = Sibling).
function UiKit.grain(board: GuiObject, random: Random)
	for index = 1, Timber.GrainLines do
		local width = random:NextNumber(0.18, 0.5)
		local line = Instance.new("Frame")
		line.Name = `Grain{index}`
		line.BackgroundColor3 = Timber.Grain
		line.BackgroundTransparency = 0.35
		line.BorderSizePixel = 0
		line.Position = UDim2.fromScale(random:NextNumber(0.03, 0.97 - width), random:NextNumber(0.15, 0.85))
		line.Size = UDim2.new(width, 0, 0, 2)
		line.ZIndex = 0
		line.Parent = board
	end
	if random:NextNumber() < Timber.KnotChance then
		local knot = Instance.new("Frame")
		knot.Name = "Knot"
		knot.AnchorPoint = Vector2.new(0.5, 0.5)
		knot.BackgroundColor3 = Timber.Grain
		knot.BorderSizePixel = 0
		knot.Position = UDim2.fromScale(random:NextNumber(0.15, 0.85), random:NextNumber(0.3, 0.7))
		knot.Size = UDim2.fromOffset(16, 10)
		knot.ZIndex = 0
		UiKit.corner(knot, 999)
		knot.Parent = board
	end
end

local function addNail(board: Frame, position: UDim2)
	local nail = Instance.new("Frame")
	nail.Name = "Nail"
	nail.AnchorPoint = Vector2.new(0.5, 0.5)
	nail.BackgroundColor3 = Timber.Nail
	nail.BorderSizePixel = 0
	nail.Position = position
	nail.Size = UDim2.fromOffset(Timber.NailSize, Timber.NailSize)
	nail.ZIndex = 0
	UiKit.corner(nail, 999)
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Timber.NailShine
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromScale(0.2, 0.2)
	shine.Size = UDim2.fromScale(0.35, 0.35)
	UiKit.corner(shine, 999)
	shine.Parent = nail
	nail.Parent = board
end

-- A tuft of moss growing over the top edge of a plank: a few soft green blobs.
local function addMoss(wood: Frame, random: Random)
	local x = random:NextNumber(0.04, 0.8)
	local offset = 0
	for _ = 1, random:NextInteger(3, 5) do
		local width = random:NextInteger(12, 26)
		local blob = Instance.new("Frame")
		blob.Name = "Moss"
		blob.BackgroundColor3 = Timber.Moss[random:NextInteger(1, #Timber.Moss)]
		blob.BorderSizePixel = 0
		blob.Position = UDim2.new(x, offset, 0, random:NextInteger(-5, -1))
		blob.Size = UDim2.fromOffset(width, random:NextInteger(8, 14))
		blob.ZIndex = 2
		UiKit.corner(blob, 999)
		blob.Parent = wood
		offset += math.floor(width * 0.65)
	end
end

-- Boards nailed together, one above the other, with rough ends and grain. Put your things straight
-- on it: the wood stays behind them. A layout needs its own frame on the plank, or it would move
-- the wood too.
function UiKit.plank(parent: Instance, name: string, boards: number?): Frame
	local count = boards or 2
	local plank = Instance.new("Frame")
	plank.Name = name
	plank.BackgroundTransparency = 1

	local wood = Instance.new("Frame")
	wood.Name = "Wood"
	wood.BackgroundTransparency = 1
	wood.Size = UDim2.fromScale(1, 1)
	wood.ZIndex = 0
	wood.Parent = plank

	local random = Random.new(#name * 31 + count) -- the same plank looks the same every time
	local first = random:NextInteger(1, #Timber.Planks)
	for row = 1, count do
		local short = random:NextInteger(0, Timber.RoughEnds)
		local board = Instance.new("Frame")
		board.Name = `Board{row}`
		board.AnchorPoint = Vector2.new(0.5, 0)
		board.BackgroundColor3 = Timber.Planks[(first + row) % #Timber.Planks + 1]
		board.Position = UDim2.new(0.5, random:NextInteger(-short // 2, short // 2), (row - 1) / count, 0)
		board.Size = UDim2.new(1, -short, 1 / count, 0)
		UiKit.corner(board, 3)
		UiKit.border(board, Timber.Edge, Timber.BoardStroke)
		shade(board, 0.8)
		UiKit.grain(board, random)
		addNail(board, UDim2.new(0, Timber.NailInset, 0.5, 0))
		addNail(board, UDim2.new(1, -Timber.NailInset, 0.5, 0))
		board.Parent = wood
	end
	for _ = 1, Timber.MossTufts do
		addMoss(wood, random)
	end

	plank.Parent = parent
	return plank
end

-- A big timber panel for menus.
function UiKit.panel(parent: Instance, name: string): Frame
	return UiKit.plank(parent, name, Timber.PanelBoards)
end

-- A row inside a panel: a darker piece of wood.
function UiKit.card(parent: Instance, name: string): Frame
	local card = Instance.new("Frame")
	card.Name = name
	card.BackgroundColor3 = Style.CardWood
	UiKit.corner(card)
	UiKit.border(card, Timber.Edge, Timber.BoardStroke)
	shade(card, 0.8)
	card.Parent = parent
	return card
end

-- A chunky button with outlined text. Change its colour with `button.BackgroundColor3` and its
-- text with the returned label.
function UiKit.button(parent: Instance, name: string, text: string, color: Color3): (TextButton, TextLabel)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	UiKit.corner(button)
	UiKit.border(button, Timber.Edge, Timber.BoardStroke)
	shade(button, 0.72)

	local label = UiKit.text(button, "Label", text)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.86, 0.7)

	-- Squish a little while pressed, then spring back.
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = PRESS_SCALE }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)

	button.Parent = parent
	return button, label
end

export type Bar = {
	Frame: Frame,
	Fill: Frame,
	Label: TextLabel,
}

-- A progress bar in a dark groove. Set how full it is with UiKit.setBar.
function UiKit.bar(parent: Instance, name: string, color: Color3?): Bar
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Style.BarBack
	frame.ClipsDescendants = true
	UiKit.corner(frame, 4)
	UiKit.border(frame, Timber.Edge)
	frame.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color or Style.Green
	fill.BorderSizePixel = 0
	UiKit.corner(fill, 4)
	shade(fill, 0.7)
	fill.Parent = frame

	local label = UiKit.smallText(frame, "Label", "")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 0.8)
	label.ZIndex = 2

	return { Frame = frame, Fill = fill, Label = label }
end

-- `fraction` is 0 (empty) to 1 (full). The fill slides there instead of jumping.
function UiKit.setBar(bar: Bar, fraction: number, text: string)
	local target = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	TweenService:Create(bar.Fill, TweenInfo.new(0.2), { Size = target }):Play()
	bar.Label.Text = text
end

-- A round piece of a log slice, centred in its parent. `size` is a share of the parent.
local function disc(parent: Instance, name: string, size: number, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(size, size)
	UiKit.corner(frame, 999)
	frame.Parent = parent
	return frame
end

-- A round slice of a log: a bark rim with little marks, a pale face with growth rings and a crack.
-- Returns the slice, its face (to give it another colour) and its outline.
function UiKit.logSlice(parent: Instance, name: string, faceColor: Color3?): (Frame, Frame, UIStroke)
	local slice = Instance.new("Frame")
	slice.Name = name
	slice.BackgroundColor3 = Timber.Bark
	UiKit.corner(slice, 999)
	local outline = UiKit.border(slice, Timber.Edge, Timber.BoardStroke)

	for index = 1, Timber.BarkMarks do
		local angle = math.rad(index * 360 / Timber.BarkMarks)
		local mark = Instance.new("Frame")
		mark.Name = "BarkMark"
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.BackgroundColor3 = Timber.Edge
		mark.BorderSizePixel = 0
		mark.Position = UDim2.fromScale(0.5 + 0.46 * math.sin(angle), 0.5 - 0.46 * math.cos(angle))
		mark.Rotation = math.deg(angle)
		mark.Size = UDim2.fromScale(0.025, 0.06)
		mark.Parent = slice
	end

	local face = disc(slice, "Face", 0.84, faceColor or Timber.CutWood)
	for index, size in { 0.72, 0.42 } do
		local ring = disc(face, `Ring{index}`, size, Timber.Rings)
		ring.BackgroundTransparency = 1
		UiKit.border(ring, Timber.Rings, 2)
	end
	disc(face, "Heart", 0.1, Timber.Rings)
	local crack = Instance.new("Frame")
	crack.Name = "Crack"
	crack.AnchorPoint = Vector2.new(0.5, 0.5)
	crack.BackgroundColor3 = Timber.Grain
	crack.BorderSizePixel = 0
	crack.Position = UDim2.fromScale(0.82, 0.22)
	crack.Rotation = 42
	crack.Size = UDim2.fromScale(0.025, 0.2)
	crack.Parent = face

	slice.Parent = parent
	return slice, face, outline
end

-- A parchment note with a red pin and a torn bottom edge. Put your things straight on it, like on
-- a plank. A slight Rotation makes it look pinned up by hand.
function UiKit.paper(parent: Instance, name: string): Frame
	local paper = Instance.new("Frame")
	paper.Name = name
	paper.BackgroundTransparency = 1

	local sheet = Instance.new("Frame")
	sheet.Name = "Sheet"
	sheet.BackgroundTransparency = 1
	sheet.Size = UDim2.fromScale(1, 1)
	sheet.ZIndex = 0
	sheet.Parent = paper

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.65
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(4, 5)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = 0
	UiKit.corner(shadow, 4)
	shadow.Parent = sheet

	-- The torn edge: little squares turned 45 degrees, poking out under the bottom.
	local edge = Timber.Paper:Lerp(Color3.new(0, 0, 0), 0.12)
	for index = 1, Timber.PaperTeeth do
		local tooth = Instance.new("Frame")
		tooth.Name = "Tooth"
		tooth.AnchorPoint = Vector2.new(0.5, 0.5)
		tooth.BackgroundColor3 = edge
		tooth.BorderSizePixel = 0
		tooth.Position = UDim2.fromScale((index - 0.5) / Timber.PaperTeeth, 1)
		tooth.Rotation = 45
		tooth.Size = UDim2.fromOffset(Timber.PaperTooth, Timber.PaperTooth)
		tooth.ZIndex = 1
		tooth.Parent = sheet
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundColor3 = Timber.Paper
	body.BorderSizePixel = 0
	body.Size = UDim2.fromScale(1, 1)
	body.ZIndex = 2
	UiKit.corner(body, 3)
	local aged = Instance.new("UIGradient")
	aged.Rotation = 90
	aged.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(0.93, 0.93, 0.93)),
		ColorSequenceKeypoint.new(0.3, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0.88, 0.88, 0.88)),
	})
	aged.Parent = body
	body.Parent = sheet

	local pin = Instance.new("Frame")
	pin.Name = "Pin"
	pin.AnchorPoint = Vector2.new(0.5, 0.5)
	pin.BackgroundColor3 = Timber.Pin
	pin.Position = UDim2.fromScale(0.5, 0)
	pin.Size = UDim2.fromOffset(Timber.PinSize, Timber.PinSize)
	pin.ZIndex = 3
	UiKit.corner(pin, 999)
	UiKit.border(pin, Timber.Outline)
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.45
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromScale(0.22, 0.2)
	shine.Size = UDim2.fromScale(0.3, 0.3)
	UiKit.corner(shine, 999)
	shine.Parent = pin
	pin.Parent = sheet

	paper.Parent = parent
	return paper
end

-- A piece of rope, hanging from `position` (its top middle) for `length` pixels, with a knot at
-- the bottom. Give it a negative position to start it above a sign or off the screen.
function UiKit.rope(parent: Instance, name: string, position: UDim2, length: number): Frame
	local rope = Instance.new("Frame")
	rope.Name = name
	rope.AnchorPoint = Vector2.new(0.5, 0)
	rope.BackgroundColor3 = Timber.Rope
	rope.Position = position
	rope.Size = UDim2.fromOffset(Timber.RopeWidth, length)
	UiKit.border(rope, Timber.Edge)

	local y = Timber.RopeTwist / 2
	while y < length do
		local twist = Instance.new("Frame")
		twist.Name = "Twist"
		twist.AnchorPoint = Vector2.new(0.5, 0.5)
		twist.BackgroundColor3 = Timber.RopeShade
		twist.BorderSizePixel = 0
		twist.Position = UDim2.new(0.5, 0, 0, y)
		twist.Rotation = -30
		twist.Size = UDim2.new(1, 1, 0, 2)
		twist.Parent = rope
		y += Timber.RopeTwist
	end

	local knot = disc(rope, "Knot", 1, Timber.Rope)
	knot.Position = UDim2.fromScale(0.5, 1)
	knot.Size = UDim2.fromOffset(Timber.RopeWidth + 6, Timber.RopeWidth + 6)
	UiKit.border(knot, Timber.Edge)

	rope.Parent = parent
	return rope
end

-- A round coin: gold with a darker ring.
function UiKit.coin(parent: Instance, name: string): Frame
	local coin = Instance.new("Frame")
	coin.Name = name
	coin.BackgroundColor3 = Style.Gold
	UiKit.corner(coin, 999)
	UiKit.border(coin)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.6, 0.6)
	ring.BackgroundTransparency = 1
	UiKit.corner(ring, 999)
	UiKit.border(ring, Color3.fromRGB(205, 150, 30), 3)
	ring.Parent = coin
	coin.Parent = parent
	return coin
end

-- An ember: an orange diamond with a yellow middle.
function UiKit.ember(parent: Instance, name: string): Frame
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromScale(0.72, 0.72)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = Style.Ember
	UiKit.corner(diamond, 4)
	UiKit.border(diamond)
	local middle = Instance.new("Frame")
	middle.AnchorPoint = Vector2.new(0.5, 0.5)
	middle.Position = UDim2.fromScale(0.5, 0.5)
	middle.Size = UDim2.fromScale(0.45, 0.45)
	middle.BackgroundColor3 = Style.Gold
	middle.BorderSizePixel = 0
	UiKit.corner(middle, 3)
	middle.Parent = diamond
	diamond.Parent = holder
	holder.Parent = parent
	return holder
end

-- How big the HUD is right now: 1 on a 1080p screen. Phones get MinScale; a screen too narrow for
-- everything (an old phone) gets less, so nothing overlaps.
function UiKit.currentScale(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local size = camera.ViewportSize
	local byHeight = math.clamp(size.Y / Hud.DesignHeight, Hud.MinScale, Hud.MaxScale)
	return math.max(math.min(byHeight, size.X / Hud.DesignWidth), Hud.NarrowScale)
end

-- A UIScale doesn't change the thickness of lines, so we do that here. Otherwise they'd look
-- twice as thick on a phone and text would turn into blobs.
local function scaleLine(line: UIStroke, scale: number)
	local base = line:GetAttribute(BASE_THICKNESS)
	if typeof(base) ~= "number" then
		base = line.Thickness
		line:SetAttribute(BASE_THICKNESS, base)
	end
	line.Thickness = (base :: number) * scale
end

-- Make a HUD screen grow and shrink with the screen. A UIScale on a ScreenGui scales everything
-- in it, and things stuck to an edge (or the middle) stay there, so the HUD fits on phones too.
function UiKit.hudScale(gui: ScreenGui)
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function update()
		scale.Scale = UiKit.currentScale()
		for _, descendant in gui:GetDescendants() do
			if descendant:IsA("UIStroke") then
				scaleLine(descendant, scale.Scale)
			end
		end
	end
	update()
	gui.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("UIStroke") then
			scaleLine(descendant, scale.Scale)
		end
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

-- A new HUD screen that grows and shrinks with the screen. Children are always drawn over their
-- parent, and ZIndex only orders things next to each other (ZIndexBehavior Sibling), which is what
-- keeps the wood behind what's on it.
function UiKit.screen(name: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UiKit.hudScale(gui)
	return gui
end

-- Does this device have keys? (Key badges are hidden on phones.)
function UiKit.hasKeyboard(): boolean
	return UserInputService.KeyboardEnabled or not UserInputService.TouchEnabled
end

-- A small dark key badge, like "T" or "R", that says which key does something.
function UiKit.keyBadge(parent: Instance, name: string, key: string): Frame
	local badge = Instance.new("Frame")
	badge.Name = name
	badge.BackgroundColor3 = Style.Box
	badge.Size = UDim2.fromOffset(math.max(Hud.KeyBadge, 14 * #key + 14), Hud.KeyBadge)
	UiKit.corner(badge)
	UiKit.border(badge, Timber.Edge)
	local label = UiKit.smallText(badge, "Key", key)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.8, 0.7)
	badge.Parent = parent
	return badge
end

-- A quick "boing" to draw the eye to something that just changed (like a counter going up).
function UiKit.bounce(object: GuiObject)
	local scale = object:FindFirstChildOfClass("UIScale")
	if not scale then
		local newScale = Instance.new("UIScale")
		newScale.Parent = object
		scale = newScale
	end
	if scale then
		scale.Scale = 1.15
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
end

-- In first person the mouse is locked in the middle of the screen, so you couldn't click a
-- menu's buttons. A "Modal" button frees the mouse while it's showing, so put one (invisible)
-- in every menu: the mouse is free while the menu is open and locked again when it closes.
-- The gui also gets the FREES_MOUSE attribute, so ViewmodelController can hide the crosshair
-- and show the mouse while it's open.
UiKit.FREES_MOUSE = "FreesMouse"
function UiKit.freeMouse(gui: ScreenGui)
	gui:SetAttribute(UiKit.FREES_MOUSE, true)
	local button = Instance.new("TextButton")
	button.Name = "FreeMouse"
	button.Modal = true
	button.Text = ""
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromOffset(1, 1)
	button.Selectable = false
	button.Parent = gui
end

-- A screen with this attribute takes over the camera (like the Garage's showroom), so
-- ViewmodelController hides the first-person arms while it's open.
UiKit.HIDES_ARMS = "HidesArms"

return UiKit
