--!strict
--[=[
	ReplicationStateTimingUtils: when a timed body state ends (character replication R3). Shared so the server's store
	and every client agree without a message: a state with a duration ends at `startMs + durationMs`; an
	open-ended one (no duration, e.g. a looping pose) ends at the safety cap, `startMs + MAX_OPEN_STATE_MS`,
	so a grant nobody stops cannot run forever on any screen.

	Times are session ms (the replication session clock both ends share). Pure.

	@class ReplicationStateTimingUtils
]=]

local ReplicationStateTimingUtils = {}

-- The safety cap for an open-ended state (a forgotten looping action ends here on every screen).
ReplicationStateTimingUtils.MAX_OPEN_STATE_MS = 30000

--[=[
	When a state ends: start + duration, or start + the safety cap when it has no duration.
]=]
function ReplicationStateTimingUtils.endMs(startMs: number, durationMs: number?): number
	return startMs + (if durationMs ~= nil then durationMs else ReplicationStateTimingUtils.MAX_OPEN_STATE_MS)
end

--[=[
	True once `nowMs` has reached the state's end.
]=]
function ReplicationStateTimingUtils.isOver(startMs: number, durationMs: number?, nowMs: number): boolean
	return nowMs >= ReplicationStateTimingUtils.endMs(startMs, durationMs)
end

return ReplicationStateTimingUtils
