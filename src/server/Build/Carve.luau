--!strict
-- Carving a tree's trunk, like in Chop a Forest (rules in Shared/Carving, numbers in Config.Cut).
-- The server only decides WHERE each hit bites a hole: it keeps each tree's list of holes and
-- stores it on the tree as the "Holes" attribute. Every player's computer cuts the holes itself
-- (Client/Controllers/CarveController), so everyone sees the same dents, and nothing heavy has
-- to go over the network. (Cutting here and sending the cut trunk got players disconnected.)
-- At 0 HP the tree breaks at its deepest dent: Carve.split leaves a "Stump" model with what
-- every computer needs to draw the carved stump.
-- It never changes the damage: that's TreeManager's job. Used by TreeManager. It's not a
-- system, so it has no init()/start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Carving = require(ReplicatedStorage.Shared.Carving)

local Carve = {}

-- Each carved tree's holes. Weak keys: a tree that's removed is forgotten by itself.
local holesOf: { [Model]: { Carving.Hole } } = setmetatable({} :: { [Model]: { Carving.Hole } }, { __mode = "k" })
local random = Random.new()

-- A hit at `point` (where the player aimed) bites a rough hole out of the trunk. `share` is how
-- much of the tree's HP the hit took (0.1 = a tenth): bigger hits bite bigger holes.
function Carve.hit(tree: Model, trunk: BasePart, point: Vector3, share: number)
	local holes = holesOf[tree] or {}
	holesOf[tree] = holes
	local offset = trunk.CFrame:PointToObjectSpace(point)
	table.insert(holes, Carving.nextHole(holes, trunk.Size, offset, share, random:NextInteger(1, 1000000000)))
	tree:SetAttribute("Holes", Carving.encode(holes))
end

-- A felled tree breaks at its deepest dent. Leaves a "Stump" model in `stumpParent`: an invisible
-- "Body" the size of the trunk, with the holes and the height it broke at, so every computer can
-- draw the carved stump (also players who join later), and a "Tree" link to the tree, so computers
-- that already carved it break their own copy instead. Returns the height it broke at (studs above
-- the bottom of the trunk; the falling top turns around there), or nil if it was never carved.
function Carve.split(tree: Model, trunk: BasePart, stumpParent: Instance): number?
	local holes = holesOf[tree]
	if not holes or #holes == 0 then
		return nil
	end
	local height = Carving.breakHeight(holes, trunk.Size)

	local stump = Instance.new("Model")
	stump.Name = "Stump"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = trunk.Size
	body.CFrame = trunk.CFrame
	body.Transparency = 1
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body:SetAttribute("Holes", Carving.encode(holes))
	body:SetAttribute("BreakHeight", height)
	body:SetAttribute("BarkColor", trunk.Color)
	-- Pictures on the trunk (birch marks), for the stump's bark. Off here: the body is invisible.
	for _, child in trunk:GetChildren() do
		if child:IsA("SurfaceGui") then
			local copy = child:Clone()
			copy.Enabled = false
			copy.Parent = body
		end
	end
	body.Parent = stump
	local link = Instance.new("ObjectValue")
	link.Name = "Tree"
	link.Value = tree
	link.Parent = stump
	stump.Parent = stumpParent
	holesOf[tree] = nil
	return height
end

return Carve
