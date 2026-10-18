--!strict
--[=[
	useServerClock: the server's clock (workspace:GetServerTimeNow()), refreshed every `interval` seconds
	(default 0.25), so a component counting down to a server deadline re-renders on its own.

	`running` (default true) false stops the refresh: the component then reads the clock as of each render it gets for
	other reasons and is not re-rendered by the clock, so a widget with nothing counting down (an idle prompt chip, an
	overlay that is not showing) costs nothing four times a second.

	@class useServerClock
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)

local DEFAULT_INTERVAL = 0.25

local function useServerClock(interval: number?, running: boolean?): number
	local _now, setNow = React.useState(0)
	local period = interval or DEFAULT_INTERVAL
	local ticking = running ~= false
	React.useEffect(function()
		if not ticking then
			return function() end
		end
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(period)
				if alive then
					setNow(Workspace:GetServerTimeNow())
				end
			end
		end)
		return function()
			alive = false
		end
	end, { period, if ticking then 1 else 0 })
	-- Read at render: the state above only schedules the re-renders, so a render for any reason (or the first one
	-- after the refresh resumes) never shows a stale time.
	return Workspace:GetServerTimeNow()
end

return useServerClock
