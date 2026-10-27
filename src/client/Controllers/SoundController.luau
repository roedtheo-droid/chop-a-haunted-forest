--!strict
-- Sounds only YOU hear, played on your own computer: picking up a log, selling, buying,
-- finishing a quest, getting knocked down, and the fanfare when the forest is cleared.
--
-- Why no new remotes? The server already keeps numbers on your player as attributes
-- (Coins, Carry, QuestIndex, KnockedDown). When one of them changes the right way, we
-- play the matching sound: Coins going up means you sold, Coins going down means you bought.
-- (World sounds everyone hears, like chopping, are made by Server/Systems/EffectsManager.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- The sounds in Config.Sounds that this controller plays.
local MY_SOUNDS = { "LogPickup", "Sell", "Buy", "QuestDone", "KnockedDown", "ForestCleared" }

local SoundController = {}

local player = Players.LocalPlayer
local sounds: { [string]: Sound } = {}

local function getNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function play(name: string)
	local sound = sounds[name]
	if sound then
		sound:Play()
	end
end

-- Call onUp when a number attribute goes up, and onDown (if given) when it goes down.
local function watchNumber(attribute: string, onUp: () -> (), onDown: (() -> ())?)
	local last = getNumber(attribute)
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local now = getNumber(attribute)
		if now > last then
			onUp()
		elseif now < last and onDown then
			onDown()
		end
		last = now
	end)
end

function SoundController.init()
	-- Sounds in SoundService play "in your head", not from a spot in the world.
	local folder = Instance.new("Folder")
	folder.Name = "MySounds"
	for _, name in MY_SOUNDS do
		local cfg = Config.Sounds[name]
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = cfg.Id
		sound.Volume = cfg.Volume
		sound.PlaybackSpeed = cfg.Speed or 1
		sound.Parent = folder
		sounds[name] = sound
	end
	folder.Parent = SoundService
end

function SoundController.start()
	watchNumber("Carry", function()
		play("LogPickup")
	end)
	watchNumber("Coins", function()
		play("Sell")
	end, function()
		play("Buy")
	end)
	watchNumber("QuestIndex", function()
		-- Skip the very first quest being set when you join (that's not finishing one).
		if getNumber("QuestIndex") > 1 then
			play("QuestDone")
		end
	end)
	player:GetAttributeChangedSignal("KnockedDown"):Connect(function()
		if player:GetAttribute("KnockedDown") == true then
			play("KnockedDown")
		end
	end)
	Remotes.getEvent("ForestCleared").OnClientEvent:Connect(function()
		play("ForestCleared")
	end)
end

return SoundController
