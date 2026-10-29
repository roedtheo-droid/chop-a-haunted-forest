--!strict
-- Carving rules that the server and every player's computer share (numbers in Config.Cut).
-- Every hit bites a rough hole out of a tree's trunk where the player aimed. The SERVER decides
-- each hole (Server/Build/Carve) and stores the list on the tree as the "Holes" attribute (a short
-- text). Every player's computer then cuts the holes itself (Client/Controllers/CarveController),
-- from that same list, so everyone sees the same dents. (Cutting on the server and sending the
-- cut trunk over the network was too much for Roblox: players got disconnected.)
-- A hole is a few numbers; the shapes it cuts (a big ball, lumps, splinters) come from its Seed,
-- so every computer makes exactly the same ones.

local Config = require(script.Parent.Config)

local Carving = {}

-- One hole, in the trunk's own space (so it's right even if the tree moves, like an awake mimic).
export type Hole = {
	Offset: Vector3, -- the middle of its big ball
	Radius: number,
	Out: Vector3, -- flat, out of the trunk where it was hit
	Seed: number, -- picks its lumps and splinters
}

-- One shape a hole cuts away: a ball, or a thin block for a torn, splintery edge (trunk space).
export type Bit = {
	Place: CFrame,
	Size: Vector3,
	Round: boolean,
}

-- One layer of a carved trunk, from the bark inwards.
export type Layer = {
	Width: number, -- each layer is a tube this wide (the heart is solid)
	Color: Color3,
	CutColor: Color3, -- the colour of the faces a hole leaves in it
}

-- The trunk's layers, like a real one: a thin skin of bark, pale wood, a darker ring and a pale
-- heart. So a dent shows a dark bark rim, then pale wood, then the ring as it gets deep.
function Carving.layers(trunkWidth: number, barkColor: Color3): { Layer }
	local cfg = Config.Cut
	local pale, ring = cfg.InnerColors[1], cfg.InnerColors[2]
	return {
		{ Width = trunkWidth, Color = barkColor, CutColor = barkColor:Lerp(Color3.new(0, 0, 0), cfg.RimShade) },
		{ Width = trunkWidth * (1 - cfg.BarkThickness * 2), Color = pale, CutColor = pale },
		{ Width = trunkWidth * cfg.RingWidth, Color = ring, CutColor = ring },
		{ Width = trunkWidth * cfg.HeartWidth, Color = pale, CutColor = pale },
	}
end

