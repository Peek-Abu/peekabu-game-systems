--!strict
--[=[
	useServerClock: the server's clock (workspace:GetServerTimeNow()), refreshed every `interval` seconds
	(default 0.25), so a component counting down to a server deadline re-renders on its own.

	@class useServerClock
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)

local DEFAULT_INTERVAL = 0.25

local function useServerClock(interval: number?): number
	local initial: number = Workspace:GetServerTimeNow()
	local now, setNow = React.useState(initial)
	local period = interval or DEFAULT_INTERVAL
	React.useEffect(function()
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
	end, { period })
	return now
end

return useServerClock
