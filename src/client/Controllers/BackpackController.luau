--!strict
-- Shows "Logs 0/5" at the bottom of the screen.
-- It only DISPLAYS the Carry and CarryLimit attributes the server sets on the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local UiKit = require(script.Parent.Parent.UiKit)

local NORMAL_COLOR = Color3.new(1, 1, 1)

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
	label.TextColor3 = if limit > 0 and carry >= limit then Config.Style.Red else NORMAL_COLOR
end

function BackpackController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Backpack"
	gui.ResetOnSpawn = false -- keep the counter when the character respawns

	local box = UiKit.box(gui, "Counter")
	box.AnchorPoint = Vector2.new(0.5, 1)
	-- Bottom middle, just above Roblox's tool bar (about 64 pixels tall), so tools don't cover it.
	box.Position = UDim2.new(0.5, 0, 1, -72)
	box.Size = UDim2.fromOffset(170, 44)

	label = UiKit.text(box, "Text", "")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -16, 1, -12)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function BackpackController.start()
	refresh()
	player:GetAttributeChangedSignal("Carry"):Connect(refresh)
	player:GetAttributeChangedSignal("CarryLimit"):Connect(refresh)
end

return BackpackController
