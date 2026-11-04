--!strict
-- Everyone's arms when they swing an axe or saw with the Chainsaw, as other players see them
-- (your own first-person hands are ViewmodelController). Only for looks.
--   * Holding an axe, both hands go on the handle. A swing lifts it back over your head, chops
--     it down with a lean forward, and brings it back.
--   * Holding the Chainsaw, both hands hold it out in front and it buzzes a little. While you
--     saw, it pushes forward, saws back and forth and shakes harder, and the engine revs.
-- The moves are made with code, not uploaded Roblox animations: every frame, just after Roblox
-- has played the character's normal animations, we turn the shoulders and the waist a little
-- more (see Config.ChopAnims and Config.SawAnims for every number).
-- Arms turned by code only move on the computer that turns them. So when you swing, this tells
-- the server (SwingTool), and the server tells everyone else (ToolSwung, see
-- Server/Systems/SwingRelayManager). Every computer then moves your arms itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

-- The moments of a swing: a swing moves from one of these poses to the next.
export type ChopStage = "Rest" | "WindUp" | "Strike" | "Follow"

-- The joints we turn: where each one is in an R15 character.
local JOINTS: { { Name: string, Part: string, Joint: string } } = {
	{ Name = "RightArm", Part = "RightUpperArm", Joint = "RightShoulder" },
	{ Name = "LeftArm", Part = "LeftUpperArm", Joint = "LeftShoulder" },
	{ Name = "Waist", Part = "UpperTorso", Joint = "Waist" },
}

-- One player's character and what its arms are doing.
type Rig = {
	Character: Model?,
	Joints: { [string]: Instance }, -- Motor6Ds (older avatars) or AnimationConstraints (newer ones)
	Written: { [string]: CFrame }, -- what we set each joint to last frame...
	Base: { [string]: CFrame }, -- ...and what it was before we turned it
	SwingStarted: number, -- os.clock() when the last axe swing started
	SwingScale: number, -- below 1 when the swing is sped up to fit the tool's cooldown
	LastSaw: number, -- os.clock() of the last Chainsaw swing
	SawBlend: number, -- 0 = just holding the Chainsaw, 1 = sawing
	Engine: Sound?, -- the Chainsaw's engine, playing in its Handle
	EngineTool: Tool?,
}

local ToolAnimController = {}

local player = Players.LocalPlayer
local random = Random.new()
local rigs: { [Player]: Rig } = {}
local swingRemote: RemoteEvent

local function newRig(): Rig
	return {
		Character = nil,
		Joints = {},
		Written = {},
		Base = {},
		SwingStarted = -math.huge,
		SwingScale = 1,
		LastSaw = -math.huge,
		SawBlend = 0,
		Engine = nil,
		EngineTool = nil,
	}
end

local function getRig(who: Player): Rig
	local rig = rigs[who]
	if not rig then
		rig = newRig()
		rigs[who] = rig
	end
	return rig
end

---------------------------------------------------------------------------
-- Swing timing (also used by ViewmodelController and ChopController)
---------------------------------------------------------------------------

-- How much a swing of `toolId` is sped up to fit its cooldown (1 = not at all), and how many
-- seconds after the click it hits the tree.
function ToolAnimController.chopTiming(toolId: string, cooldown: number): (number, number)
	local anim = Config.ChopAnims[toolId]
	if not anim then
		return 1, Config.ChopEffects.ImpactDelay
	end
	local total = anim.WindUpTime + anim.StrikeTime + math.max(anim.HitStop, anim.FollowTime) + anim.ReturnTime
	local scale = math.min(1, cooldown * 0.95 / total)
	return scale, (anim.WindUpTime + anim.StrikeTime) * scale
end

