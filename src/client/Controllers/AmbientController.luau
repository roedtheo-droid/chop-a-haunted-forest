--!strict
-- Small movements that make the zones feel alive, only for looks:
--   * fog banks in zone 2 drift slowly from side to side
--   * the crooked lamps in zone 3 (and the crypt's glow) flicker a little
-- The server builds them still (see Server/Systems/LandmarkManager); moving them here on
-- each player's own computer is smooth and sends nothing over the network.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

type FogBank = {
	Part: BasePart,
	Start: CFrame,
	Phase: number,
}

type FlickerLight = {
	Light: PointLight,
	Brightness: number, -- its brightness when it isn't flickering
	Seed: number, -- so the lamps don't all flicker together
}

local AmbientController = {}

local fogBanks: { [Instance]: FogBank } = {}
local lights: { [Instance]: FlickerLight } = {}

local function addFogBank(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local phase = instance:GetAttribute("Phase")
	fogBanks[instance] = {
		Part = instance,
		Start = instance.CFrame,
		Phase = if typeof(phase) == "number" then phase else 0,
	}
end

local function addLight(instance: Instance)
	if not instance:IsA("PointLight") then
		return
	end
	lights[instance] = {
		Light = instance,
		Brightness = instance.Brightness,
		Seed = math.random() * 100,
	}
end

-- Calls `add` for everything with the tag now and later, and `remove` for things that lose it.
local function watch(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

function AmbientController.init() end

function AmbientController.start()
	watch(Tags.FogBank, addFogBank, function(instance: Instance)
		fogBanks[instance] = nil
	end)
	watch(Tags.Flicker, addLight, function(instance: Instance)
		lights[instance] = nil
	end)

	local cfg = Config.Props
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, fog in fogBanks do
			local offset = math.sin(now * cfg.FogDriftSpeed + fog.Phase) * cfg.FogDrift
			fog.Part.CFrame = fog.Start + Vector3.new(offset, 0, 0)
		end
		for _, flicker in lights do
			-- math.noise wobbles smoothly between about -0.5 and 0.5.
			local dip = math.clamp(math.noise(now * 5, flicker.Seed) + 0.5, 0, 1)
			flicker.Light.Brightness = flicker.Brightness * (1 - cfg.Flicker * dip)
		end
	end)
end

return AmbientController
