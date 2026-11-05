--!strict
-- Building blocks for the cartoony UI (see STYLE_GUIDE.md), so every screen looks the same:
--   * text: white (or coloured) with a thick black outline, in Fredoka One
--   * box: a dark, see-through, rounded box with a black border (for the HUD)
--   * panel: a wooden panel with a dark wood border (for menus like the Tool Shed)
--   * button: a rounded, coloured button that squishes a little when pressed
--   * bar: a rounded progress bar with text on top
--   * coin / ember: small round icons made from frames (no images needed)
--   * hudText / hudPanel / hudDot / hudBar: the purple HUD (Config.Hud), flatter, with no
--     thick black outlines
-- Colours and sizes are in Config.Style. It's not a controller, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Style = Config.Style
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local PRESS_SCALE = 0.9 -- how small a button gets while it's pressed

local UiKit = {}

function UiKit.corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Style.Corner)
	corner.Parent = parent
end

-- A border around a frame. (On a TextLabel, a UIStroke outlines the text instead.)
function UiKit.border(parent: GuiObject, color: Color3?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or BLACK
	stroke.Thickness = thickness or Style.BoxStroke
	stroke.Parent = parent
end

-- Text that fills its size, with a black outline so it's easy to read on anything.
function UiKit.text(parent: Instance, name: string, text: string, color: Color3?, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or WHITE
	label.Font = font or Style.BodyFont
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Color = BLACK
	stroke.Thickness = Style.TextStroke
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- Smaller text (like descriptions) with a thinner outline, so it doesn't look blobby.
function UiKit.smallText(parent: Instance, name: string, text: string, color: Color3?): TextLabel
	local label = UiKit.text(parent, name, text, color)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = Style.TextStroke / 2
	end
	return label
end

-- A dark, rounded HUD box.
function UiKit.box(parent: Instance, name: string): Frame
	local box = Instance.new("Frame")
	box.Name = name
	box.BackgroundColor3 = Style.Box
	box.BackgroundTransparency = Style.BoxTransparency
	UiKit.corner(box)
	UiKit.border(box)
	box.Parent = parent
	return box
end

-- A wooden menu panel.
function UiKit.panel(parent: Instance, name: string): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.BackgroundColor3 = Style.Wood
	UiKit.corner(panel, Style.Corner + 4)
	UiKit.border(panel, Style.DarkWood, Style.PanelStroke)
	panel.Parent = parent
	return panel
end

-- A row inside a wooden panel: a slightly darker piece of wood.
function UiKit.card(parent: Instance, name: string): Frame
	local card = Instance.new("Frame")
	card.Name = name
	card.BackgroundColor3 = Style.CardWood
	UiKit.corner(card)
	UiKit.border(card, Style.DarkWood)
	card.Parent = parent
	return card
end

-- A rounded button with outlined text. Change its colour with `button.BackgroundColor3`
-- and its text with the returned label.
function UiKit.button(parent: Instance, name: string, text: string, color: Color3): (TextButton, TextLabel)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	UiKit.corner(button)
	UiKit.border(button)

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

-- A rounded progress bar. Set how full it is with UiKit.setBar.
function UiKit.bar(parent: Instance, name: string, color: Color3?): Bar
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Style.BarBack
	frame.ClipsDescendants = true
	UiKit.corner(frame, 6)
	UiKit.border(frame)
	frame.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color or Style.Green
	fill.BorderSizePixel = 0
	UiKit.corner(fill, 6)
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

-- The purple HUD (colours and sizes in Config.Hud). It's flatter than the menus: no thick
-- black outlines, just dark purple rounded panels with a lighter purple edge.
local Hud = Config.Hud

-- HUD text at a fixed size in pixels. A thin, soft dark outline keeps it readable when it sits
-- over bright scenery instead of a panel.
function UiKit.hudText(parent: Instance, name: string, text: string, size: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Hud.Ink
	label.Font = Hud.Font
	label.TextSize = size
	local stroke = Instance.new("UIStroke")
	stroke.Color = Hud.Panel
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- A dark purple, rounded HUD panel with a lighter purple edge.
function UiKit.hudPanel(parent: Instance, name: string, radius: number?): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.BackgroundColor3 = Hud.Panel
	panel.BackgroundTransparency = Hud.PanelTransparency
	UiKit.corner(panel, radius or Hud.Corner)
	UiKit.border(panel, Hud.Edge, Hud.EdgeThickness)
	panel.Parent = parent
	return panel
end

-- A round dot: the coin, the log and the heart in the HUD. `glyph` is a letter or symbol on it.
function UiKit.hudDot(parent: Instance, name: string, color: Color3, glyph: string?): Frame
	local dot = Instance.new("Frame")
	dot.Name = name
	dot.BackgroundColor3 = color
	UiKit.corner(dot, 999)
	UiKit.border(dot, Hud.Track, 3)
	if glyph then
		local label = UiKit.hudText(dot, "Glyph", glyph, 16, Hud.Panel)
		label.Size = UDim2.fromScale(1, 1)
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Enabled = false
		end
	end
	dot.Parent = parent
	return dot
end

-- Shrink every HUD screen on short screens (see Config.Hud.FullSizeHeight). A UIScale on a
-- ScreenGui scales everything in it, and things stuck to an edge stay at that edge.
function UiKit.hudScale(gui: ScreenGui)
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function update()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else Hud.FullSizeHeight
		scale.Scale = math.clamp(height / Hud.FullSizeHeight, Hud.MinScale, 1)
	end
	update()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

-- A rounded HUD bar with its text on top. Set how full it is with UiKit.setBar.
function UiKit.hudBar(parent: Instance, name: string, color: Color3, textSize: number?): Bar
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Hud.Track
	frame.ClipsDescendants = true
	UiKit.corner(frame, 999)
	frame.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	UiKit.corner(fill, 999)
	fill.Parent = frame

	local label = UiKit.hudText(frame, "Label", "", textSize or 13)
	label.Size = UDim2.fromScale(1, 1)
	label.ZIndex = 2

	return { Frame = frame, Fill = fill, Label = label }
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
