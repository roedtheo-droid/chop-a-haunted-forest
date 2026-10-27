--!strict
-- Shows short messages from the server at the top of the screen,
-- like "Your backpack is full!".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local NotifyController = {}

local player = Players.LocalPlayer
local label: TextLabel
-- Goes up with every message, so an old message's timer can't hide a newer message.
local messageId = 0

local function show(message: string)
	messageId += 1
	local myId = messageId
	label.Text = message
	label.Visible = true

	task.delay(Config.UI.NotifyDuration, function()
		if messageId == myId then
			label.Visible = false
		end
	end)
end

function NotifyController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notify"
	gui.ResetOnSpawn = false

	label = Instance.new("TextLabel")
	label.Name = "Message"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 70)
	label.Size = UDim2.fromOffset(360, 40)
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Visible = false
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	gui.Parent = player:WaitForChild("PlayerGui")
end

function NotifyController.start()
	Remotes.getEvent("Notify").OnClientEvent:Connect(function(message: unknown)
		if typeof(message) == "string" then
			show(message)
		end
	end)
end

return NotifyController
