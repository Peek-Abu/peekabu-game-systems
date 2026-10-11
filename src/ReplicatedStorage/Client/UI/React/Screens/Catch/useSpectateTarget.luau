--!strict
--[=[
	useSpectateTarget: the UserId Death's spectate camera is following, or nil. DeathServiceClient:spectating() is a
	plain getter (not reactive), so this polls it every POLL_SECONDS and re-renders only when it changes. React hook
	(exempt: needs a renderer).

	@class useSpectateTarget
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DeathServiceClient = require(ReplicatedStorage.Client.Features.Death.DeathServiceClient)

local POLL_SECONDS = 0.2

local function readTarget(): number?
	return DeathServiceClient:spectating()
end

local function useSpectateTarget(): number?
	local target, setTarget = React.useState(readTarget)
	React.useEffect(function(): () -> ()
		local alive = true
		local last = readTarget()
		setTarget(last)
		task.spawn(function()
			while alive do
				task.wait(POLL_SECONDS)
				local now = readTarget()
				if alive and now ~= last then
					last = now
					setTarget(now)
				end
			end
		end)
		return function()
			alive = false
		end
	end, {})
	return target
end

return useSpectateTarget
