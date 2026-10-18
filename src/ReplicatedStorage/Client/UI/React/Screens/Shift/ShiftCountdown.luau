--!strict
--[=[
	ShiftCountdown: one live "m:ss" countdown to a server-clock `deadline`, drawn by `render`. It owns its timer: it
	sleeps until the shown second changes (ShiftHudViewModel.untilTick) and re-renders only then, so the HUD around it
	(ShiftHud, ShiftCompactHudPanel) never subscribes to the clock and re-renders only when its own state changes.
	Used for the shift clock, the clock-out slip and a caught crew member's "back in" line.
	Presentational (exempt; the timing and the text are specced in ShiftHudViewModel.untilTick / clock).

	@class ShiftCountdown
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type Props = {
	-- The server-clock time (workspace:GetServerTimeNow()) it counts down to.
	deadline: number,
	-- Draws the countdown from its "m:ss" text.
	render: (clock: string) -> React.ReactNode,
}

local function shown(deadline: number): string
	return ShiftHudViewModel.clock(deadline - Workspace:GetServerTimeNow())
end

local function ShiftCountdown(props: Props): React.ReactNode
	local deadline = props.deadline
	-- The text last shown: setting it (only when it changed) is what re-renders this countdown.
	local _clock, setClock = React.useState(function(): string
		return shown(deadline)
	end)
	React.useEffect(function()
		local alive = true
		local thread = task.spawn(function()
			local last = shown(deadline)
			while alive do
				local wait = ShiftHudViewModel.untilTick(deadline - Workspace:GetServerTimeNow())
				if wait == nil then
					return
				end
				task.wait(wait)
				local next = shown(deadline)
				if alive and next ~= last then
					last = next
					setClock(next)
				end
			end
		end)
		return function()
			alive = false
			if coroutine.status(thread) == "suspended" then
				task.cancel(thread)
			end
		end
	end, { deadline })
	-- Read at render, so a new deadline (or a parent's re-render) never shows a stale second.
	return props.render(shown(deadline))
end

return ShiftCountdown
