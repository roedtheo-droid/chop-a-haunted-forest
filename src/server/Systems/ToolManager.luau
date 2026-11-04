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
local Assets = require(script.Parent.Parent.Build.Assets)

-- How each placeholder tool looks: a handle, plus a "head" stuck to it. When Theo's model of
-- the tool is imported (Config.ToolModels), the handle and head turn invisible and the model
-- is held instead, but they stay: the hand holds the handle, and the head is where the
-- Lantern's light, the Torch's fire and the Ghost Vacuum's nozzle are.
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
	-- Like the Log Vacuum's leaf blower, but pale blue and ghostly, with a dark nozzle.
	GhostVacuum = {
		HandleSize = Vector3.new(0.9, 1.1, 1.8),
		HandleColor = Color3.fromRGB(150, 205, 255),
		HeadSize = Vector3.new(0.6, 0.6, 2.4),
		HeadColor = Color3.fromRGB(70, 70, 85),
		HeadOffset = Vector3.new(0, 0.2, -2),
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

-- How part `name` of tool `toolId` is coloured: by its name without the tool's name in
-- front ("Axe_GripRidge2" -> "GripRidge2"), using the longest Paint key it starts with.
local function paintFor(cfg: Types.ToolModelConfig, toolId: string, name: string): Types.ToolPaint?
	local plain = if string.sub(name, 1, #toolId + 1) == toolId .. "_" then string.sub(name, #toolId + 2) else name
	local best: Types.ToolPaint? = nil
	local bestLength = 0
	for key, paint in cfg.Paint do
		if #key > bestLength and string.sub(plain, 1, #key) == key then
			best = paint
			bestLength = #key
		end
	end
	return best
end

-- Is `name` part `role` of tool `toolId` ("Axe_Grip" is the Axe's "Grip")?
local function isRole(toolId: string, name: string, role: string): boolean
	return name == `{toolId}_{role}` or name == role
end

-- Put Theo's model of the tool on the handle: turned so it points forward (-Z), sized,
-- with its grip part at GripAt, coloured and welded on. The head moves to the model's head
-- part. Returns false (and changes nothing) if the model isn't imported.
local function dressWithModel(tool: Tool, toolId: string, handle: Part, head: Part): boolean
	local cfg = Config.ToolModels.Tools[toolId]
	local model = if cfg then Assets.tool(toolId) else nil
	if not (cfg and model) then
		return false
	end

	-- `turn` takes a place in the imported model to the same place seen from the handle.
	local back = -cfg.Forward.Unit
	local up = cfg.Up.Unit
	local turn = CFrame.fromMatrix(Vector3.zero, up:Cross(back), up, back):Inverse()
	local _, extents = model:GetBoundingBox()
	local scale = cfg.Size / math.max(extents.X, extents.Y, extents.Z)

	local places: { [BasePart]: CFrame } = {}
	local gripAt: Vector3? = nil
	local headAt: Vector3? = nil
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local turned = turn * part.CFrame
			local place = CFrame.new(turned.Position * scale) * turned.Rotation
			places[part] = place
			if isRole(toolId, part.Name, cfg.Grip) then
				gripAt = place.Position
			end
			if isRole(toolId, part.Name, cfg.Head) then
				headAt = place.Position
			end
		end
	end
	local shift = cfg.GripAt - (gripAt or Vector3.zero)

	for part, place in places do
		part.Size *= scale
		part.CFrame = handle.CFrame * CFrame.new(shift) * place
		local paint = paintFor(cfg, toolId, part.Name)
		if paint then
			part.Color = paint.Color
			part.Material = paint.Material
			part.Transparency = paint.Transparency or 0
		end
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.Anchored = false
		part.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
	end
	model:Destroy()

	handle.Transparency = 1
	head.Transparency = 1
	head.Size = Vector3.new(0.2, 0.2, 0.2)
	head.CFrame = handle.CFrame * CFrame.new(shift + (headAt or Vector3.zero))
	return true
end

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

	local dressed = dressWithModel(tool, toolId, handle, head)

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
		local model = Config.ToolModels.Tools[toolId]
		fire.Size = if dressed and model and model.Fire then model.Fire else 2.5
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
