--!strict
-- The tool bar at the bottom middle of the screen (the purple HUD, see Config.Hud). It replaces
-- Roblox's own tool bar: one numbered slot for every tool in your backpack, in the Tool Shed's
-- order, with the held tool's name above the bar.
-- Press a number key (1-9) or click/tap a slot to hold that tool; do it again to put it away.
--
-- Holding a tool works the same way Roblox's own bar does it: your computer moves the Tool from
-- your Backpack into your character (Humanoid:EquipTool) and Roblox tells the server. The server
-- still decides everything a tool does, so this can't be used to cheat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local UiKit = require(script.Parent.Parent.UiKit)

local Hud = Config.Hud

local NUMBER_KEYS: { Enum.KeyCode } = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local BackpackController = {}

type Slot = {
	Button: TextButton,
	Number: TextLabel,
	Icon: Frame,
	Letter: TextLabel,
	Name: TextLabel,
	Border: UIStroke,
}

local player = Players.LocalPlayer
local bar: Frame
local nameTag: Frame
local nameLabel: TextLabel
local slots: { Slot } = {}
local tools: { Tool } = {} -- the tool in each slot, in slot order
local watched: { RBXScriptConnection } = {} -- the Backpack's and character's events
local refreshQueued = false
local toggle: (index: number) -> () -- written further down

-- The tool's id (like "SteelAxe"). Our tools carry it (see Server/Systems/ToolManager).
local function toolId(tool: Tool): string
	local id = tool:GetAttribute("ToolId")
	return if typeof(id) == "string" then id else tool.Name
end

-- Where a tool goes in the bar: the Tool Shed's order, unknown tools at the end.
local order: { [string]: number } = {}
for index, item in Shop.Items do
	order[item.Id] = index
end

local function heldTool(): Tool?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Tool") else nil
end

-- Every tool you have: the ones in your Backpack and the one in your hand.
local function collectTools(): { Tool }
	local list: { Tool } = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") then
				table.insert(list, child)
			end
		end
	end
	local held = heldTool()
	if held then
		table.insert(list, held)
	end
	table.sort(list, function(a: Tool, b: Tool): boolean
		local orderA = order[toolId(a)] or math.huge
		local orderB = order[toolId(b)] or math.huge
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a.Name < b.Name
	end)
	return list
end

local function makeSlot(index: number): Slot
	local button = Instance.new("TextButton")
	button.Name = `Slot{index}`
	button.Text = ""
	button.AutoButtonColor = false
	button.LayoutOrder = index
	button.BackgroundColor3 = Hud.Track
	button.Size = UDim2.fromOffset(Hud.SlotSize, Hud.SlotSize)
	UiKit.corner(button, 10)
	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = Hud.Edge
	border.Thickness = Hud.EdgeThickness
	border.Parent = button

	local number = UiKit.hudText(button, "Number", tostring(index), 11, Hud.Muted)
	number.Position = UDim2.fromOffset(6, 3)
	number.Size = UDim2.fromOffset(12, 12)
	number.TextXAlignment = Enum.TextXAlignment.Left

	local iconSize = math.floor(Hud.SlotSize * 0.4)
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 9)
	icon.Size = UDim2.fromOffset(iconSize, iconSize)
	UiKit.corner(icon, 6)
	icon.Parent = button

	local letter = UiKit.hudText(icon, "Letter", "", 15, Hud.Panel)
	letter.Size = UDim2.fromScale(1, 1)
	local stroke = letter:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Enabled = false
	end

	local name = UiKit.hudText(button, "Name", "", 12)
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -6)
	name.Size = UDim2.new(1, -4, 0, 14)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	button.Activated:Connect(function()
		toggle(index)
	end)

	button.Parent = bar
	return { Button = button, Number = number, Icon = icon, Letter = letter, Name = name, Border = border }
end

