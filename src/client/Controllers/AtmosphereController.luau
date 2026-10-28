--!strict
-- Each zone has its own light, fog, sky and background sound (the Look in Config.Zones): a
-- clear afternoon with fluffy clouds and birds in Pale Pines, thick fog, grey clouds and drips
-- in Fog Hollow, eerie dusk with purple clouds in Graveyard Grove. When you walk into a zone,
-- this fades YOUR lighting, clouds and sound to it.
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
local clouds: Clouds
local sunRays: SunRaysEffect
local colorCorrection: ColorCorrectionEffect -- makes colours stronger and tints the screen per zone
local ambience: { Sound } = {} -- ambience[i] is zone i's background sound
local currentZone: number? = nil
local playing: { Tween } = {}
-- While the intro flies the camera over the forest, the look follows this spot instead of
-- your character (see setViewPoint).
local viewPoint: Vector3? = nil
local viewFadeTime: number? = nil

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
		TweenService:Create(clouds, info, {
			Cover = look.CloudCover,
			Density = look.CloudDensity,
			Color = look.CloudColor,
		}),
		TweenService:Create(sunRays, info, { Intensity = look.SunRays }),
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
	local position = viewPoint or (if root then root.Position else nil)
	local zone = if position then Zones.indexAt(position) else nil
	if position and not zone and Zones.isInCamp(position) then
		zone = 1 -- the camp has zone 1's sunny look
	end
	if not zone or zone == currentZone then
		return -- same zone as before (or between zones): keep the look we have
	end
	-- The very first time (when you spawn), switch at once instead of fading.
	local seconds = if currentZone == nil then 0 else viewFadeTime or Config.ZoneLook.FadeTime
	currentZone = zone
	fadeTo(zone, seconds)
end

-- Show the look of the zone at `position` (fading over `fadeTime` seconds, 0 = at once)
-- instead of the zone your character is in. The intro uses this so each zone it flies over
-- has its own fog and light. Call it with nil to follow your character again.
function AtmosphereController.setViewPoint(position: Vector3?, fadeTime: number?)
	viewPoint = position
	viewFadeTime = fadeTime
	update()
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

	-- Real clouds in the sky. They only work inside Terrain. If the place already has some,
	-- we use those.
	local existingClouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if existingClouds then
		clouds = existingClouds
	else
		clouds = Instance.new("Clouds")
		clouds.Parent = workspace.Terrain
	end

	-- The cartoony look (see STYLE_GUIDE.md): soft shadows, a gentle glow on bright things,
	-- soft rays when you look towards the sun, and a colour filter that each zone's Look fades.
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
	sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "ZoneSunRays"
	sunRays.Intensity = 0
	sunRays.Spread = cfg.SunRaySpread
	sunRays.Parent = Lighting

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
