--!strict
-- Models made in Blender (see the blender/ folder). Theo imports each .fbx into Studio and
-- puts it in ServerStorage > MapAssets (Config.Models.Folder). Builders ask for a model by
-- name: when it's there they get a copy, and when it isn't they get nil and build the old
-- Parts version instead. So the game always works, even before any model is imported.
--
-- Why ServerStorage? Rojo only syncs the folders in default.project.json, so imported models
-- stay safe in the place, and only the server can see them (players get the built copies).
--
-- Used by Blocky (trees and the chop notch) and Props (rocks).
-- It's not a system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

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

local function template(name: string): Instance?
	local folder = ServerStorage:FindFirstChild(Config.Models.Folder)
	local found = if folder then folder:FindFirstChild(name) else nil
	report(name, found ~= nil)
	return found
end

-- The names the game looks for. Longer names first, so "BarkBlock" isn't mistaken for "Block".
local ROLES = { "BarkBlock", "LeafBlock", "Leaves", "Trunk", "Branch", "Root", "Moss", "Rock", "Patch", "Pebble", "Sand", "Stone" }

-- Blender can't give two objects the same name, so they're numbered ("LeafBlock_2"), and
-- Studio sometimes adds the file's name too ("Oak_LeafBlock_2"). The game wants the plain
-- name: "LeafBlock".
local function plainName(name: string): string
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
	local source = template(name)
	if not source then
		return nil
	end
	local copy = source:Clone()
	local parts: { BasePart } = {}
	if copy:IsA("BasePart") then
		table.insert(parts, copy)
	end
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	local model = Instance.new("Model")
	model.Name = name
	for _, part in parts do
		-- Pictures and joints from the import would fight the colours and welds we set.
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("JointInstance") or child:IsA("WeldConstraint") then
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
	if not copy:IsA("BasePart") then
		copy:Destroy()
	end
	if #parts == 0 then
		model:Destroy()
		return nil
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

return Assets
