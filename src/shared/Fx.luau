--!strict
-- Plays a sound at a spot in the world.
-- The server uses it (through Server/Systems/EffectsManager) for sounds everyone hears.
-- The client uses it for sounds it plays itself, like your chops (see
-- Client/Controllers/ChopEffectsController). Things a client makes only exist on that client.

local Debris = game:GetService("Debris")

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local CLEANUP_FALLBACK = 10 -- seconds: remove a sound by then even if it never says it ended

local Fx = {}

-- An invisible point in the world to hang a sound or particles on.
function Fx.anchorAt(position: Vector3): Attachment
	local anchor = Instance.new("Attachment")
	anchor.Name = "Effect"
	anchor.Parent = workspace.Terrain -- Terrain is always there and never moves
	anchor.WorldPosition = position
	return anchor
end

-- Play a sound at a position. `pitch` (1 if not given) makes it a little higher or lower.
function Fx.playSound(cfg: Types.SoundConfig, position: Vector3, pitch: number?)
	local anchor = Fx.anchorAt(position)
	local sound = Instance.new("Sound")
	sound.SoundId = cfg.Id
	sound.Volume = cfg.Volume
	sound.PlaybackSpeed = (cfg.Speed or 1) * (pitch or 1)
	-- Fades out smoothly with distance, and can't be heard past its range.
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = Config.Effects.SoundFullVolume
	sound.RollOffMaxDistance = cfg.Range or Config.Effects.SoundRange
	sound.Parent = anchor
	sound.Ended:Once(function()
		anchor:Destroy()
	end)
	Debris:AddItem(anchor, CLEANUP_FALLBACK)
	sound:Play()
end

return table.freeze(Fx)
