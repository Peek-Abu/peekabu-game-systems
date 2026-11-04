--!strict
--[=[
	InteractionChannelTracker: who is channeling which target, and each target's progress (0-1). Plain
	bookkeeping keyed by numbers (UserIds, target ids); InteractionChannelSystem owns the Instances.

	A player channels at most one target. Progress is kept when everyone stops. `advance` returns the
	players on a target exactly once, the tick it reaches 1, and forgets the target. Each player adds
	`dt / duration` times their rate (`rateOf`, absent = 1; a missing, non-finite or non-positive rate counts as 1).

	@class InteractionChannelTracker
]=]

export type InteractionChannelTracker = {
	start: (self: InteractionChannelTracker, userId: number, targetId: number) -> (),
	stop: (self: InteractionChannelTracker, userId: number) -> number?,
	targetOf: (self: InteractionChannelTracker, userId: number) -> number?,
	channelers: (self: InteractionChannelTracker, targetId: number) -> { number },
	progress: (self: InteractionChannelTracker, targetId: number) -> number,
	advance: (
		self: InteractionChannelTracker,
		targetId: number,
		dt: number,
		duration: number,
		rateOf: ((userId: number) -> number?)?
	) -> { number }?,
	reset: (self: InteractionChannelTracker, targetId: number) -> (),
	activeTargets: (self: InteractionChannelTracker) -> { number },
}

local InteractionChannelTracker = {}

-- A player's rate: a positive finite number, else 1.
local function rateFor(rateOf: ((userId: number) -> number?)?, userId: number): number
	local rate = if rateOf ~= nil then rateOf(userId) else nil
	return if rate ~= nil and rate > 0 and rate < math.huge then rate else 1
end

function InteractionChannelTracker.new(): InteractionChannelTracker
	local targetByUser: { [number]: number } = {}
	local progressByTarget: { [number]: number } = {}

	local tracker: InteractionChannelTracker
	tracker = {
		start = function(_self, userId, targetId)
			targetByUser[userId] = targetId
		end,

		stop = function(_self, userId)
			local targetId = targetByUser[userId]
			targetByUser[userId] = nil
			return targetId
		end,

		targetOf = function(_self, userId)
			return targetByUser[userId]
		end,

		channelers = function(_self, targetId)
			local list: { number } = {}
			for userId, current in targetByUser do
				if current == targetId then
					table.insert(list, userId)
				end
			end
			table.sort(list)
			return list
		end,

		progress = function(_self, targetId)
			return progressByTarget[targetId] or 0
		end,

		advance = function(self, targetId, dt, duration, rateOf)
			local players = self:channelers(targetId)
			if #players == 0 then
				return nil
			end
			local rates = 0
			for _, userId in players do
				rates += rateFor(rateOf, userId)
			end
			local nextProgress = (progressByTarget[targetId] or 0) + dt * rates / duration
			if nextProgress < 1 then
				progressByTarget[targetId] = nextProgress
				return nil
			end
			self:reset(targetId)
			return players
		end,

		reset = function(_self, targetId)
			progressByTarget[targetId] = nil
			for userId, current in targetByUser do
				if current == targetId then
					targetByUser[userId] = nil
				end
			end
		end,

		activeTargets = function(_self)
			local seen: { [number]: true } = {}
			local list: { number } = {}
			for _, targetId in targetByUser do
				if not seen[targetId] then
					seen[targetId] = true
					table.insert(list, targetId)
				end
			end
			table.sort(list)
			return list
		end,
	}
	return tracker
end

return InteractionChannelTracker
