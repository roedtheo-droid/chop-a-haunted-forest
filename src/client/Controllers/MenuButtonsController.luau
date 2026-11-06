--!strict
-- The signpost on the right side of the screen: a post with two boards shaped like arrows,
-- SHOP (R key) and UPGRADES (U key). Each board has a picture, a word and a small key badge
-- (no badge on phones). Sizes are in Config.Hud (pixels on a 1080p screen).
--
-- The menus they open are in MenusController, which plugs them in with
-- MenuButtonsController.setAction("Shop", toggleShop). A board with no action shows a short message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(script.Parent.Parent.Icons)
local UiKit = require(script.Parent.Parent.UiKit)
local NotifyController = require(script.Parent.NotifyController)

local Hud = Config.Hud
local Timber = Config.TimberUi
local PRESS_SCALE = 0.92 -- how small a board gets while it's pressed

export type ButtonName = "Shop" | "Upgrades"

type ButtonInfo = {
	Name: ButtonName,
	Label: string,
	Key: string, -- the text on the key badge
	KeyCode: Enum.KeyCode,
	Icon: (parent: Instance, name: string) -> Frame,
}

local BUTTONS: { ButtonInfo } = {
	{ Name = "Shop", Label = Hud.Text.Shop, Key = Hud.Text.ShopKey, KeyCode = Hud.ShopKey, Icon = Icons.basket },
	{ Name = "Upgrades", Label = Hud.Text.Upgrades, Key = Hud.Text.UpgradesKey, KeyCode = Hud.UpgradesKey, Icon = Icons.upArrow },
}

local MenuButtonsController = {}

local player = Players.LocalPlayer
local actions: { [string]: () -> () } = {}

-- What a board does. The menus set this when they're built.
function MenuButtonsController.setAction(name: ButtonName, action: () -> ())
	actions[name] = action
end

local function press(info: ButtonInfo)
	local action = actions[info.Name]
	if action then
		action()
	else
		NotifyController.show(Hud.Text.NotReady)
	end
end

-- One board shaped like an arrow pointing left. The point is a square turned 45 degrees behind the
-- board's left end, and a patch hides the line where the two meet.
local function makeBoard(parent: Instance, info: ButtonInfo, order: number)
	local height = Hud.PostBoardHeight
	local color = Timber.Planks[order]

	local button = Instance.new("TextButton")
	button.Name = info.Name
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(Hud.PostBoardWidth, height)

	local side = height / math.sqrt(2)
	local point = Instance.new("Frame")
	point.Name = "Point"
	point.AnchorPoint = Vector2.new(0.5, 0.5)
	point.BackgroundColor3 = color
	point.Position = UDim2.new(0, height / 2, 0.5, 0)
	point.Rotation = 45
	point.Size = UDim2.fromOffset(side, side)
	UiKit.corner(point, 3)
	UiKit.border(point, Timber.Edge, Timber.BoardStroke)
	point.Parent = button

	local board = Instance.new("Frame")
	board.Name = "Board"
	board.BackgroundColor3 = color
	board.Position = UDim2.fromOffset(height / 2, 0)
	board.Size = UDim2.new(1, -height / 2, 1, 0)
	UiKit.corner(board, 3)
	UiKit.border(board, Timber.Edge, Timber.BoardStroke)
	UiKit.grain(board, Random.new(order))
	board.Parent = button

	local patch = Instance.new("Frame")
	patch.Name = "Patch"
	patch.BackgroundColor3 = color
	patch.BorderSizePixel = 0
	patch.Position = UDim2.fromOffset(height / 2 - 5, 0)
	patch.Size = UDim2.new(0, 10, 1, 0)
	patch.Parent = button

	local icon = info.Icon(button, "Icon")
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, height / 2 - 12, 0.5, 0)
	icon.Size = UDim2.fromOffset(Hud.PostIcon, Hud.PostIcon)

	local textLeft = height / 2 - 12 + Hud.PostIcon + 4
	local hasKeyboard = UiKit.hasKeyboard()
	local badgeRoom = if hasKeyboard then Hud.KeyBadge + 14 else 8
	local label = UiKit.text(button, "Label", info.Label)
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, textLeft, 0.5, 0)
	label.Size = UDim2.new(1, -(textLeft + badgeRoom), 0, Hud.PostText)
	label.TextXAlignment = Enum.TextXAlignment.Left

	if hasKeyboard then
		local badge = UiKit.keyBadge(button, "KeyBadge", info.Key)
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Position = UDim2.new(1, -8, 0.5, 0)
	end

	-- Squish a little while pressed, then spring back (like UiKit.button).
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
	button.Activated:Connect(function()
		press(info)
	end)

	button.Parent = parent
end

function MenuButtonsController.init()
	local gui = UiKit.screen("MenuButtons")

	local boardsHeight = #BUTTONS * Hud.PostBoardHeight + (#BUTTONS - 1) * Hud.PostBoardGap
	local signpost = Instance.new("Frame")
	signpost.Name = "Signpost"
	signpost.BackgroundTransparency = 1
	signpost.AnchorPoint = Vector2.new(1, 0)
	signpost.Position = UDim2.new(1, -Hud.Margin, 0, Hud.SignpostY)
	signpost.Size = UDim2.fromOffset(Hud.PostBoardWidth, boardsHeight)
	signpost.Parent = gui

	-- The post, behind the boards near their right end.
	local post = Instance.new("Frame")
	post.Name = "Post"
	post.AnchorPoint = Vector2.new(0.5, 0.5)
	post.BackgroundColor3 = Timber.Bark
	post.Position = UDim2.new(1, -Hud.PostWidth / 2 - 22, 0.5, 0)
	post.Size = UDim2.new(0, Hud.PostWidth, 1, 2 * Hud.PostOver)
	UiKit.corner(post, 4)
	UiKit.border(post, Timber.Edge, Timber.BoardStroke)
	UiKit.grain(post, Random.new(7))
	post.Parent = signpost

	-- The boards go in their own frame, so the layout doesn't move the post.
	local boards = Instance.new("Frame")
	boards.Name = "Boards"
	boards.BackgroundTransparency = 1
	boards.Size = UDim2.fromScale(1, 1)
	boards.ZIndex = 2
	boards.Parent = signpost

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Hud.PostBoardGap)
	layout.Parent = boards

	for index, info in BUTTONS do
		makeBoard(boards, info, index)
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
			if input.KeyCode == info.KeyCode then
				press(info)
				return
			end
		end
	end)
end

return MenuButtonsController
