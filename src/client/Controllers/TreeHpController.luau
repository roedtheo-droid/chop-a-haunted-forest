--!strict
-- The tree's health bar, like in Chop a Forest: while you aim at a tree, its name ("Oak") shows
-- just under the crosshair in white with a black outline, and under that a rounded dark bar
-- with "4.1/4.6 HP". The fill is green when the tree is healthy and turns yellow, orange and
-- red as it loses HP, and grey at 0 (Config.TreeHpBar).
-- It's off unless Config.ShowTreeHpBar is true (clean effects by default).
-- It only DISPLAYS the "HP", "MaxHP" and "TreeName" attributes the server sets on each tree.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local UiKit = require(script.Parent.Parent.UiKit)
local ChopController = require(script.Parent.ChopController)
local ViewmodelController = require(script.Parent.ViewmodelController)

local cfg = Config.TreeHpBar

local TreeHpController = {}

local player = Players.LocalPlayer
local holder: Frame? = nil -- the name and the bar; nil when the bar is switched off
local nameLabel: TextLabel
local bar: UiKit.Bar
local shownTree: Model? = nil
local shownHp = -1

local function getNumber(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

-- The tree you're aiming at (a tree, an awake mimic, or one that's falling), or nil.
-- The Elder Hollow has its own big HP bar (see BossController).
local function aimedTree(): Model?
	local result = ChopController.castAim()
	local model = if result then result.Instance:FindFirstAncestorWhichIsA("Model") else nil
	if not model or CollectionService:HasTag(model, Tags.ElderHollow) or CollectionService:HasTag(model, Tags.BossRoot) then
		return nil
	end
	if getNumber(model, "HP") and getNumber(model, "MaxHP") and model:GetAttribute("TreeName") then
		return model
	end
	return nil
end

-- The fill's colour for this share of HP left (Config.TreeHpBar.Colors), grey at 0.
local function fillColor(fraction: number): Color3
	if fraction <= 0 then
		return cfg.EmptyColor
	end
	for _, step in cfg.Colors do
		if fraction > step.Above then
			return step.Color
		end
	end
	return cfg.EmptyColor
end

local function update()
	local frame = holder
	if not frame then
		return
	end
	local tree = aimedTree()
	if not tree then
		frame.Visible = false
		shownTree = nil
		return
	end

	-- Just under the crosshair (the middle of the screen), or under the mouse.
	local at = if ViewmodelController.isActive()
		then workspace.CurrentCamera.ViewportSize / 2
		else UserInputService:GetMouseLocation()
	frame.Position = UDim2.fromOffset(at.X, at.Y + cfg.Below)
	frame.Visible = true

	local hp = math.max(getNumber(tree, "HP") or 0, 0)
	local maxHp = math.max(getNumber(tree, "MaxHP") or 1, 0.1)
	if tree ~= shownTree or hp ~= shownHp then
		nameLabel.Text = tostring(tree:GetAttribute("TreeName"))
		local fraction = hp / maxHp
		bar.Fill.BackgroundColor3 = fillColor(fraction)
		if tree ~= shownTree then
			bar.Fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) -- a new tree: no sliding
		end
		UiKit.setBar(bar, fraction, string.format(cfg.Text, hp, maxHp))
		shownTree = tree
		shownHp = hp
	end
end

function TreeHpController.init()
	if not Config.ShowTreeHpBar then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TreeHp"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- so the middle of the screen is the crosshair's middle

	local frame = Instance.new("Frame")
	frame.Name = "Holder"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Size = UDim2.fromOffset(cfg.Width, cfg.NameHeight + cfg.BarHeight + 2)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui

	nameLabel = UiKit.text(frame, "TreeName", "")
	nameLabel.Size = UDim2.new(1, 0, 0, cfg.NameHeight)

	bar = UiKit.bar(frame, "HpBar")
	bar.Frame.Position = UDim2.fromOffset(0, cfg.NameHeight + 2)
	bar.Frame.Size = UDim2.new(1, 0, 0, cfg.BarHeight)

	gui.Parent = player:WaitForChild("PlayerGui")
	holder = frame
end

function TreeHpController.start()
	if not holder then
		return
	end
	RunService.RenderStepped:Connect(update)
end

return TreeHpController
