--!strict
-- World sounds and particle bursts, in one place. Other systems just say what and where:
--   EffectsManager.playSound("TreeFall", position)
--   EffectsManager.burst("Dust", position)
-- The server makes them, so every player near the spot hears and sees them.
-- Which sound and how it looks are in Config.Sounds and Config.Particles.
-- (Sounds only one player should hear, like selling, are played by Client/Controllers/SoundController.
-- Chop sounds are played by every player's own computer, see Client/Controllers/ChopEffectsController.)

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Fx = require(ReplicatedStorage.Shared.Fx)
local Types = require(ReplicatedStorage.Shared.Types)

local EffectsManager = {}

-- When each player (or thing) last made each sound, for sounds with a MinGap.
local lastPlayed: { [Instance]: { [string]: number } } = {}

-- Play a world sound at a position. `owner` (like the player who chopped) is only needed
-- for sounds with a MinGap, so one player can't stack the same sound on top of itself.
function EffectsManager.playSound(name: string, position: Vector3, owner: Instance?)
	local cfg = Config.Sounds[name]
	if not cfg then
		warn(`[Effects] No sound called "{name}" in Config.Sounds`)
		return
	end
	local gap = cfg.MinGap
	if owner and gap then
		local played = lastPlayed[owner] or {}
		lastPlayed[owner] = played
		local now = os.clock()
		local last = played[name]
		if last and now - last < gap then
			return
		end
		played[name] = now
	end
	Fx.playSound(cfg, position)
end

local function makeEmitter(cfg: Types.ParticleConfig, parent: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(cfg.Color)
	-- Start full size and shrink to nothing, so particles fade away instead of popping out.
	emitter.Size = NumberSequence.new(cfg.Size, 0)
	emitter.Transparency = NumberSequence.new(0.1, 0.6)
	emitter.Lifetime = NumberRange.new(cfg.Lifetime * 0.7, cfg.Lifetime)
	emitter.Speed = NumberRange.new(cfg.Speed * 0.5, cfg.Speed)
	emitter.SpreadAngle = Vector2.new(180, 180) -- every direction
	emitter.Drag = 3 -- slow down quickly, like dust in the air
	emitter.Parent = parent
	return emitter
end

-- A one-off burst of particles at a position, like dust when a tree lands.
function EffectsManager.burst(name: string, position: Vector3)
	local cfg = Config.Particles[name]
	if not cfg then
		warn(`[Effects] No particles called "{name}" in Config.Particles`)
		return
	end
	local anchor = Fx.anchorAt(position)
	local emitter = makeEmitter(cfg, anchor)
	emitter.Enabled = false
	emitter:Emit(cfg.Amount)
	Debris:AddItem(anchor, cfg.Lifetime + 0.5) -- gone once the last particle has faded
end

-- A steady stream of particles rising from the middle of a part (like embers from a burning
-- mimic). They stop when the part is destroyed, or when you set the emitter's Enabled to false.
function EffectsManager.stream(name: string, part: BasePart): ParticleEmitter?
	local cfg = Config.Particles[name]
	if not cfg then
		warn(`[Effects] No particles called "{name}" in Config.Particles`)
		return nil
	end
	-- Tree trunks are cylinders lying on their side and turned upright, so the part's own
	-- "up" points sideways. This point sits in the part's middle but faces the world's up.
	local holder = Instance.new("Attachment")
	holder.Name = "Stream"
	holder.Parent = part
	holder.WorldCFrame = CFrame.new(part.Position)
	local emitter = makeEmitter(cfg, holder)
	emitter.Rate = cfg.Amount
	emitter.SpreadAngle = Vector2.new(25, 25) -- mostly upwards
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, 4, 0) -- float up, like embers on hot air
	emitter.LightEmission = 1 -- glow
	return emitter
end

function EffectsManager.init() end

function EffectsManager.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPlayed[player] = nil
	end)
end

return EffectsManager