-- The hole a hit at `offset` (where the player aimed, in the trunk's space) bites out.
-- `share` is how much of the tree's HP the hit took (0.1 = a tenth): bigger hits, bigger holes.
-- Aiming always finds the outside of the trunk, so the depth is worked out here: a new dent starts
-- as a shallow bowl, and hitting a dent again digs it a step deeper, until it's almost through.
function Carving.nextHole(holes: { Hole }, trunkSize: Vector3, offset: Vector3, share: number, seed: number): Hole
	local cfg = Config.Cut
	local scale = math.clamp((share * cfg.HitsPerTree) ^ (1 / 3), cfg.MinHoleScale, cfg.MaxHoleScale)
	local radius = trunkSize.X * cfg.HoleSize * scale
	local out = Vector3.new(offset.X, 0, offset.Z)
	out = if out.Magnitude > 0.01 then out.Unit else Vector3.zAxis

	-- A new dent: the ball's middle sits a little outside the bark.
	local center = offset + out * radius * cfg.HoleOut
	-- An old dent on this line: a step further in than its deepest hole.
	local deepest: Hole? = nil
	for _, hole in holes do
		local apart = hole.Offset - offset
		local sideways = (apart - out * apart:Dot(out)).Magnitude -- how far off the line in from where you hit
		if sideways < math.max(hole.Radius, radius) and (not deepest or hole.Offset:Dot(out) < deepest.Offset:Dot(out)) then
			deepest = hole
		end
	end
	if deepest then
		local inward = deepest.Offset - out * radius * cfg.DigStep
		local limit = -trunkSize.X / 2 * cfg.MaxDepth -- never further in than almost through
		center = inward - out * math.min(inward:Dot(out) - limit, 0)
	end

	-- Shifted a little at random, so dents look natural.
	local random = Random.new(seed)
	local jitter = radius * cfg.HoleJitter
	center += Vector3.new(random:NextNumber(-jitter, jitter), random:NextNumber(-jitter, jitter), random:NextNumber(-jitter, jitter))
	return { Offset = center, Radius = radius, Out = out, Seed = seed }
end

-- The shapes a hole cuts away, so it isn't a perfect bowl but looks bitten out of real wood
-- (Config.Cut.Rough): a big ball in the middle, smaller lumps above and below it (wood tears along
-- its grain, which runs up the trunk), lumps on the sides, and thin, tilted blocks around the edge
-- that leave sharp, splintery corners. The same hole always gives the same shapes.
function Carving.bits(hole: Hole): { Bit }
	local rough = Config.Cut.Rough
	local random = Random.new(hole.Seed + 1)
	local center, radius, out = hole.Offset, hole.Radius, hole.Out
	local up = Vector3.yAxis
	local side = up:Cross(out)
	local function range(pair: { number }): number
		return random:NextNumber(pair[1], pair[2])
	end
	local bits: { Bit } = {}
	local function ball(position: Vector3, ballRadius: number)
		table.insert(bits, { Place = CFrame.new(position), Size = Vector3.one * ballRadius * 2, Round = true })
	end

	ball(center, radius * range(rough.MainSize))
	for index = 1, rough.GrainLumps do
		local direction = if index % 2 == 1 then 1 else -1 -- one above, one below, ...
		ball(
			center + up * direction * radius * range(rough.GrainReach) + side * radius * range({ -0.25, 0.25 }) + out * radius * range({ -0.5, -0.1 }),
			radius * range(rough.GrainSize)
		)
	end
	for _ = 1, random:NextInteger(rough.SideLumps[1], rough.SideLumps[2]) do
		local direction = if random:NextNumber() < 0.5 then 1 else -1
		ball(
			center + side * direction * radius * range(rough.SideReach) + up * radius * range({ -0.4, 0.4 }) + out * radius * range({ -0.5, -0.1 }),
			radius * range(rough.SideSize)
		)
	end
	for _ = 1, random:NextInteger(rough.Splinters[1], rough.Splinters[2]) do
		-- Somewhere on the edge of the hole, dug into the wood, tall and thin like a splinter
		-- pulled off along the grain, and tilted a little.
		local angle = random:NextNumber(0, math.pi * 2)
		local around = side * math.cos(angle) + up * math.sin(angle) * 1.3
		local position = center + around * radius * range(rough.SplinterReach) + out * radius * range(rough.SplinterDepth)
		local place = CFrame.fromMatrix(position, side, up, -out) -- its long side up the grain
			* CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(-0.4, 0.4), random:NextNumber(-0.5, 0.5))
		local length = radius * range(rough.SplinterLength)
		table.insert(bits, { Place = place, Size = Vector3.new(length * 0.25, length, length * 0.7), Round = false })
	end
	return bits
end

-- Where the trunk was dug into the most: the height (studs above the bottom of the trunk) with
-- the most hole around it. A felled tree breaks there.
function Carving.breakHeight(holes: { Hole }, trunkSize: Vector3): number
	local band = trunkSize.X * 0.25 -- holes this close in height count as the same dent
	local amount: { [number]: number } = {}
	local best, bestAmount = nil :: number?, 0
	for _, hole in holes do
		local slot = math.floor((hole.Offset.Y + trunkSize.Y / 2) / band)
		amount[slot] = (amount[slot] or 0) + hole.Radius ^ 3
		if amount[slot] > bestAmount then
			best, bestAmount = slot, amount[slot]
		end
	end
	local height = if best then (best + 0.5) * band else trunkSize.Y * 0.2
	return math.clamp(height, 0.3, trunkSize.Y * 0.8)
end

-- Holes as a short text for the "Holes" attribute (attributes can't hold lists), and back.
-- Each hole is "x,y,z,radius,outX,outZ,seed" and holes are separated by ";".
function Carving.encode(holes: { Hole }): string
	local parts = table.create(#holes)
	for index, hole in holes do
		local o = hole.Offset
		parts[index] = string.format("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d", o.X, o.Y, o.Z, hole.Radius, hole.Out.X, hole.Out.Z, hole.Seed)
	end
	return table.concat(parts, ";")
end

function Carving.decode(text: string): { Hole }
	local holes: { Hole } = {}
	for entry in string.gmatch(text, "[^;]+") do
		local n = {}
		for number in string.gmatch(entry, "[^,]+") do
			table.insert(n, tonumber(number) or 0)
		end
		if #n == 7 then
			table.insert(holes, { Offset = Vector3.new(n[1], n[2], n[3]), Radius = n[4], Out = Vector3.new(n[5], 0, n[6]), Seed = n[7] })
		end
	end
	return holes
end

return table.freeze(Carving)
