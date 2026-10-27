--!strict
-- Building blocks for the cartoony UI (see STYLE_GUIDE.md), so every screen looks the same:
--   * text: white (or coloured) with a thick black outline, in Fredoka One
--   * box: a dark, see-through, rounded box with a black border (for the HUD)
--   * panel: a wooden panel with a dark wood border (for menus like the Tool Shed)
--   * button: a rounded, coloured button that squishes a little when pressed
--   * bar: a rounded progress bar with text on top
--   * coin / ember: small round icons made from frames (no images needed)
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

return UiKit