-- Where a swing is `t` seconds in (already slowed back to the swing's own speed): it moves from
-- pose `from` to pose `to`, `amount` of the way (0 to 1, a little more while it bounces back).
-- `stuck` is true while an axe that hit is stuck in the bark.
function ToolAnimController.chopStage(
	anim: Types.ChopAnimConfig,
	t: number,
	hit: boolean
): (ChopStage, ChopStage, number, boolean)
	if t < 0 then
		return "Rest", "Rest", 0, false
	end
	if t < anim.WindUpTime then
		-- Lifting it back: quick at first, slowing down at the top.
		local u = t / anim.WindUpTime
		return "Rest", "WindUp", 1 - (1 - u) * (1 - u), false
	end
	t -= anim.WindUpTime
	if t < anim.StrikeTime then
		-- Chopping down: faster and faster until it lands.
		local u = t / anim.StrikeTime
		return "WindUp", "Strike", u * u * u, false
	end
	t -= anim.StrikeTime
	local last: ChopStage = "Strike"
	if hit then
		if t < anim.HitStop then
			return "Strike", "Strike", 0, true
		end
		t -= anim.HitStop
	else
		if t < anim.FollowTime then
			local u = t / anim.FollowTime
			return "Strike", "Follow", 1 - (1 - u) * (1 - u), false
		end
		t -= anim.FollowTime
		last = "Follow"
	end
	if t < anim.ReturnTime then
		-- Back to rest, swinging a little past it first (Bounce) so it doesn't stop dead.
		local v = t / anim.ReturnTime - 1
		local c = anim.Bounce
		return last, "Rest", 1 + (c + 1) * v * v * v + c * v * v, false
	end
	return "Rest", "Rest", 0, false
end

-- How much the Chainsaw in `who`'s hands is sawing right now (0 = just holding it, 1 = sawing).
function ToolAnimController.sawAmount(who: Player): number
	local rig = rigs[who]
	return if rig then rig.SawBlend else 0
end

-- Note a swing by `who`: start their axe swing, or keep their Chainsaw sawing.
local function noteSwing(who: Player, toolId: string)
	local rig = getRig(who)
	if Config.ChopAnims[toolId] then
		rig.SwingScale = ToolAnimController.chopTiming(toolId, Config.Tools[toolId].Cooldown)
		rig.SwingStarted = os.clock()
	elseif Config.SawAnims[toolId] then
		rig.LastSaw = os.clock()
	end
end

-- You swung (or keep sawing): move your own character's arms, and tell the others.
-- Tools without a code animation (Fists, the Torch) do nothing here.
function ToolAnimController.swingMine(toolId: string)
	if not (Config.ChopAnims[toolId] or Config.SawAnims[toolId]) then
		return
	end
	noteSwing(player, toolId)
	swingRemote:FireServer()
end

---------------------------------------------------------------------------
-- Turning the joints
---------------------------------------------------------------------------

local function getTransform(joint: Instance): CFrame?
	if joint:IsA("Motor6D") then
		return joint.Transform
	elseif joint:IsA("AnimationConstraint") then
		return joint.Transform
	end
	return nil
end

local function setTransform(joint: Instance, value: CFrame)
	if joint:IsA("Motor6D") then
		joint.Transform = value
	elseif joint:IsA("AnimationConstraint") then
		joint.Transform = value
	end
end

-- Find the character's shoulders and waist (again, if it's a new character).
local function findJoints(rig: Rig, character: Model)
	if rig.Character == character then
		return
	end
	rig.Character = character
	table.clear(rig.Joints)
	table.clear(rig.Written)
	table.clear(rig.Base)
	for _, info in JOINTS do
		local part = character:FindFirstChild(info.Part)
		local joint = if part then part:FindFirstChild(info.Joint) else nil
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			rig.Joints[info.Name] = joint
		end
	end
end

-- Turn one joint `degrees` more than Roblox's own animation put it this frame.
local function turnJoint(rig: Rig, name: string, degrees: Vector3)
	local joint = rig.Joints[name]
	local current = if joint then getTransform(joint) else nil
	if not (joint and current) then
		return
	end
	-- When no animation set this joint this frame, it still has our turn from last frame:
	-- start again from what it was before, so the turns don't add up.
	local base = if rig.Written[name] == current then rig.Base[name] else current
	local value = base * CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
	setTransform(joint, value)
	rig.Base[name] = base
	rig.Written[name] = value
end

-- Stop turning the joints: put back any joint no animation has set since.
local function letGo(rig: Rig)
	for name, written in rig.Written do
		local joint = rig.Joints[name]
		if joint and getTransform(joint) == written then
			setTransform(joint, rig.Base[name])
		end
	end
	table.clear(rig.Written)
	table.clear(rig.Base)
end

local function poseOf(anim: Types.ChopAnimConfig, stage: ChopStage): Types.BodyPose
	if stage == "WindUp" then
		return anim.BodyWindUp
	elseif stage == "Strike" or stage == "Follow" then
		return anim.BodyStrike
	end
	return anim.BodyHold
end

local function lerpPose(a: Types.BodyPose, b: Types.BodyPose, amount: number): Types.BodyPose
	return {
		RightArm = a.RightArm:Lerp(b.RightArm, amount),
		LeftArm = a.LeftArm:Lerp(b.LeftArm, amount),
		Waist = a.Waist:Lerp(b.Waist, amount),
	}
end

local function applyPose(rig: Rig, pose: Types.BodyPose)
	turnJoint(rig, "RightArm", pose.RightArm)
	turnJoint(rig, "LeftArm", pose.LeftArm)
	turnJoint(rig, "Waist", pose.Waist)
end

