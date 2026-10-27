--!strict
-- Shows the player's Coins and Embers on the left side of the screen, with a small "+15"
-- that floats up when one of them goes up.
-- It only DISPLAYS the Coins and Embers attributes the server sets on the player.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local COIN_COLOR = Color3.fromRGB(255, 220, 90)
local EMBER_COLOR = Color3.fromRGB(255, 130, 60)
local POP_TIME = 0.9

local HudController = {}

type Counter = {
	Attribute: string, -- the player attribute it shows, like "Coins"
	Title: string, -- the text before the number
	Label: TextLabel,
	Last: number, -- the amount it showed last time, to know how much it went up
}

local player = Players.LocalPlayer
local counters: { Counter } = {}

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- A "+N" label that floats up and fades out, then removes itself.
local function popGain(label: TextLabel, amount: number)
	local pop = Instance.new("TextLabel")
	pop.Name = "Pop"
	pop.AnchorPoint = Vector2.new(0, 0.5)
	pop.Position = UDim2.new(1, 8, 0.5, 0)
	pop.Size = UDim2.fromOffset(90, 30)
	pop.BackgroundTransparency = 1
	pop.Text = `+{amount}`
	pop.TextColor3 = label.TextColor3
	pop.TextStrokeTransparency = 0.4
	pop.Font = Enum.Font.GothamBlack
	pop.TextScaled = true
	pop.TextXAlignment = Enum.TextXAlignment.Left
	pop.Parent = label

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

local function refresh(counter: Counter)
	local amount = getNumber(counter.Attribute)
	counter.Label.Text = `{counter.Title}: {amount}`
	if amount > counter.Last then
		popGain(counter.Label, amount - counter.Last)
	end
	counter.Last = amount
end

-- One rounded box on the left of the screen. `yOffset` moves it up (negative) or down.
local function addCounter(gui: ScreenGui, attribute: string, title: string, color: Color3, yOffset: number)
	local label = Instance.new("TextLabel")
	label.Name = attribute
	-- Left side, a bit above the middle, so it doesn't cover the chat window.
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 16, 0.45, yOffset)
	label.Size = UDim2.fromOffset(170, 40)
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = label

	table.insert(counters, { Attribute = attribute, Title = title, Label = label, Last = 0 })
end

function HudController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	-- Embers sit just above Coins (the quest box is just below Coins).
	addCounter(gui, "Embers", "Embers", EMBER_COLOR, -46)
	addCounter(gui, "Coins", "Coins", COIN_COLOR, 0)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function HudController.start()
	for _, counter in counters do
		-- Start from the current amount so we don't "pop" the starting amount.
		counter.Last = getNumber(counter.Attribute)
		refresh(counter)
		player:GetAttributeChangedSignal(counter.Attribute):Connect(function()
			refresh(counter)
		end)
	end
end

return HudController
