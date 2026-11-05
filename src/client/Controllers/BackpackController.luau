--!strict
-- The tool bar at the bottom middle of the screen, like Chop a Forest's: no boxes, just a
-- picture of each tool with a small number above it. "1" is your fists (hold nothing), then
-- your tools in the Tool Shed's order. The one you hold is a bit bigger. It replaces Roblox's
-- own tool bar. Sizes are in Config.Hud (pixels on a 1080p screen, see UiKit.hudScale).
-- Press a number key (1-9) or click/tap a picture to hold that tool; again to put it away.
--
-- The tool pictures are little 3D views (ViewportFrames) of the tool itself, so they look just
-- like the models Theo imported.
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
local Icons = require(script.Parent.Parent.Icons)
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
	Picture: Frame, -- holds the fist icon or the tool's 3D view
	Tool: Tool?, -- the tool shown (nil for the fists)
}

local player = Players.LocalPlayer
local bar: Frame
local slots: { Slot } = {}
local tools: { Tool } = {} -- your tools, in slot order (slot 2 is tools[1])
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

-- A little 3D view of a tool: copies of its visible parts, with a camera looking at them.
local function toolPicture(tool: Tool): ViewportFrame
	local view = Instance.new("ViewportFrame")
	view.Name = "Picture"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.LightDirection = Vector3.new(-1, -1.5, -1)
	view.Ambient = Color3.fromRGB(170, 170, 170)

	local model = Instance.new("Model")
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local copy = part:Clone()
			copy:ClearAllChildren()
			-- Keep what gives the part its look (meshes, textures, decals).
			for _, child in part:GetChildren() do
				if child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
					child:Clone().Parent = copy
				end
			end
			copy.Anchored = true
			copy.Parent = model
		end
	end
	model.Parent = view

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	if #model:GetChildren() > 0 then
		local boxCFrame, boxSize = model:GetBoundingBox()
		local radius = boxSize.Magnitude / 2
		local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
		local center = boxCFrame.Position
		camera.CFrame = CFrame.lookAt(center + Hud.ToolCameraAngle.Unit * distance, center)
	end
	return view
end

local function makeSlot(index: number): Slot
	local button = Instance.new("TextButton")
	button.Name = `Slot{index}`
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.LayoutOrder = index
	button.Size = UDim2.fromOffset(Hud.SlotIcon, Hud.SlotIcon + Hud.SlotNumberText)

	local number = UiKit.smallText(button, "Number", tostring(index))
	number.AnchorPoint = Vector2.new(0.5, 0)
	number.Position = UDim2.fromScale(0.5, 0)
	number.Size = UDim2.new(1, 0, 0, Hud.SlotNumberText)

	local picture = Instance.new("Frame")
	picture.Name = "PictureHolder"
	picture.BackgroundTransparency = 1
	picture.AnchorPoint = Vector2.new(0.5, 1)
	picture.Position = UDim2.fromScale(0.5, 1)
	picture.Size = UDim2.new(1, 0, 1, -Hud.SlotNumberText)
	picture.Parent = button

	button.Activated:Connect(function()
		toggle(index)
	end)

	button.Parent = bar
	return { Button = button, Number = number, Picture = picture, Tool = nil }
end

-- Put the right picture in a slot (only when the tool in it changed).
local function setPicture(slot: Slot, tool: Tool?)
	if slot.Tool == tool and #slot.Picture:GetChildren() > 0 then
		return
	end
	slot.Tool = tool
	slot.Picture:ClearAllChildren()
	if tool then
		toolPicture(tool).Parent = slot.Picture
	else
		local fist = Icons.fist(slot.Picture, "Fist")
		fist.AnchorPoint = Vector2.new(0.5, 0.5)
		fist.Position = UDim2.fromScale(0.5, 0.5)
		fist.Size = UDim2.fromScale(0.8, 0.8)
	end
end

local function refresh()
	refreshQueued = false
	tools = collectTools()
	local held = heldTool()
	local count = math.min(#tools + 1, Hud.MaxSlots) -- +1: the fists

	for index = 1, count do
		local slot = slots[index]
		local tool = if index == 1 then nil else tools[index - 1]
		setPicture(slot, tool)
		slot.Button.Visible = true
		-- The one you hold is bigger (the fists when you hold nothing).
		local isHeld = if index == 1 then held == nil else tool == held
		local size = if isHeld then Hud.SelectedSize else Hud.SlotIcon
		slot.Button.Size = UDim2.fromOffset(size, size + Hud.SlotNumberText)
		slot.Number.TextColor3 = if isHeld then Config.Style.Gold else Color3.new(1, 1, 1)
	end
	for index = count + 1, #slots do
		slots[index].Button.Visible = false
		setPicture(slots[index], nil)
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

-- Slot 1 puts your tool away. Any other slot holds that tool, or puts it away if you hold it.
function toggle(index: number)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (humanoid and humanoid.Health > 0) then
		return
	end
	if index == 1 then
		humanoid:UnequipTools()
		return
	end
	local tool = tools[index - 1]
	if not tool then
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

	bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -Hud.Margin)
	bar.Size = UDim2.fromOffset(Hud.MaxSlots * (Hud.SelectedSize + Hud.SlotGap), Hud.SelectedSize + Hud.SlotNumberText)
	bar.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Hud.SlotGap)
	layout.Parent = bar

	for index = 1, Hud.MaxSlots do
		table.insert(slots, makeSlot(index))
	end

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
