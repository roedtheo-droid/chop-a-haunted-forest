--!strict
-- The three round wooden buttons on the right side of the screen, like Chop a Forest's:
-- PETS (greyed out, "Soon"), SHOP (R key) and UPGRADES (U key). Each one has a picture,
-- a big label and a small key badge. Sizes are in Config.Hud (pixels on a 1080p screen).
--
-- The menus they open are in MenusController, which plugs them in with
-- MenuButtonsController.setAction("Shop", toggleShop). A button with no action shows a short message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(script.Parent.Parent.Icons)
local UiKit = require(script.Parent.Parent.UiKit)
local NotifyController = require(script.Parent.NotifyController)

local Hud = Config.Hud
local Style = Config.Style
local PRESS_SCALE = 0.9 -- how small a badge gets while it's pressed

export type ButtonName = "Pets" | "Shop" | "Upgrades"

type ButtonInfo = {
	Name: ButtonName,
	Label: string,
	Key: string, -- the text on the key badge
	KeyCode: Enum.KeyCode?, -- nil: no key
	Soon: boolean, -- greyed out, does nothing yet
	Icon: (parent: Instance, name: string) -> Frame,
}

local BUTTONS: { ButtonInfo } = {
	{ Name = "Pets", Label = Hud.Text.Pets, Key = Hud.Text.Soon, KeyCode = nil, Soon = true, Icon = Icons.paw },
	{ Name = "Shop", Label = Hud.Text.Shop, Key = Hud.Text.ShopKey, KeyCode = Hud.ShopKey, Soon = false, Icon = Icons.basket },
	{
		Name = "Upgrades",
		Label = Hud.Text.Upgrades,
		Key = Hud.Text.UpgradesKey,
		KeyCode = Hud.UpgradesKey,
		Soon = false,
		Icon = Icons.upArrow,
	},
}

local MenuButtonsController = {}

local player = Players.LocalPlayer
local actions: { [string]: () -> () } = {}

-- What a button does. The menus set this when they're built.
function MenuButtonsController.setAction(name: ButtonName, action: () -> ())
	actions[name] = action
end

local function press(info: ButtonInfo)
	if info.Soon then
		return
	end
	local action = actions[info.Name]
	if action then
		action()
	else
		NotifyController.show(Hud.Text.NotReady)
	end
end

-- One round wooden badge with its picture, label and key badge.
local function makeBadge(parent: Instance, info: ButtonInfo, order: number)
	local size = Hud.BadgeSize
	local labelHeight = Hud.BadgeLabelText

	-- The whole button (circle + label), so clicking the label works too.
	local button = Instance.new("TextButton")
	button.Name = info.Name
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(size + 60, size + labelHeight / 2)

	local circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.AnchorPoint = Vector2.new(0.5, 0)
	circle.Position = UDim2.fromScale(0.5, 0)
	circle.Size = UDim2.fromOffset(size, size)
	circle.BackgroundColor3 = if info.Soon then Hud.Soon else Style.Wood
	UiKit.corner(circle, 999)
	UiKit.border(circle, Style.DarkWood, Style.PanelStroke)
	circle.Parent = button

	-- A lighter ring inside the border, so it looks like a carved wooden badge.
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.82, 0.82)
	inner.BackgroundColor3 = if info.Soon then Hud.Soon else Style.CardWood
	UiKit.corner(inner, 999)
	inner.Parent = circle

	local icon = info.Icon(circle, "Icon")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.46)
	icon.Size = UDim2.fromScale(0.62, 0.62)

	if info.Soon then
		-- Grey the picture out with a see-through cover.
		local cover = Instance.new("Frame")
		cover.Name = "Cover"
		cover.AnchorPoint = Vector2.new(0.5, 0.5)
		cover.Position = UDim2.fromScale(0.5, 0.5)
		cover.Size = UDim2.fromScale(1, 1)
		cover.BackgroundColor3 = Hud.Soon
		cover.BackgroundTransparency = 0.4
		cover.ZIndex = 2
		UiKit.corner(cover, 999)
		cover.Parent = circle
	end

	-- The big label, half over the circle's bottom edge.
	local label = UiKit.text(button, "Label", info.Label, if info.Soon then Hud.Soon else nil)
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 1)
	label.Size = UDim2.new(1, 0, 0, labelHeight)
	label.ZIndex = 3

	-- The key badge on the circle's top-right edge.
	local badge = UiKit.keyBadge(button, "KeyBadge", info.Key)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(0.5, size * 0.36, 0, size * 0.14)
	badge.ZIndex = 3

	-- Squish a little while pressed, then spring back (like UiKit.button).
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseButton1Down:Connect(function()
		if not info.Soon then
			TweenService:Create(scale, TweenInfo.new(0.06), { Scale = PRESS_SCALE }):Play()
		end
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	button.Activated:Connect(function()
		press(info)
	end)

	button.Parent = parent
end

function MenuButtonsController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MenuButtons"
	gui.ResetOnSpawn = false
	UiKit.hudScale(gui)

	local stack = Instance.new("Frame")
	stack.Name = "Stack"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(1, 0.5)
	stack.Position = UDim2.new(1, -Hud.Margin, Hud.BadgeY, 0)
	local itemHeight = Hud.BadgeSize + Hud.BadgeLabelText / 2
	stack.Size = UDim2.fromOffset(Hud.BadgeSize + 60, #BUTTONS * itemHeight + (#BUTTONS - 1) * Hud.BadgeGap)
	stack.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Hud.BadgeGap)
	layout.Parent = stack

	for index, info in BUTTONS do
		makeBadge(stack, info, index)
	end

	gui.Parent = player:WaitForChild("PlayerGui")
end

function MenuButtonsController.start()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		-- gameProcessed is true while you type in the chat.
		if gameProcessed then
			return
		end
		for _, info in BUTTONS do
			if info.KeyCode and input.KeyCode == info.KeyCode then
				press(info)
				return
			end
		end
	end)
end

return MenuButtonsController
