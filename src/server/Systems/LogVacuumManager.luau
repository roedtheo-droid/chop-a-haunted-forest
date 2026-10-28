--!strict
-- The Log Vacuum: players who bought it pull nearby logs into their backpack.
-- Runs on the server a few times a second, so the client can't fake pickups.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local LogManager = require(script.Parent.LogManager)
local UpgradeManager = require(script.Parent.UpgradeManager)

local LogVacuumManager = {}

-- How many logs are flying to each player right now (so we don't pull more than fits).
local inFlight: { [Player]: number } = {}

local function setPromptEnabled(log: BasePart, enabled: boolean)
	local prompt = log:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = enabled
	end
end

local function pull(player: Player, log: BasePart, target: Vector3)
	local startCFrame = log.CFrame
	log:SetAttribute("Pulling", true)
	setPromptEnabled(log, false) -- nobody else can grab it mid-air
	inFlight[player] = (inFlight[player] or 0) + 1

	local tween = TweenService:Create(
		log,
		TweenInfo.new(Config.LogVacuum.PullTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(target) }
	)
	tween.Completed:Connect(function()
		inFlight[player] = math.max((inFlight[player] or 1) - 1, 0)
		if log.Parent == nil then
			return
		end
		if not LogManager.tryPickUp(player, log) then
			-- No room after all (or the player left): put the log back where it was.
			log.CFrame = startCFrame
			log:SetAttribute("Pulling", nil)
			setPromptEnabled(log, true)
		end
	end)
	tween:Play()
end

local function vacuumFor(player: Player)
	if UpgradeManager.getLevel(player, "LogVacuum") < 1 then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return
	end

	local room = player:GetAttribute("CarryLimit")
	local free = (if typeof(room) == "number" then room else 0) - LogManager.getCarry(player) - (inFlight[player] or 0)
	if free <= 0 then
		return
	end

	for _, log in LogManager.getLogs() do
		if free <= 0 then
			break
		end
		-- Logs still popping out of their tree land first, so the pop looks right on every screen.
		if log:IsA("BasePart") and not log:GetAttribute("Pulling") and not LogManager.isPopping(log) then
			if (log.Position - root.Position).Magnitude <= Config.LogVacuum.Radius then
				pull(player, log, root.Position)
				free -= 1
			end
		end
	end
end

function LogVacuumManager.init() end

function LogVacuumManager.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		inFlight[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.LogVacuum.Interval)
			for _, player in Players:GetPlayers() do
				vacuumFor(player)
			end
		end
	end)
end

return LogVacuumManager
