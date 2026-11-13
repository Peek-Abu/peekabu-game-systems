--!strict
--[=[
	OfficeBuildPaceTracker: keeps a map build from holding the server. A whole Office or School build (generation,
	shell, furniture, decor, doors, grounds, dressing) is seconds of work; run in one resumption it freezes every player
	on the server and trips Play's script timeout. Each build pass calls `step` between pieces (a room, a wall, a prop):
	once the current stretch has run BUILD_SLICE_SECONDS it yields one frame (task.wait), so no resumption runs much
	past the slice. Plain bookkeeping: when the stretch began, the longest stretch seen and how many yields (the
	numbers a probe reads to prove the build stays sliced).

	`shared` is the one pace every build pass steps through (builds run one at a time on the shift's thread);
	`OfficeBuildPaceTracker.step()` steps it. A caller that starts a build calls `shared:begin()` first, so time spent
	before the build is not charged to its first stretch.

	@class OfficeBuildPaceTracker
]=]

local OfficeConstants = require(script.Parent.Parent.Data.OfficeConstants)

export type Stats = {
	-- The longest stretch between yields so far (seconds), the current one included.
	longest: number,
	yields: number,
}

export type OfficeBuildPaceTracker = {
	-- Starts a new stretch now and clears the stats.
	begin: (self: OfficeBuildPaceTracker) -> (),
	-- Yields one frame when the current stretch has reached the budget; returns whether it yielded.
	step: (self: OfficeBuildPaceTracker) -> boolean,
	stats: (self: OfficeBuildPaceTracker) -> Stats,
}

local OfficeBuildPaceTracker = {}

function OfficeBuildPaceTracker.new(budget: number, clock: (() -> number)?, wait: (() -> ())?): OfficeBuildPaceTracker
	local now = clock or os.clock
	local yieldFrame = wait or function()
		task.wait()
	end
	local started = now()
	local longest = 0
	local yields = 0

	local tracker: OfficeBuildPaceTracker = {
		begin = function(_self)
			started = now()
			longest = 0
			yields = 0
		end,

		step = function(_self)
			local stretch = now() - started
			if stretch < budget then
				return false
			end
			longest = math.max(longest, stretch)
			yields += 1
			yieldFrame()
			started = now()
			return true
		end,

		stats = function(_self)
			return { longest = math.max(longest, now() - started), yields = yields }
		end,
	}
	return tracker
end

OfficeBuildPaceTracker.shared = OfficeBuildPaceTracker.new(OfficeConstants.BUILD_SLICE_SECONDS)

function OfficeBuildPaceTracker.step(): boolean
	return OfficeBuildPaceTracker.shared:step()
end

return OfficeBuildPaceTracker
