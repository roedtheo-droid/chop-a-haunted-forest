--!strict
-- Gives players the tools they bought and says which tool a player is holding.
--
-- Tools are real Roblox Tools, so the built-in toolbar gives number keys (1, 2, 3)
-- and phone buttons for free. Each Tool has a "ToolId" attribute (like "Axe").
-- Ownership is a player attribute ("Owns_Axe" = true) that only the server sets,
-- and the server only trusts a held tool if the player owns it (or is trying it: a tool lent
-- by the trial table has a "Trial" attribute and is taken back when the trial ends).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Types = require(ReplicatedStorage.Shared.Types)

-- How each placeholder tool looks: a handle, plus a "head" stuck to it.
type Look = {
	HandleSize: Vector3,
	HandleColor: Color3,
	HeadSize: Vector3,
	HeadColor: Color3,
	HeadOffset: Vector3, -- where the head sits, relative to the handle
	HeadMaterial: Enum.Material?, -- Metal if not set
	Light: boolean?, -- the head glows and lights up the ground (Lantern)
	Flame: boolean?, -- the head is on fire (Torch)
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
	Lantern = {
		HandleSize = Vector3.new(0.2, 0.2, 1.2),
		HandleColor = Color3.fromRGB(50, 50, 55),
		HeadSize = Vector3.new(0.9, 1.2, 0.9),
		HeadColor = Color3.fromRGB(255, 200, 120),
		HeadOffset = Vector3.new(0, -0.3, -1),
		HeadMaterial = Enum.Material.Neon,
		Light = true,
	},
	Torch = {
		HandleSize = Vector3.new(0.3, 0.3, 3),
		HandleColor = WOOD,
		HeadSize = Vector3.new(0.5, 0.5, 0.7),
		HeadColor = Color3.fromRGB(40, 30, 25),
		HeadOffset = Vector3.new(0, 0, -1.7),
		HeadMaterial = Enum.Material.Fabric,
		Flame = true,
	},
}

-- Things that are only ever shown on the Tool Shed's walls, never held (the Log Vacuum is an
-- upgrade): a green body like a leaf blower, with a grey nozzle.
local DISPLAY_LOOKS: { [string]: Look } = {
	LogVacuum = {
		HandleSize = Vector3.new(0.9, 1.1, 1.8),
		HandleColor = Color3.fromRGB(80, 170, 70),
		HeadSize = Vector3.new(0.55, 0.55, 2.4),
		HeadColor = Color3.fromRGB(120, 125, 130),
		HeadOffset = Vector3.new(0, 0.2, -2),
	},
}

local ToolManager = {}

local function buildTool(toolId: string): Tool
	local item = Shop.getItem(toolId)
	local look = LOOKS[toolId] or DISPLAY_LOOKS[toolId]

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
	head.Material = look.HeadMaterial or Enum.Material.Metal
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(look.HeadOffset)
	head.Parent = tool

	if look.Light then
		local light = Instance.new("PointLight")
		light.Color = look.HeadColor
		light.Range = Config.Lantern.LightRange
		light.Brightness = 1.5
		light.Shadows = true
		light.Parent = head
	end
	if look.Flame then
		local fire = Instance.new("Fire")
		fire.Size = 2.5
		fire.Heat = 6
		fire.Parent = head
	end

	-- Glue the head to the handle so they move together.
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle

	return tool
end

-- The look of a tool (its handle and head, anchored, in a Model) without the Tool itself,
-- for hanging on the Tool Shed's walls (see Build/ShedDisplays). Its pivot is the handle.
function ToolManager.buildDisplay(toolId: string): Model
	local tool = buildTool(toolId)
	local display = Instance.new("Model")
	display.Name = tool.Name
	for _, part in tool:GetChildren() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.Parent = display
		end
	end
	tool:Destroy()
	display.PrimaryPart = display:FindFirstChild("Handle") :: BasePart
	return display
end

function ToolManager.owns(player: Player, toolId: string): boolean
	return player:GetAttribute(Shop.ownsAttribute(toolId)) == true
end

-- Is the player trying this tool right now (the trial table, see TrialManager)?
function ToolManager.hasTrial(player: Player, toolId: string): boolean
	local ends = player:GetAttribute(Shop.TRIAL_ENDS)
	return player:GetAttribute(Shop.TRIAL_TOOL) == toolId
		and typeof(ends) == "number"
		and workspace:GetServerTimeNow() < ends
end

-- Take away the copies of a tool that were only lent for a trial (in the backpack, in the
-- character's hand, and in StarterGear so it doesn't come back on respawn).
local function removeTrialCopies(player: Player, toolId: string)
	for _, place in { player:FindFirstChild("Backpack"), player.Character, player:FindFirstChild("StarterGear") } :: { Instance? } do
		for _, tool in if place then place:GetChildren() else {} do
			if tool:IsA("Tool") and tool:GetAttribute("ToolId") == toolId and tool:GetAttribute("Trial") == true then
				tool:Destroy()
			end
		end
	end
end

-- Lend a player a tool for `seconds`: now, and on respawn until the trial ends (TrialManager
-- ends it with endTrial).
function ToolManager.giveTrial(player: Player, toolId: string, seconds: number): number
	local ends = workspace:GetServerTimeNow() + seconds
	removeTrialCopies(player, toolId)
	player:SetAttribute(Shop.TRIAL_TOOL, toolId)
	player:SetAttribute(Shop.TRIAL_ENDS, ends)
	for _, name in { "StarterGear", "Backpack" } do
		local place = player:FindFirstChild(name)
		if place then
			local tool = buildTool(toolId)
			tool:SetAttribute("Trial", true)
			tool.Parent = place
		end
	end
	return ends
end

-- The trial is over: take the lent tool back (a bought one stays).
function ToolManager.endTrial(player: Player)
	local toolId = player:GetAttribute(Shop.TRIAL_TOOL)
	player:SetAttribute(Shop.TRIAL_TOOL, nil)
	player:SetAttribute(Shop.TRIAL_ENDS, nil)
	if typeof(toolId) == "string" then
		removeTrialCopies(player, toolId)
	end
end

-- Give a player a tool for good: now, and again every time they respawn.
function ToolManager.give(player: Player, toolId: string)
	if not LOOKS[toolId] then
		return
	end
	-- Bought it during a trial: the lent copies go, so there's only one in the backpack.
	if player:GetAttribute(Shop.TRIAL_TOOL) == toolId then
		ToolManager.endTrial(player)
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

-- Which tool is the player holding right now? "Fists" if none (or one they don't own and
-- aren't trying).
function ToolManager.getEquippedId(player: Player): string
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	if not tool then
		return "Fists"
	end
	local toolId = tool:GetAttribute("ToolId")
	if typeof(toolId) == "string" and Config.Tools[toolId] and (ToolManager.owns(player, toolId) or ToolManager.hasTrial(player, toolId)) then
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
