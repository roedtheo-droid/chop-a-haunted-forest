--!strict
-- Shows short messages from the server at the top of the screen,
-- like "Your backpack is full!".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.Parent.UiKit)

local NotifyController = {}

local player = Players.LocalPlayer
local box: Frame
local label: TextLabel
-- Goes up with every message, so an old message's timer can't hide a newer message.
local messageId = 0

local function show(message: string)
	messageId += 1
	local myId = messageId
	label.Text = message
	box.Visible = true

	task.delay(Config.UI.NotifyDuration, function()
		if messageId == myId then
			box.Visible = false
		end
	end)
end

function NotifyController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notify"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10 -- on top of other windows, like the shop

	box = UiKit.box(gui, "Message")
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 70)
	box.Size = UDim2.fromOffset(380, 40)
	box.Visible = false

	label = UiKit.text(box, "Text", "")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -20, 1, -10)

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
