--!strict
-- Shows short messages from the server on a small plank under the zone sign,
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

-- Show a message from this computer (the server's messages come through the Notify remote).
function NotifyController.show(message: string)
	show(message)
end

function NotifyController.init()
	local gui = UiKit.screen("Notify")
	gui.DisplayOrder = 10 -- on top of other windows, like the shop

	-- Sizes in pixels on a 1080p screen.
	box = UiKit.plank(gui, "Message", 1)
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, Config.Hud.MessageY)
	box.Size = UDim2.fromOffset(Config.UI.NotifyWidth, Config.UI.NotifyHeight)
	box.Visible = false

	label = UiKit.text(box, "Text", "")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -2 * Config.TimberUi.NailInset - 20, 1, -10)
	label.TextWrapped = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = Config.UI.NotifyText
	limit.Parent = label

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