local function refresh()
	refreshQueued = false
	tools = collectTools()
	local held = heldTool()
	local count = math.min(#tools, Hud.MaxSlots)

	for index = 1, count do
		local slot = slots[index]
		local tool = tools[index]
		local look = Hud.ToolLooks[toolId(tool)]
		slot.Button.Visible = true
		slot.Icon.BackgroundColor3 = if look then look.Color else Hud.OtherToolColor
		slot.Letter.Text = if look then look.Letter else string.upper(string.sub(tool.Name, 1, 1))
		slot.Name.Text = if look then look.Short else tool.Name
		local isHeld = tool == held
		slot.Border.Color = if isHeld then Hud.Orange else Hud.Edge
		slot.Border.Thickness = if isHeld then 3 else Hud.EdgeThickness
		slot.Button.BackgroundColor3 = if isHeld then Hud.Edge else Hud.Track
	end
	for index = count + 1, #slots do
		slots[index].Button.Visible = false
	end

	local width = count * Hud.SlotSize + math.max(count - 1, 0) * Hud.SlotGap + 2 * 10
	bar.Size = UDim2.fromOffset(width, Hud.SlotSize + 2 * 10)
	bar.Visible = count > 0

	nameTag.Visible = held ~= nil
	if held then
		nameLabel.Text = held.Name
	end
end

-- Tools move between the Backpack and your hand a lot; redraw once, after they've all moved.
local function queueRefresh()
	if not refreshQueued then
		refreshQueued = true
		task.defer(refresh)
	end
end

-- Watch the Backpack and the character for tools coming and going. Both are new after a respawn.
local function watch()
	for _, connection in watched do
		connection:Disconnect()
	end
	table.clear(watched)
	for _, holder in { player:FindFirstChildOfClass("Backpack"), player.Character } :: { Instance? } do
		if holder then
			table.insert(watched, holder.ChildAdded:Connect(queueRefresh))
			table.insert(watched, holder.ChildRemoved:Connect(queueRefresh))
		end
	end
	queueRefresh()
end

-- Hold the tool in slot `index`, or put it away if you're already holding it.
function toggle(index: number)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local tool = tools[index]
	if not (humanoid and tool and humanoid.Health > 0) then
		return
	end
	if tool.Parent == character then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
end

function BackpackController.init()
	-- Our bar replaces Roblox's. (Do it before the intro and the Garage, which hide Roblox's
	-- menus and show them again afterwards: they only show again what was on.)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ToolBar"
	gui.ResetOnSpawn = false
	UiKit.hudScale(gui)

	bar = UiKit.hudPanel(gui, "Bar")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -Hud.Margin)
	bar.Visible = false

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Hud.SlotGap)
	layout.Parent = bar

	for index = 1, Hud.MaxSlots do
		table.insert(slots, makeSlot(index))
	end

	-- The held tool's name, in a small dark pill just above the bar.
	nameTag = UiKit.hudPanel(gui, "HeldName", 999)
	nameTag.AnchorPoint = Vector2.new(0.5, 1)
	nameTag.Position = UDim2.new(0.5, 0, 1, -(Hud.Margin + Hud.SlotSize + 2 * 10 + 8))
	nameTag.Size = UDim2.fromOffset(0, 26)
	nameTag.AutomaticSize = Enum.AutomaticSize.X -- as wide as the name
	nameTag.Visible = false
	local namePadding = Instance.new("UIPadding")
	namePadding.PaddingLeft = UDim.new(0, 14)
	namePadding.PaddingRight = UDim.new(0, 14)
	namePadding.Parent = nameTag
	nameLabel = UiKit.hudText(nameTag, "Text", "", 16)
	nameLabel.Size = UDim2.fromOffset(0, 26)
	nameLabel.AutomaticSize = Enum.AutomaticSize.X

	gui.Parent = player:WaitForChild("PlayerGui")
end

function BackpackController.start()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		-- gameProcessed is true while you type in the chat.
		if gameProcessed then
			return
		end
		local index = table.find(NUMBER_KEYS, input.KeyCode)
		if index then
			toggle(index)
		end
	end)

	player.CharacterAdded:Connect(watch)
	player.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Backpack") then
			watch()
		end
	end)
	watch()
end

return BackpackController
