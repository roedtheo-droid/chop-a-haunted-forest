--!strict
-- Being out of action, in two ways. Either way you can't move or swing:
--   * Flattened by the Elder Hollow's slam (knockDown): you're down for a while. A friend can hold E
--     on you (the "Revive" prompt) to get you back up sooner.
--   * Caught by a mimic (swallow): you're inside it. You mash a key to get out, or a friend chops you
--     out, or in the end it spits you out. MimicManager holds still and chews meanwhile.
--
-- Player attributes the client reads (only the server sets them):
--   KnockedDown     true while you're down, either way
--   DownUntil       when you get up or get spat out by yourself (server time, for the countdown)
--   DownCause       what happened: "Swallowed" or "Slam" (changes what's on screen)
--   EscapeProgress  0 to 1: how close you are to getting out of a mimic

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Types = require(ReplicatedStorage.Shared.Types)
local AnalyticsManager = require(script.Parent.AnalyticsManager)
local MovementManager = require(script.Parent.MovementManager)

type Swallow = {
	Progress: number, -- 0 to 1: at 1 they're out
	LastMash: number, -- when they last pressed the key (os.clock)
	Outside: CFrame, -- where they land when they get out
}

local KnockdownManager = {}

local notifyRemote: RemoteEvent
-- Each knockdown gets a number, so an old timer can't stand up a player
-- who has been knocked down again since.
local knockCount: { [Player]: number } = {}
local prompts: { [Player]: ProximityPrompt } = {}
local swallows: { [Player]: Swallow } = {}
-- Just after getting up, mimics can't catch you again straight away.
local safeUntil: { [Player]: number } = {}

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

function KnockdownManager.isDown(player: Player): boolean
	return player:GetAttribute("KnockedDown") == true
end

-- Is this player inside a mimic right now?
function KnockdownManager.isSwallowed(player: Player): boolean
	return swallows[player] ~= nil
end

-- Can a mimic catch this player right now?
function KnockdownManager.canBeCaught(player: Player): boolean
	local safe = safeUntil[player]
	return not KnockdownManager.isDown(player) and not (safe and os.clock() < safe)
end

function KnockdownManager.standUp(player: Player)
	if not KnockdownManager.isDown(player) then
		return
	end
	player:SetAttribute("KnockedDown", false)
	player:SetAttribute("DownUntil", nil)
	player:SetAttribute("EscapeProgress", nil)
	safeUntil[player] = os.clock() + Config.Knockdown.SafeTime
	local prompt = prompts[player]
	if prompt then
		prompt:Destroy()
		prompts[player] = nil
	end
	-- Out of a mimic: you land in front of it, and can move again.
	local swallow = swallows[player]
	if swallow then
		swallows[player] = nil
		local root = getRoot(player)
		local character = player.Character
		if root and character then
			character:PivotTo(swallow.Outside)
			root.Anchored = false
		end
	end
	MovementManager.refresh(player)
end

-- What's the same for both ways of being down. Returns this knockdown's number.
local function goDown(player: Player, why: Types.KnockdownCause, duration: number): number
	local count = (knockCount[player] or 0) + 1
	knockCount[player] = count
	-- The cause first, so every computer knows it by the time it hears you're down.
	player:SetAttribute("DownCause", why)
	player:SetAttribute("DownUntil", workspace:GetServerTimeNow() + duration)
	player:SetAttribute("KnockedDown", true)
	MovementManager.refresh(player)
	return count
end

local function onRevive(downPlayer: Player, helper: Player)
	if helper == downPlayer or KnockdownManager.isDown(helper) or not KnockdownManager.isDown(downPlayer) then
		return
	end
	-- The prompt is held on the helper's computer, so check the distance again here.
	local downRoot = getRoot(downPlayer)
	local helperRoot = getRoot(helper)
	if not (downRoot and helperRoot) then
		return
	end
	if (downRoot.Position - helperRoot.Position).Magnitude > Config.Knockdown.ReviveDistance + 2 then
		return
	end

	KnockdownManager.standUp(downPlayer)
	AnalyticsManager.event(helper, "RevivedFriend")
	notifyRemote:FireClient(downPlayer, `{helper.DisplayName} revived you!`)
	notifyRemote:FireClient(helper, `You revived {downPlayer.DisplayName}!`)
end

-- The Elder Hollow's slam flattens a player.
function KnockdownManager.knockDown(player: Player)
	local root = getRoot(player)
	if not (root and KnockdownManager.canBeCaught(player)) then
		return
	end

	local duration = Config.Boss.SlamKnockdown
	local count = goDown(player, "Slam", duration)
	AnalyticsManager.event(player, "SlammedByBoss")

	-- Friends hold E on you to revive you. (Your own screen hides this prompt.)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.Knockdown.ReviveHoldTime
	prompt.MaxActivationDistance = Config.Knockdown.ReviveDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	CollectionService:AddTag(prompt, Tags.RevivePrompt)
	prompt.Triggered:Connect(function(helper: Player)
		onRevive(player, helper)
	end)
	prompts[player] = prompt

	-- Tell everyone else, so they can come and help.
	for _, other in Players:GetPlayers() do
		if other ~= player then
			notifyRemote:FireClient(other, `{player.DisplayName} was flattened by the Elder Hollow! Hold E on them to revive them.`)
		end
	end

	task.delay(duration, function()
		-- Still down from THIS knockdown? (Not revived, reset or caught again since.)
		if knockCount[player] == count and KnockdownManager.isDown(player) then
			KnockdownManager.standUp(player)
			notifyRemote:FireClient(player, "You're back up. Run!")
		end
	end)
end

-- Get a player out of the mimic they're in. `helper` is who chopped them out, if anyone did.
function KnockdownManager.free(player: Player, helper: Player?)
	if not swallows[player] then
		return
	end
	local text = Config.Swallow.Text
	KnockdownManager.standUp(player)
	if helper and helper ~= player then
		AnalyticsManager.event(helper, "ChoppedFriendOut")
		notifyRemote:FireClient(player, string.format(text.ChoppedOut, helper.DisplayName))
		notifyRemote:FireClient(helper, string.format(text.YouChopped, player.DisplayName))
	else
		AnalyticsManager.event(player, "EscapedMimic")
		notifyRemote:FireClient(player, text.GotOut)
	end
end

-- A mimic swallows a player: they're held at `inside` until they get out, and land at `outside`.
function KnockdownManager.swallow(player: Player, inside: CFrame, outside: CFrame)
	if not KnockdownManager.canBeCaught(player) then
		return
	end
	local root = getRoot(player)
	local character = player.Character
	if not (root and character) then
		return
	end
	local cfg = Config.Swallow
	local count = goDown(player, "Swallowed", cfg.Time)
	swallows[player] = { Progress = 0, LastMash = 0, Outside = outside }
	player:SetAttribute("EscapeProgress", 0)
	root.Anchored = true
	character:PivotTo(inside)
	AnalyticsManager.event(player, "CaughtByMimic")

	-- Tell everyone else, so they can come and help.
	for _, other in Players:GetPlayers() do
		if other ~= player then
			notifyRemote:FireClient(other, string.format(cfg.Text.Swallowed, player.DisplayName))
		end
	end

	task.delay(cfg.Time, function()
		-- Still inside from THIS time? Then it spits them out.
		if knockCount[player] == count and swallows[player] then
			KnockdownManager.standUp(player)
			notifyRemote:FireClient(player, cfg.Text.SpatOut)
		end
	end)
end

local function addProgress(player: Player, amount: number, helper: Player?)
	local swallow = swallows[player]
	if not swallow then
		return
	end
	swallow.Progress = math.min(swallow.Progress + amount, 1)
	if swallow.Progress >= 1 then
		KnockdownManager.free(player, helper)
	else
		player:SetAttribute("EscapeProgress", swallow.Progress)
	end
end

-- A friend hit the mimic this player is in.
function KnockdownManager.chopOut(player: Player, helper: Player)
	addProgress(player, 1 / Config.Swallow.ChopOutHits, helper)
end

-- The player pressed the key to get out. No numbers come from the client: the server counts the
-- presses, and ignores any that come too fast.
local function onMash(player: Player)
	local swallow = swallows[player]
	if not swallow then
		return
	end
	local now = os.clock()
	if now - swallow.LastMash < Config.Swallow.MashGap then
		return
	end
	swallow.LastMash = now
	addProgress(player, 1 / Config.Swallow.MashNeeded)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("KnockedDown", false)
	-- A new character (after a reset) starts standing up, wherever it spawned.
	player.CharacterAdded:Connect(function()
		swallows[player] = nil
		KnockdownManager.standUp(player)
	end)
end

function KnockdownManager.init() end

function KnockdownManager.start()
	notifyRemote = Remotes.getEvent("Notify")
	Remotes.getEvent("MashEscape").OnServerEvent:Connect(onMash)

	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this ran (can happen in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		knockCount[player] = nil
		prompts[player] = nil
		swallows[player] = nil
		safeUntil[player] = nil
	end)
end

return KnockdownManager
