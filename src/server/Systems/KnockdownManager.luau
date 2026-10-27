--!strict
-- Getting caught by a mimic: you're knocked down and can't move for a while.
-- A friend can hold E on you (the "Revive" prompt) to get you back up sooner.
--
-- Player attributes the client reads (only the server sets them):
--   KnockedDown  true while you're down
--   DownUntil    when you get up by yourself (server time, for the countdown on screen)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local MovementManager = require(script.Parent.MovementManager)

local KnockdownManager = {}

local notifyRemote: RemoteEvent
-- Each knockdown gets a number, so an old timer can't stand up a player
-- who has been knocked down again since.
local knockCount: { [Player]: number } = {}
local prompts: { [Player]: ProximityPrompt } = {}
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
	safeUntil[player] = os.clock() + Config.Knockdown.SafeTime
	local prompt = prompts[player]
	if prompt then
		prompt:Destroy()
		prompts[player] = nil
	end
	MovementManager.refresh(player)
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
	notifyRemote:FireClient(downPlayer, `{helper.DisplayName} revived you!`)
	notifyRemote:FireClient(helper, `You revived {downPlayer.DisplayName}!`)
end

function KnockdownManager.knockDown(player: Player)
	if not KnockdownManager.canBeCaught(player) then
		return
	end
	local root = getRoot(player)
	if not root then
		return
	end

	local count = (knockCount[player] or 0) + 1
	knockCount[player] = count
	player:SetAttribute("KnockedDown", true)
	player:SetAttribute("DownUntil", workspace:GetServerTimeNow() + Config.Knockdown.Duration)
	MovementManager.refresh(player)

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
			notifyRemote:FireClient(other, `{player.DisplayName} was caught by a mimic! Hold E on them to revive them.`)
		end
	end

	task.delay(Config.Knockdown.Duration, function()
		-- Still down from THIS knockdown? (Not revived, reset or caught again since.)
		if knockCount[player] == count and KnockdownManager.isDown(player) then
			KnockdownManager.standUp(player)
			notifyRemote:FireClient(player, "You're back up. Run!")
		end
	end)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("KnockedDown", false)
	-- A new character (after a reset) starts standing up.
	player.CharacterAdded:Connect(function()
		KnockdownManager.standUp(player)
	end)
end

function KnockdownManager.init() end

function KnockdownManager.start()
	notifyRemote = Remotes.getEvent("Notify")

	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this ran (can happen in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		knockCount[player] = nil
		prompts[player] = nil
		safeUntil[player] = nil
	end)
end

return KnockdownManager
