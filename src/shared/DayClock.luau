--!strict
-- The day and night clock, shared by the server and the client so they always agree.
-- One cycle is a day (Config.Day.DaySeconds) and then a night (Config.Day.NightSeconds).
-- The server writes when the clock started (DayClock.STARTED_AT on ReplicatedStorage, see
-- Server/Systems/DayManager); anyone can then work out the time from workspace:GetServerTimeNow().

local Config = require(script.Parent.Config)

local DayClock = {}

-- Attributes on ReplicatedStorage (only the server sets them).
DayClock.STARTED_AT = "DayStartedAt" -- the server time the first day began
DayClock.IS_NIGHT = "IsNight" -- true while it's night (for systems that only need to know that)

export type State = {
	IsNight: boolean,
	SecondsLeft: number, -- until night (in the day) or until morning (at night)
	Progress: number, -- how far into this day or night, from 0 to 1
}

-- Where in the cycle we are, `now - startedAt` seconds after the clock started.
function DayClock.state(startedAt: number, now: number): State
	local cfg = Config.Day
	local cycle = cfg.DaySeconds + cfg.NightSeconds
	local t = (now - startedAt) % cycle
	if t < cfg.DaySeconds then
		return { IsNight = false, SecondsLeft = cfg.DaySeconds - t, Progress = t / cfg.DaySeconds }
	end
	local intoNight = t - cfg.DaySeconds
	return { IsNight = true, SecondsLeft = cfg.NightSeconds - intoNight, Progress = intoNight / cfg.NightSeconds }
end

return table.freeze(DayClock)
