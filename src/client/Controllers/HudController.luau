--!strict
-- Shows the player's Coins on the left side of the screen, with a small "+15" that floats up when coins go up.
-- It only DISPLAYS the Coins attribute the server sets on the player.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local POP_COLOR = Color3.fromRGB(255, 220, 90)
local POP_TIME = 0.9

local HudController = {}

local player = Players.LocalPlayer
local coinsLabel: TextLabel
local lastCoins = 0

local function getCoins(): number
	local value = player:GetAttribute("Coins")
	return if typeof(value) == "number" then value else 0
end

-- A "+N" label that floats up and fades out, then removes itself.
local function popGain(amount: number)
	local pop = Instance.new("TextLabel")
	pop.Name = "Pop"
	pop.AnchorPoint = Vector2.new(0, 0.5)
	pop.Position = UDim2.new(1, 8, 0.5, 0)
	pop.Size = UDim2.fromOffset(90, 30)
	pop.BackgroundTransparency = 1
	pop.Text = `+{amount}`
	pop.TextColor3 = POP_COLOR
	pop.TextStrokeTransparency = 0.4
	pop.Font = Enum.Font.GothamBlack
	pop.TextScaled = true
	pop.TextXAlignment = Enum.TextXAlignment.Left
	pop.Parent = coinsLabel

	local tween = TweenService:Create(pop, TweenInfo.new(POP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, 8, 0.5, -30),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		pop:Destroy()
	end)
	tween:Play()
end

local function refresh()
	local coins = getCoins()
	coinsLabel.Text = `Coins: {coins}`
	if coins > lastCoins then
		popGain(coins - lastCoins)
	end
	lastCoins = coins
end

function HudController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "Coins"
	-- Left side, a bit above the middle, so it doesn't cover the chat window.
	coinsLabel.AnchorPoint = Vector2.new(0, 0.5)
	coinsLabel.Position = UDim2.new(0, 16, 0.45, 0)
	coinsLabel.Size = UDim2.fromOffset(170, 40)
	coinsLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	coinsLabel.BackgroundTransparency = 0.3
	coinsLabel.TextColor3 = POP_COLOR
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.TextScaled = true
	coinsLabel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = coinsLabel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = coinsLabel

	gui.Parent = player:WaitForChild("PlayerGui")
end

function HudController.start()
	-- Start from the current amount so we don't "pop" the starting coins.
	lastCoins = getCoins()
	refresh()
	player:GetAttributeChangedSignal("Coins"):Connect(refresh)
end

return HudController
