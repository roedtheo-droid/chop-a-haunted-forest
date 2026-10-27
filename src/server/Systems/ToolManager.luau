--!strict
-- Gives players the tools they bought and says which tool a player is holding.
--
-- Tools are real Roblox Tools, so the built-in toolbar gives number keys (1, 2, 3)
-- and phone buttons for free. Each Tool has a "ToolId" attribute (like "Axe").
-- Ownership is a player attribute ("Owns_Axe" = true) that only the server sets,
-- and the server only trusts a held tool if the player owns it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Types = require(ReplicatedStorage.Shared.Types)

-- How each placeholder tool looks: a handle, plus an optional "head" stuck to it.
type Look = {
	HandleSize: Vector3,
	HandleColor: Color3,
	HeadSize: Vector3,
	HeadColor: Color3,
	HeadOffset: Vector3, -- where the head sits, relative to the handle
}

local WOOD = Color3.fromRGB(120, 80, 50)
local LOOKS: { [string]: Look } = {
	Axe = {
		HandleSize = Vector3.new(0.3, 0.3, 3.5),
		HandleColor = WOOD,
		HeadSize = Vector3.new(0.3, 1.4, 1),
		HeadColor = Color3.fromRGB(110, 110, 115),
		HeadOffset = Vector3.new(0, 0.5, -1.4),
	},
	SteelAxe = {
		HandleSize = Vector3.new(0.35, 0.35, 4),
		HandleColor = Color3.fromRGB(60, 45, 35),
		HeadSize = Vector3.new(0.35, 1.9, 1.4),
		HeadColor = Color3.fromRGB(200, 210, 220),
		HeadOffset = Vector3.new(0, 0.6, -1.6),
	},
	Chainsaw = {
		HandleSize = Vector3.new(0.8, 1, 2),
		HandleColor = Color3.fromRGB(230, 120, 30),
		HeadSize = Vector3.new(0.2, 0.6, 2.6),
		HeadColor = Color3.fromRGB(90, 90, 95),
		HeadOffset = Vector3.new(0, 0, -2.2),
	},
}

local ToolManager = {}

local function buildTool(toolId: string): Tool
	local item = Shop.getItem(toolId)
	local look = LOOKS[toolId]

	local tool = Instance.new("Tool")
	tool.Name = if item then item.Name else toolId
	tool.ToolTip = if item then item.Description else ""
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ToolId", toolId)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = look.HandleSize
	handle.Color = look.HandleColor
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = look.HeadSize
	head.Color = look.HeadColor
	head.Material = Enum.Material.Metal
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(look.HeadOffset)
	head.Parent = tool

	-- Glue the head to the handle so they move together.
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle

	return tool
end

function ToolManager.owns(player: Player, toolId: string): boolean
	return player:GetAttribute(Shop.ownsAttribute(toolId)) == true
end

-- Give a player a tool for good: now, and again every time they respawn.
function ToolManager.give(player: Player, toolId: string)
	if not LOOKS[toolId] then
		return
	end
	player:SetAttribute(Shop.ownsAttribute(toolId), true)

	-- StarterGear is copied into the Backpack every time the character spawns.
	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		buildTool(toolId).Parent = starterGear
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		buildTool(toolId).Parent = backpack
	end
end

-- Which tool is the player holding right now? "Fists" if none (or one they don't own).
function ToolManager.getEquippedId(player: Player): string
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	if not tool then
		return "Fists"
	end
	local toolId = tool:GetAttribute("ToolId")
	if typeof(toolId) == "string" and Config.Tools[toolId] and ToolManager.owns(player, toolId) then
		return toolId
	end
	return "Fists"
end

function ToolManager.getStats(player: Player): Types.ToolConfig
	return Config.Tools[ToolManager.getEquippedId(player)]
end

function ToolManager.init() end

function ToolManager.start() end

return ToolManager