---------------------------------------------------------------------------
-- The Chainsaw's engine
---------------------------------------------------------------------------

local function stopEngine(rig: Rig)
	if rig.Engine then
		rig.Engine:Destroy()
	end
	rig.Engine = nil
	rig.EngineTool = nil
end

-- Keep the engine running in the saw's Handle, louder and higher while it saws.
local function runEngine(rig: Rig, tool: Tool, anim: Types.SawAnimConfig)
	local sound = Config.Sounds[anim.Engine]
	if not sound then
		return
	end
	if rig.EngineTool ~= tool then
		stopEngine(rig)
		local handle = tool:FindFirstChild("Handle")
		if not (handle and handle:IsA("BasePart")) then
			return
		end
		local engine = Instance.new("Sound")
		engine.Name = "Engine"
		engine.SoundId = sound.Id
		engine.Looped = true
		engine.RollOffMode = Enum.RollOffMode.InverseTapered
		engine.RollOffMinDistance = Config.Effects.SoundFullVolume
		engine.RollOffMaxDistance = sound.Range or Config.Effects.SoundRange
		engine.Parent = handle
		engine:Play()
		rig.Engine = engine
		rig.EngineTool = tool
	end
	local engine = rig.Engine
	if engine then
		local blend = rig.SawBlend
		engine.Volume = sound.Volume * (anim.IdleVolume + (1 - anim.IdleVolume) * blend)
		engine.PlaybackSpeed = (sound.Speed or 1) * (anim.IdleSpeed + (anim.CutSpeed - anim.IdleSpeed) * blend)
	end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------

-- The tool `character` is holding, and its Id (nil if none).
local function heldTool(character: Model): (Tool?, string?)
	local tool = character:FindFirstChildOfClass("Tool")
	local toolId = if tool then tool:GetAttribute("ToolId") else nil
	if tool and typeof(toolId) == "string" then
		return tool, toolId
	end
	return nil, nil
end

local function updateRig(who: Player, rig: Rig, now: number, dt: number)
	local character = who.Character
	local tool: Tool?, toolId: string? = nil, nil
	if character then
		findJoints(rig, character)
		tool, toolId = heldTool(character)
	end
	local chop = if toolId then Config.ChopAnims[toolId] else nil
	local saw = if toolId then Config.SawAnims[toolId] else nil

	if not (saw and tool) then
		stopEngine(rig)
		rig.SawBlend = 0
	end
	if chop then
		local t = (now - rig.SwingStarted) / rig.SwingScale
		local from, to, amount = ToolAnimController.chopStage(chop, t, true)
		applyPose(rig, lerpPose(poseOf(chop, from), poseOf(chop, to), amount))
	elseif saw and tool then
		-- Glide between holding and sawing, so it doesn't jump.
		local target = if now - rig.LastSaw < saw.RevHold then 1 else 0
		rig.SawBlend += (target - rig.SawBlend) * (1 - math.exp(-saw.Blend * dt))
		local blend = rig.SawBlend
		local pose = lerpPose(saw.BodyHold, saw.BodyCut, blend)
		-- Saw strokes, and a buzz that shakes the arms (harder while sawing).
		local stroke = math.sin(now * math.pi * 2 * saw.StrokeSpeed) * saw.BodyStroke * blend
		local shake = saw.BodyIdleShake + (saw.BodyCutShake - saw.BodyIdleShake) * blend
		local function buzz(): Vector3
			return Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * shake
		end
		pose.RightArm += Vector3.new(stroke, 0, 0) + buzz()
		pose.LeftArm += Vector3.new(stroke, 0, 0) + buzz()
		applyPose(rig, pose)
		runEngine(rig, tool, saw)
	else
		letGo(rig)
	end
end

local function update(dt: number)
	local now = os.clock()
	for _, who in Players:GetPlayers() do
		updateRig(who, getRig(who), now, dt)
	end
end

function ToolAnimController.init()
	swingRemote = Remotes.getEvent("SwingTool")
end

function ToolAnimController.start()
	-- Someone else swung: move their arms.
	Remotes.getEvent("ToolSwung").OnClientEvent:Connect(function(who: Player, toolId: string)
		if typeof(who) == "Instance" and who:IsA("Player") and who ~= player and typeof(toolId) == "string" then
			noteSwing(who, toolId)
		end
	end)
	Players.PlayerRemoving:Connect(function(who)
		local rig = rigs[who]
		if rig then
			stopEngine(rig)
			rigs[who] = nil
		end
	end)
	-- PreSimulation comes just after Roblox has played the characters' animations this frame,
	-- so our turns go on top of them (and it runs even while Studio isn't drawing).
	RunService.PreSimulation:Connect(update)
end

return ToolAnimController
