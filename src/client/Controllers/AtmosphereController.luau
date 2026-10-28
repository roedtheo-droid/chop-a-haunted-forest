--!strict
-- Each zone has its own light, fog and background sound (the Look in Config.Zones): a clear
-- afternoon with birds in Pale Pines, thick fog and drips in Fog Hollow, eerie dusk in
-- Graveyard Grove. When you walk into a zone, this fades YOUR lighting and sound to it.
--
-- Why on the client? Changes a client makes to Lighting (and sounds it plays itself) only
-- happen on that client. So every player gets the zone they're standing in, and the server
-- doesn't need to know.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Zones = require(ReplicatedStorage.Shared.Zones)

local AtmosphereController = {}

local player = Players.LocalPlayer
local atmosphere: Atmosphere
local colorCorrection: ColorCorrectionEffect -- makes colours stronger and tints the screen per zone
local ambience: { Sound } = {} -- ambience[i] is zone i's background sound
local currentZone: number? = nil
local playing: { Tween } = {}

local function getRoot(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Fade to a zone's look over `seconds` (0 = right away).
local function fadeTo(zone: number, seconds: number)
	local look: Types.ZoneLookConfig = Config.Zones[zone].Look
	-- Stop a fade that's still going, so two fades don't fight each other.
	for _, tween in playing do
		tween:Cancel()
	end
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	playing = {
		TweenService:Create(Lighting, info, {
			ClockTime = look.ClockTime,
			Brightness = look.Brightness,
			Ambient = look.Ambient,
			OutdoorAmbient = look.Ambient,
		}),
		TweenService:Create(colorCorrection, info, {
			Saturation = look.Saturation,
			TintColor = look.Tint,
		}),
		TweenService:Create(atmosphere, info, {
			Density = look.FogDensity,
			Offset = look.FogOffset,
			Color = look.FogColor,
			Decay = look.FogDecay,
			Haze = look.Haze,
		}),
	}
	-- Every zone's background sound keeps looping; only this zone's one is turned up.
	for index, sound in ambience do
		local volume = if index == zone then Config.Zones[index].Look.Ambience.Volume else 0
		table.insert(playing, TweenService:Create(sound, info, { Volume = volume }))
	end
	for _, tween in playing do
		tween:Play()
	end
end

local function update()
	local root = getRoot()
	local zone = if root then Zones.indexAt(root.Position) else nil
	if root and not zone and Zones.isInCamp(root.Position) then
		zone = 1 -- the camp has zone 1's sunny look
	end
	if not zone or zone == currentZone then
		return -- same zone as before (or between zones): keep the look we have
	end
	-- The very first time (when you spawn), switch at once instead of fading.
	local seconds = if currentZone == nil then 0 else Config.ZoneLook.FadeTime
	currentZone = zone
	fadeTo(zone, seconds)
end

function AtmosphereController.init()
	-- The place already has an Atmosphere in Lighting. If someone deletes it, make one,
	-- because the fog needs it.
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if existing then
		atmosphere = existing
	else
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end

	-- The cartoony look (see STYLE_GUIDE.md): soft shadows, a gentle glow on bright things,
	-- and a colour filter that each zone's Look fades.
	local cfg = Config.ZoneLook
	Lighting.ShadowSoftness = cfg.ShadowSoftness
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "ZoneColor"
	colorCorrection.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "ZoneBloom"
	bloom.Intensity = cfg.BloomIntensity
	bloom.Size = cfg.BloomSize
	bloom.Threshold = cfg.BloomThreshold
	bloom.Parent = Lighting

	-- One looping background sound per zone, all silent until you walk into that zone.
	local folder = Instance.new("Folder")
	folder.Name = "ZoneAmbience"
	for index, zone in Config.Zones do
		local sound = Instance.new("Sound")
		sound.Name = zone.Name
		sound.SoundId = zone.Look.Ambience.Id
		sound.Volume = 0
		sound.Looped = true
		sound.Parent = folder
		ambience[index] = sound
	end
	folder.Parent = SoundService
end

function AtmosphereController.start()
	for _, sound in ambience do
		sound:Play()
	end
	task.spawn(function()
		while true do
			update()
			task.wait(Config.ZoneLook.Refresh)
		end
	end)
end

return AtmosphereController
