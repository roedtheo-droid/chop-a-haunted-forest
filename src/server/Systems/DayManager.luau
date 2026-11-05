--!strict
-- Starts the day and night clock when the server starts (one server = one run), and says on
-- ReplicatedStorage whether it's night right now. The time itself is worked out by
-- Shared/DayClock from the start time, so the server never has to send the time every second.
-- Night doesn't change anything else yet (no darker lighting, mimics act the same: see
-- Config.Day.NightMimicBoost).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DayClock = require(ReplicatedStorage.Shared.DayClock)

local DayManager = {}

local startedAt = 0

-- Is it night right now? (For other systems, later.)
function DayManager.isNight(): boolean
	return DayClock.state(startedAt, workspace:GetServerTimeNow()).IsNight
end

function DayManager.init()
	startedAt = workspace:GetServerTimeNow()
	ReplicatedStorage:SetAttribute(DayClock.STARTED_AT, startedAt)
	ReplicatedStorage:SetAttribute(DayClock.IS_NIGHT, false)
end

function DayManager.start()
	-- Once a second is plenty: day and night last minutes.
	while true do
		local night = DayManager.isNight()
		if ReplicatedStorage:GetAttribute(DayClock.IS_NIGHT) ~= night then
			ReplicatedStorage:SetAttribute(DayClock.IS_NIGHT, night)
		end
		task.wait(1)
	end
end

return DayManager
