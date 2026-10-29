--!strict
-- Shows the player's Coins and Embers on the left side of the screen: a round icon and the
-- number, with a small "+15" that floats up when one of them goes up. During a tool trial,
-- "TRIAL 2:59" shows under the coins.
-- It only DISPLAYS the attributes the server sets on the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local UiKit = require(script.Parent.Parent.UiKit)

local POP_TIME = 0.9
local ICON_SIZE = 40

local HudController = {}

type Counter = {
	Attribute: string, -- the player attribute it shows, like "Coins"
	Label: TextLabel,
	Last: number, -- the amount it showed last time, to know how much it went up
}

local player = Players.LocalPlayer
local counters: { Counter } = {}
local trialLabel: TextLabel

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- A "+N" label that floats up and fades out, then removes itself.
local function popGain(label: TextLabel, amount: number)
	local pop = UiKit.text(label, "Pop", `+{amount}`, label.TextColor3)
	pop.AnchorPoint = Vector2.new(0, 0.5)
	pop.Position = UDim2.new(1, 8, 0.5, 0)
	pop.Size = UDim2.fromOffset(90, 30)
	pop.TextXAlignment = Enum.TextXAlignment.Left
	-- Fade the outline together with the text.
	local stroke = pop:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(POP_TIME), { Transparency = 1 }):Play()
	end

	local tween = TweenService:Create(pop, TweenInfo.new(POP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, 8, 0.5, -30),
		TextTransparency = 1,
	})
	tween.Completed:Connect(function()
		pop:Destroy()
	end)
	tween:Play()
end

local function refresh(counter: Counter)
	local amount = getNumber(counter.Attribute)
	counter.Label.Text = tostring(amount)
	if amount > counter.Last then
		popGain(counter.Label, amount - counter.Last)
		UiKit.bounce(counter.Label)
	end
	counter.Last = amount
end

-- An icon and a number on the left of the screen. `yOffset` moves it up (negative) or down.
local function addCounter(gui: ScreenGui, attribute: string, color: Color3, yOffset: number)
	local holder = Instance.new("Frame")
	holder.Name = attribute
	-- Left side, a bit above the middle, so it doesn't cover the chat window.
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, 16, 0.45, yOffset)
	holder.Size = UDim2.fromOffset(170, ICON_SIZE)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	local icon = if attribute == "Embers" then UiKit.ember(holder, "Icon") else UiKit.coin(holder, "Icon")
	icon.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)

	local label = UiKit.text(holder, "Amount", "0", color)
	label.Position = UDim2.fromOffset(ICON_SIZE + 8, 2)
	label.Size = UDim2.new(1, -(ICON_SIZE + 8), 1, -4)
	label.TextXAlignment = Enum.TextXAlignment.Left

	table.insert(counters, { Attribute = attribute, Label = label, Last = 0 })
end

-- "TRIAL 2:59" under the coins while you're trying a tool from the trial table. The server
-- sets when the trial ends (Shop.TRIAL_ENDS, in server time) and removes it when it's over.
local function addTrialTimer(gui: ScreenGui)
	trialLabel = UiKit.text(gui, "Trial", "", Config.Style.Ember)
	trialLabel.Position = UDim2.new(0, 16, 0.45, 24)
	trialLabel.Size = UDim2.fromOffset(170, 26)
	trialLabel.TextXAlignment = Enum.TextXAlignment.Left
	trialLabel.Visible = false
end

local function updateTrialTimer()
	local ends = player:GetAttribute(Shop.TRIAL_ENDS)
	if typeof(ends) ~= "number" then
		trialLabel.Visible = false
		return
	end
	local left = math.max(0, math.floor(ends - workspace:GetServerTimeNow()))
	trialLabel.Text = string.format(Config.Trial.Text.Hud, left // 60, left % 60)
	trialLabel.Visible = true
end

function HudController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	-- Embers sit just above Coins (the quest box is just below Coins).
	addCounter(gui, "Embers", Config.Style.Ember, -46)
	addCounter(gui, "Coins", Config.Style.Gold, 0)
	addTrialTimer(gui)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function HudController.start()
	RunService.Heartbeat:Connect(updateTrialTimer)
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
