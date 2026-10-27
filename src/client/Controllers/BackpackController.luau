--!strict
-- Shows "Logs 0/5" at the bottom of the screen.
-- It only DISPLAYS the Carry and CarryLimit attributes the server sets on the player.

local Players = game:GetService("Players")

local NORMAL_COLOR = Color3.fromRGB(255, 255, 255)
local FULL_COLOR = Color3.fromRGB(255, 120, 100)

local BackpackController = {}

local player = Players.LocalPlayer
local label: TextLabel

local function getNumberAttribute(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refresh()
	local carry = getNumberAttribute("Carry")
	local limit = getNumberAttribute("CarryLimit")
	label.Text = `Logs {carry}/{limit}`
	label.TextColor3 = if limit > 0 and carry >= limit then FULL_COLOR else NORMAL_COLOR
end

function BackpackController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Backpack"
	gui.ResetOnSpawn = false -- keep the counter when the character respawns

	label = Instance.new("TextLabel")
	label.Name = "Counter"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -16)
	label.Size = UDim2.fromOffset(170, 44)
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	label.BackgroundTransparency = 0.3
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

	gui.Parent = player:WaitForChild("PlayerGui")
end

function BackpackController.start()
	refresh()
	player:GetAttributeChangedSignal("Carry"):Connect(refresh)
	player:GetAttributeChangedSignal("CarryLimit"):Connect(refresh)
end

return BackpackController
