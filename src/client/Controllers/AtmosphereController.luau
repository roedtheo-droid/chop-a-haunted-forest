--!strict
-- Each zone has its own light and fog (the Look in Config.Zones): a clear afternoon in
-- Pale Pines, thick fog in Fog Hollow, dusk in Graveyard Grove. When you walk into a
-- zone, this fades YOUR screen's lighting to that zone's look.
--
-- Why on the client? Changes a client makes to Lighting only show on that client. So
-- every player sees the zone they're standing in, and the server doesn't need to know.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Zones = require(ReplicatedStorage.Shared.Zones)

local AtmosphereController = {}

local player = Players.LocalPlayer
local atmosphere: Atmosphere
local currentZone: number? = nil
local playing: { Tween } = {}

local function getRoot(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Fade to a zone's look over `seconds` (0 = right away).
local function fadeTo(look: Types.ZoneLookConfig, seconds: number)
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
		TweenService:Create(atmosphere, info, {
			Density = look.FogDensity,
			Offset = look.FogOffset,
			Color = look.FogColor,
			Decay = look.FogDecay,
			Haze = look.Haze,
		}),
	}
	for _, tween in playing do
		tween:Play()
	end
end

local function update()
	local root = getRoot()
	local zone = if root then Zones.indexAt(root.Position) else nil
	if not zone or zone == currentZone then
		return -- same zone as before (or between zones): keep the look we have
	end
	-- The very first time (when you spawn), switch at once instead of fading.
	local seconds = if currentZone == nil then 0 else Config.ZoneLook.FadeTime
	currentZone = zone
	fadeTo(Config.Zones[zone].Look, seconds)
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
end

function AtmosphereController.start()
	task.spawn(function()
		while true do
			update()
			task.wait(Config.ZoneLook.Refresh)
		end
	end)
end

return AtmosphereController
