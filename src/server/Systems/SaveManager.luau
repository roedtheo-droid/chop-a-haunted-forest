--!strict
-- Saves each player's permanent data (Embers, lifetime stats, unlocks) with DataStores.
-- This is the ONLY file that talks to DataStoreService.
--
-- How it works:
--   Join      Load your save and "lock" it with this server's id, in one UpdateAsync call.
--             If another server still holds the lock (you just left it and it's still
--             saving), wait and try again. If it still holds it after a few tries, or
--             loading keeps failing, you're kicked with a "please rejoin" message:
--             playing on with an empty save would overwrite your real one.
--   Playing   Other systems change the save in memory only (EmberManager, addStat).
--   Autosave  Every few minutes. It also refreshes the lock.
--   Leave     One last save that also removes the lock.
--   Shutdown  BindToClose saves everyone who's still here and waits for it.
-- Every DataStore call is retried with a growing wait (1, 2, 4, 8 seconds).
--
-- Why the lock? Without it, a player who rejoins quickly could load their OLD save on
-- the new server before the old server finished writing, and lose (or double) Embers.
--
-- In Studio, saving only works if the place is published AND "Enable Studio Access to
-- API Services" is on (Home > Game Settings > Security). Otherwise saving is switched
-- off: the game still runs, it just doesn't save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local CURRENT_VERSION = 1

-- Lifetime stats. To add one, add its name here: old saves get it at 0 automatically.
local STAT_NAMES = { "TreesFelled", "MimicsChopped", "MimicsBurned", "CoinsEarned", "ForestsCleared" }

-- Upgrades from one save version to the next: MIGRATIONS[1] turns a version 1 save into
-- version 2, and so on. Empty for now. Add one (and raise CURRENT_VERSION) whenever a
-- field is renamed or changes meaning.
local MIGRATIONS: { [number]: (any) -> any } = {}

type Profile = {
	Data: Types.SaveData,
	Loaded: boolean, -- false until the save has loaded (and always false while saving is off)
	Released: boolean, -- true once the last save (the one that removes the lock) has started
}

type SaveResult = "Saved" | "Failed" | "LostLock"

local SaveManager = {}

local isStat: { [string]: boolean } = {}
for _, name in STAT_NAMES do
	isStat[name] = true
end

local store: DataStore? = nil -- nil while saving is off
-- In Studio every test server has the same empty JobId, so we use "Studio" instead.
-- That way a Studio test can always take over a lock left by an earlier Studio test.
local serverId = if game.JobId ~= "" then game.JobId else "Studio"
local profiles: { [Player]: Profile } = {}
local savesRunning = 0 -- DataStore writes in progress (shutdown waits for these)
local notifyRemote: RemoteEvent

local function keyFor(userId: number): string
	return `Player_{userId}`
end

local function newData(): Types.SaveData
	local stats: { [string]: number } = {}
	for _, name in STAT_NAMES do
		stats[name] = 0
	end
	return { Version = CURRENT_VERSION, Embers = 0, Stats = stats, Unlocks = {} }
end

-- Turn whatever came out of the DataStore into a clean save of the current version.
-- Anything missing or of the wrong type gets its default value.
local function cleanUp(stored: any): Types.SaveData
	if typeof(stored) ~= "table" then
		return newData() -- a brand new player
	end
	local version = if typeof(stored.Version) == "number" then stored.Version else 1
	if version > CURRENT_VERSION then
		-- Saved by a newer version of the game (an update is rolling out). Loading it here
		-- would throw away whatever the new version added, so refuse.
		error(`Save is version {version}, but this server only knows up to {CURRENT_VERSION}`)
	end
	local raw = stored
	while version < CURRENT_VERSION do
		local step = MIGRATIONS[version]
		if not step then
			error(`No migration from save version {version}`)
		end
		raw = step(raw)
		version += 1
	end

	local data = newData()
	if typeof(raw.Embers) == "number" then
		data.Embers = raw.Embers
	end
	if typeof(raw.Stats) == "table" then
		for _, name in STAT_NAMES do
			local value = raw.Stats[name]
			if typeof(value) == "number" then
				data.Stats[name] = value
			end
		end
	end
	if typeof(raw.Unlocks) == "table" then
		for _, unlock in raw.Unlocks do
			if typeof(unlock) == "string" then
				table.insert(data.Unlocks, unlock)
			end
		end
	end
	return data
end

-- Run a DataStore call. If it fails, wait and try again, waiting twice as long each time.
-- Returns true if it worked.
local function withRetry(what: string, call: () -> ()): boolean
	local waitTime = Config.Save.RetryWait
	for attempt = 1, Config.Save.Retries do
		local ok, err = pcall(call)
		if ok then
			return true
		end
		warn(`[Save] {what} failed (try {attempt}/{Config.Save.Retries}): {err}`)
		if attempt < Config.Save.Retries then
			task.wait(waitTime)
			waitTime *= 2
		end
	end
	return false
