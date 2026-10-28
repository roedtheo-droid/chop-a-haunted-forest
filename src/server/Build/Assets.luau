--!strict
-- Models made in Blender (see the blender/ folder). Theo imports them into Studio and puts
-- them in ServerStorage > MapAssets (Config.Models.Folder): either AllModels.fbx, which holds
-- every model in one file, or one .fbx per model. Builders ask for a model by name: when it's
-- there they get a copy, and when it isn't they get nil and build the old Parts version
-- instead. So the game always works, even before any model is imported.
--
-- Why ServerStorage? Rojo only syncs the folders in default.project.json, so imported models
-- stay safe in the place, and only the server can see them (players get the built copies).
--
-- Used by Blocky (trees and the chop notch), Props (rocks and pebbles), Ground, CampManager
-- (the river banks), Edges and SceneryManager (hills and mountains).
-- It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local Assets = {}

-- Which models we've already reported in the Output window (once each).
local reported: { [string]: boolean } = {}

local function report(name: string, found: boolean)
	if reported[name] or not Config.DebugPrints then
		return
	end
	reported[name] = true
	if found then
		print(`[Assets] Using the Blender model "{name}"`)
	else
		print(`[Assets] No "{name}" in ServerStorage.{Config.Models.Folder} yet: using parts instead`)
	end
end

-- In AllModels.fbx every part is named "<Model>__<Part>" ("Oak__Trunk"). Which parts belong
-- to which model, worked out the first time it's needed.
local bundled: { [string]: { BasePart } }? = nil

local function bundle(folder: Instance): { [string]: { BasePart } }
	if bundled then
		return bundled
	end
	local index: { [string]: { BasePart } } = {}
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- Not anchored to the start, in case Studio adds the file's name in front.
			local model = string.match(descendant.Name, "(%w+)__.")
			if model then
				index[model] = index[model] or {}
				table.insert(index[model], descendant)
			end
		end
	end
	bundled = index
	return index
end

