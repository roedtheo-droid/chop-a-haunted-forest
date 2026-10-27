--!strict
-- Draws a faint outline around the sleeping mimics your Lantern can see.
-- The server decides which trees those are (LanternManager) and sends us the list.
-- The outlines are made here on YOUR computer, so nobody else sees them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GLOW_NAME = "LanternGlow"

local LanternController = {}

-- The outline on each tree we're showing right now.
local glows: { [Model]: Highlight } = {}

local function addGlow(tree: Model): Highlight
	local glow = Instance.new("Highlight")
	glow.Name = GLOW_NAME
	glow.FillTransparency = 1 -- outline only, no colour fill
	glow.OutlineColor = Config.Lantern.OutlineColor
	glow.OutlineTransparency = Config.Lantern.OutlineTransparency
	glow.DepthMode = Enum.HighlightDepthMode.Occluded -- not through walls or other trees
	glow.Adornee = tree
	glow.Parent = tree
	return glow
end

local function show(trees: { Instance })
	-- The trees the server says we can see. Skip anything that isn't a tree Model
	-- (a tree that's too far away to be loaded on our computer arrives as nothing).
	local wanted: { [Model]: boolean } = {}
	for _, instance in trees do
		if typeof(instance) == "Instance" and instance:IsA("Model") then
			wanted[instance] = true
		end
	end

	-- Remove outlines we don't need any more...
	for tree, glow in glows do
		if not wanted[tree] then
			glow:Destroy()
			glows[tree] = nil
		end
	end
	-- ...and add the new ones.
	for tree in wanted do
		if not glows[tree] then
			glows[tree] = addGlow(tree)
		end
	end
end

function LanternController.init() end

function LanternController.start()
	Remotes.getEvent("LanternMimics").OnClientEvent:Connect(show)
end

return LanternController