end

-- Put the numbers on the player as attributes: the HUD reads "Embers", and you can see
-- the stats in Studio under Players > (your name) > Attributes.
local function show(player: Player, data: Types.SaveData)
	player:SetAttribute("Embers", data.Embers)
	for name, value in data.Stats do
		player:SetAttribute(`Stat_{name}`, value)
	end
	-- One attribute per unlock, like "Unlock_Truck_StakeHauler" = true (the Garage reads these).
	for _, unlock in data.Unlocks do
		player:SetAttribute(`Unlock_{unlock}`, true)
	end
end

-- Write a profile to the DataStore. `release` also removes the lock (the player is leaving).
local function writeSave(userId: number, profile: Profile, release: boolean): SaveResult
	local activeStore = store
	if not activeStore or not profile.Loaded then
		return "Failed"
	end

	savesRunning += 1
	local lostLock = false
	local ok = withRetry(`Saving player {userId}`, function()
		lostLock = false
		activeStore:UpdateAsync(keyFor(userId), function(stored: any): (any, { number }?)
			-- Only write if this server still holds the lock. If it doesn't, our lock went
			-- stale and another server has loaded this save since: writing would undo that.
			if typeof(stored) == "table" and stored.LockedBy ~= serverId then
				lostLock = true
				return nil, nil -- nil means "don't change anything"
			end
			local record = {
				Data = profile.Data,
				LockedBy = if release then nil else serverId,
				LockedAt = if release then nil else os.time(),
			}
			return record, { userId } -- the user id is stored with the data (Roblox asks for this)
		end)
	end)
	savesRunning -= 1

	if not ok then
		return "Failed"
	end
	return if lostLock then "LostLock" else "Saved"
end

local function autosaveLoop(player: Player, profile: Profile)
	while true do
		task.wait(Config.Save.AutosaveInterval)
		if profiles[player] ~= profile or profile.Released then
			return -- they left, so the leave-save takes care of it
		end
		if writeSave(player.UserId, profile, false) == "LostLock" and profiles[player] == profile then
			player:Kick("Your progress was opened on another server. Please rejoin.")
			return
		end
	end
end

type LoadResult = "Loaded" | "Locked" | "Failed"

-- One attempt to load and lock a player's save.
local function tryLoad(player: Player, activeStore: DataStore): (LoadResult, Types.SaveData?)
	local result: LoadResult = "Failed"
	local loaded: Types.SaveData? = nil
	local ok = withRetry(`Loading {player.Name}`, function()
		result = "Failed"
		activeStore:UpdateAsync(keyFor(player.UserId), function(stored: any): (any, { number }?)
			local lockedBy = if typeof(stored) == "table" then stored.LockedBy else nil
			local lockedAt = if typeof(stored) == "table" then stored.LockedAt else nil
			if
				typeof(lockedBy) == "string"
				and lockedBy ~= serverId
				and typeof(lockedAt) == "number"
				and os.time() - lockedAt < Config.Save.LockTimeout
			then
				result = "Locked" -- another server is still using this save
				return nil, nil
			end

			local cleanOk, data = pcall(cleanUp, if typeof(stored) == "table" then stored.Data else nil)
			if not cleanOk then
				warn(`[Save] Can't read {player.Name}'s save: {data}`)
				return nil, nil -- result stays "Failed"
			end
			loaded = data
			result = "Loaded"
			return { Data = data, LockedBy = serverId, LockedAt = os.time() }, { player.UserId }
		end)
	end)
	if not ok then
		return "Failed", nil
	end
	return result, loaded
end