-- The parts of model `name` to copy: the model on its own in the folder, or its parts in
-- AllModels. nil if it isn't imported.
local function template(name: string): { BasePart }?
	local folder = ServerStorage:FindFirstChild(Config.Models.Folder)
	local parts: { BasePart } = {}
	local model = if folder then folder:FindFirstChild(name) else nil
	if model then
		if model:IsA("BasePart") then
			table.insert(parts, model)
		end
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	elseif folder then
		parts = bundle(folder)[name] or parts
	end
	report(name, #parts > 0)
	return if #parts > 0 then parts else nil
end

-- The names the game looks for.
local ROLES = {
	"BarkBlock",
	"LeafBlock",
	"Leaves",
	"Trunk",
	"Branch",
	"Root",
	"Moss",
	"Twig",
	"Roof",
	"Sign",
	"Lamp",
	"Iron",
	"Rock",
	"Patch",
	"Pebble",
	"Sand",
	"Stone",
	"Hedge",
	"Log",
	"Mountain",
	"Snow",
	"Hill",
	"Grove",
	"Bush",
	"Berry",
	"Rings",
	"Post",
	"Lantern",
	"Rail",
	"Pumpkin",
	"Stem",
	"Mound",
	"Reed",
	"Cattail",
	"Pad",
	"Flower",
	"Middle",
	"Grass",
	"Bloom",
	"Frond",
	"Cap",
	"Dot",
	"Leaf",
	"Bone",
	"Canvas",
	"Door",
	"Wood",
	"Rope",
	"Step",
	"Deck",
	"Hull",
	"Trim",
	"Oar",
	"Tower",
	"Dark",
	"Spar",
	"Sail",
	"Hub",
	"Glow",
	"Front",
	"Chunk",
	"Seat",
	"Leg",
	"Board",
	"Tip",
	"Note",
	"Pin",
	"Water",
	"Bucket",
	"Metal",
	"Ash",
	"Frame",
}

-- Blender can't give two objects the same name, so they're numbered ("LeafBlock_2"), and
-- Studio sometimes adds the file's name too ("Oak_LeafBlock_2", "StoneGatehouse_Iron"), or
-- it's from AllModels ("Oak__LeafBlock_2"). The game wants the plain name: "LeafBlock",
-- "Iron". The name it ends with wins, so "StoneGatehouse_Iron" is "Iron", not "Stone".
local function plainName(name: string): string
	local trimmed = string.gsub(name, "[%._%d]+$", "")
	for _, role in ROLES do
		if string.sub(trimmed, -#role) == role then
			return role
		end
	end
	for _, role in ROLES do
		if string.find(name, role, 1, true) then
			return role
		end
	end
	return string.match(name, "^%a+") or name
end

-- Is model `name` imported?
function Assets.has(name: string): boolean
	return template(name) ~= nil
end

-- One of `names` that is imported, picked at random, or nil if none of them is.
function Assets.pick(names: { string }, random: Random): string?
	local found: { string } = {}
	for _, name in names do
		if Assets.has(name) then
			table.insert(found, name)
		end
	end
	return if #found > 0 then found[random:NextInteger(1, #found)] else nil
end

-- A copy of model `name`: a Model holding its parts directly (however Studio nested them
-- when importing), each anchored and named plainly ("Trunk", "Leaves", "LeafBlock", "Root",
-- "Rock", "Moss"...). Not parented. nil if the model isn't imported.
-- The parts keep their imported size: the caller scales the model (Model:ScaleTo) and
-- moves it (Model:PivotTo), and colours each part.
function Assets.model(name: string): Model?
	local sources = template(name)
	if not sources then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name
	for _, source in sources do
		local part = source:Clone()
		if not part:IsA("BasePart") then
			continue
		end
		for _, child in part:GetChildren() do
			-- Pictures and joints from the import would fight the colours and welds we set,
			-- and a part inside this part gets copied on its own.
			if
				child:IsA("SurfaceAppearance")
				or child:IsA("Decal")
				or child:IsA("JointInstance")
				or child:IsA("WeldConstraint")
				or child:IsA("BasePart")
			then
				child:Destroy()
			end
		end
		if part:IsA("MeshPart") then
			part.TextureID = "" -- so the part's Color shows
		end
		part.Name = plainName(part.Name)
		part.Anchored = true
		part.Parent = model
	end
	return model
end

-- A copy of the first part in model `name` (for one-part models like the bark block).
-- Not parented. nil if the model isn't imported.
function Assets.part(name: string): BasePart?
	local model = Assets.model(name)
	if not model then
		return nil
	end
	local part = model:FindFirstChildWhichIsA("BasePart")
	if part then
		part.Parent = nil
	end
	model:Destroy()
	return part
end

-- Scale `model` so `reference` (one of its parts) is `width` studs wide, then stand it
-- with the bottom middle of `reference` on `base`, turned by `turn` (a rotation).
-- The model's pivot ends up at `base`, turned the same way.
function Assets.fit(model: Model, reference: BasePart, width: number, base: Vector3, turn: CFrame)
	model.PrimaryPart = nil -- with a PrimaryPart, Roblox would ignore WorldPivot
	model.WorldPivot = reference.CFrame * CFrame.new(0, -reference.Size.Y / 2, 0)
	model:ScaleTo(model:GetScale() * width / reference.Size.X)
	model:PivotTo(CFrame.new(base) * turn)
end

-- The Blender model `prop` (see Types.PropModelConfig) in `parent`, sized so its part is
-- `scale` times its usual width, with that part's bottom middle on `frame` (a spot, turned).
-- nil if it isn't imported yet: then the caller builds the parts version.
function Assets.prop(parent: Instance, prop: Types.PropModelConfig, scale: number, frame: CFrame): Model?
	local model = Assets.model(prop.Model)
	if not model then
		return nil
	end
	local part = model:FindFirstChild(prop.Part)
	if not (part and part:IsA("BasePart")) then
		warn(`[Assets] The "{prop.Model}" model needs a part named {prop.Part}, so parts are used instead`)
		model:Destroy()
		return nil
	end
	Assets.fit(model, part, prop.Width * scale, frame.Position, frame.Rotation)
	model.Parent = parent
	return model
end

-- Colour every part of `model` called `name`. Solid ones stop players. Returns the last one.
function Assets.paint(model: Model, name: string, color: Color3, material: Enum.Material, solid: boolean): BasePart?
	local found: BasePart? = nil
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name == name then
			part.Color = color
			part.Material = material
			part.CanCollide = solid
			found = part
		end
	end
	return found
end

-- Remove every part of `model` called `name` (like the moss on a rock that shouldn't have any).
function Assets.remove(model: Model, name: string)
	for _, part in model:GetChildren() do
		if part.Name == name then
			part:Destroy()
		end
	end
end

return Assets