-- Add what the player earned before their save finished loading (it's in `early`).
local function merge(saved: Types.SaveData, early: Types.SaveData)
	saved.Embers += early.Embers
	for name, value in early.Stats do
		saved.Stats[name] = (saved.Stats[name] or 0) + value
	end
	for _, unlock in early.Unlocks do
		if not table.find(saved.Unlocks, unlock) then
			table.insert(saved.Unlocks, unlock)
		end
	end
end

local function load(player: Player, profile: Profile, activeStore: DataStore)
	local result: LoadResult = "Failed"
	for attempt = 1, Config.Save.LockedRetries do
		local data: Types.SaveData?
		result, data = tryLoad(player, activeStore)
		if result == "Loaded" and data then
			merge(data, profile.Data)
			profile.Data = data
			profile.Loaded = true
			if profiles[player] == profile then
				show(player, data)
				task.spawn(autosaveLoop, player, profile)
			elseif not profile.Released then
				-- They left while we were loading: save and unlock right away.
				profile.Released = true
				writeSave(player.UserId, profile, true)
			end
			return
		elseif result == "Locked" and attempt < Config.Save.LockedRetries then
			task.wait(Config.Save.LockedWait)
		elseif result ~= "Locked" then
			break
		end
	end

	if profiles[player] == profile then
		if result == "Locked" then
			player:Kick("Your progress is still saving from your last server. Please rejoin in a moment.")
		else
			player:Kick("Your progress couldn't be loaded. Please rejoin.")
		end
	end
end

local function onPlayerAdded(player: Player)
	if profiles[player] then
		return
	end
	-- Start with an empty save so Embers and stats work right away.
	-- Anything earned before the real save loads is added to it (see merge).
	local profile: Profile = { Data = newData(), Loaded = false, Released = false }
	profiles[player] = profile
	show(player, profile.Data)

	local activeStore = store
	if activeStore then
		load(player, profile, activeStore)
	elseif RunService:IsStudio() then
		task.delay(3, function()
			notifyRemote:FireClient(player, "Saving is OFF in this test. See the Output window.")
		end)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile and profile.Loaded and not profile.Released then
		profile.Released = true
		writeSave(player.UserId, profile, true)
	end
end

local function onClose()
	-- Save everyone who's still here, all at the same time.
	for player, profile in profiles do
		profiles[player] = nil
		if profile.Loaded and not profile.Released then
			profile.Released = true
			task.spawn(writeSave, player.UserId, profile, true)
		end
	end
	-- Wait for every save to finish (including ones started by players leaving),
	-- but not forever: Roblox shuts the server down after about 30 seconds anyway.
	local deadline = os.clock() + Config.Save.ShutdownWait
	while savesRunning > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

-- Get the DataStore, or nil (with a warning) if saving can't work here.
local function openStore(): DataStore?
	local offHelp = 'Publish the place (File > Publish to Roblox) and turn on "Enable Studio Access to API Services" (Home > Game Settings > Security).'
	if game.PlaceId == 0 then
		warn(`[Save] Saving is OFF: this place isn't published. {offHelp}`)
		return nil
	end
	local ok, result = pcall(function(): DataStore
		return DataStoreService:GetDataStore(Config.Save.StoreName)
	end)
	if not ok then
		warn(`[Save] Saving is OFF: {result}. {offHelp}`)
		return nil
	end
	if RunService:IsStudio() then
		-- Studio can block DataStores even in a published place. Try one read to find out.
		local readOk, err = pcall(function()
			result:GetAsync("StudioCheck")
		end)
		if not readOk then
			warn(`[Save] Saving is OFF: {err}. {offHelp}`)
			return nil
		end
	end
	return result
end

-- The player's save, for other systems to change. Changes are written by the autosave and
-- when the player leaves. nil if the player has already left.
function SaveManager.getData(player: Player): Types.SaveData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Add to one of the player's lifetime stats (a name from STAT_NAMES, like "TreesFelled").
function SaveManager.addStat(player: Player, name: string, amount: number)
	if not isStat[name] then
		warn(`[Save] Unknown stat "{name}"`)
		return
	end
	local data = SaveManager.getData(player)
	if not data then
		return
	end
	data.Stats[name] = (data.Stats[name] or 0) + amount
	player:SetAttribute(`Stat_{name}`, data.Stats[name])
end

-- Does the player own this permanent unlock (like "Truck_StakeHauler")?
function SaveManager.hasUnlock(player: Player, name: string): boolean
	local data = SaveManager.getData(player)
	return data ~= nil and table.find(data.Unlocks, name) ~= nil
end

-- Give the player a permanent unlock. It's saved with the next save (or call saveNow).
function SaveManager.addUnlock(player: Player, name: string)
	local data = SaveManager.getData(player)
	if not data then
		return
	end
	if not table.find(data.Unlocks, name) then
		table.insert(data.Unlocks, name)
	end
	player:SetAttribute(`Unlock_{name}`, true)
end

-- Save the player right away (for Robux purchases: Roblox wants them saved before we say
-- "done"). Returns true if it worked; false if saving is off, their save hasn't loaded yet,
-- or the DataStore failed.
function SaveManager.saveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile or profile.Released then
		return false
	end
	return writeSave(player.UserId, profile, false) == "Saved"
end

function SaveManager.init() end

function SaveManager.start()
	notifyRemote = Remotes.getEvent("Notify")
	store = openStore()
	if store and Config.DebugPrints then
		print(`[Save] Saving is ON (DataStore "{Config.Save.StoreName}")`)
	end

	game:BindToClose(onClose)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined while we were opening the DataStore.
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return SaveManager
