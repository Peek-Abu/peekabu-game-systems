--!strict
--[=[
	ShiftCrewTracker: who the crew is on this server, and whether it is on its way home (Cleanup Crew spec §3
	steps 3 and 7, §6.5). The crew is the party that arrived (Queue `arrived`; a second party joins a crew
	still here, and replaces one that has gone) plus expected members who came late. A player leaves it by
	leaving the server or by being moved back to the depot. After Back to depot the crew is "leaving" for a
	while: `startable` is 0, so no shift starts under a crew whose return trip is still in flight; once the
	window has passed, `expired` reports it once and the crew still here can work again. Plain bookkeeping
	(pure).

	@class ShiftCrewTracker
]=]

export type ShiftCrewTracker = {
	join: (self: ShiftCrewTracker, userIds: { number }, presentIds: { number }) -> (),
	add: (self: ShiftCrewTracker, userId: number) -> boolean,
	remove: (self: ShiftCrewTracker, userId: number) -> boolean,
	has: (self: ShiftCrewTracker, userId: number) -> boolean,
	present: (self: ShiftCrewTracker, presentIds: { number }) -> { number },
	leave: (self: ShiftCrewTracker, now: number, wait: number) -> (),
	isLeaving: (self: ShiftCrewTracker, now: number) -> boolean,
	expired: (self: ShiftCrewTracker, now: number) -> boolean,
	startable: (self: ShiftCrewTracker, presentIds: { number }, now: number) -> number,
	clear: (self: ShiftCrewTracker) -> (),
}

local ShiftCrewTracker = {}

function ShiftCrewTracker.new(): ShiftCrewTracker
	local members: { [number]: boolean } = {}
	local leavingUntil: number? = nil

	local tracker: ShiftCrewTracker
	tracker = {
		join = function(self, userIds, presentIds)
			if #self:present(presentIds) == 0 then
				table.clear(members)
				leavingUntil = nil
			end
			for _, userId in userIds do
				members[userId] = true
			end
		end,

		add = function(_self, userId)
			if members[userId] then
				return false
			end
			members[userId] = true
			return true
		end,

		remove = function(_self, userId)
			if not members[userId] then
				return false
			end
			members[userId] = nil
			return true
		end,

		has = function(_self, userId)
			return members[userId] == true
		end,

		present = function(_self, presentIds)
			local ids: { number } = {}
			for _, userId in presentIds do
				if members[userId] and not table.find(ids, userId) then
					table.insert(ids, userId)
				end
			end
			table.sort(ids)
			return ids
		end,

		leave = function(_self, now, wait)
			leavingUntil = now + wait
		end,

		isLeaving = function(_self, now)
			local untilTime = leavingUntil
			return untilTime ~= nil and now < untilTime
		end,

		expired = function(_self, now)
			local untilTime = leavingUntil
			if untilTime == nil or now < untilTime then
				return false
			end
			leavingUntil = nil
			return true
		end,

		startable = function(self, presentIds, now)
			if self:isLeaving(now) then
				return 0
			end
			return #self:present(presentIds)
		end,

		clear = function(_self)
			table.clear(members)
			leavingUntil = nil
		end,
	}
	return tracker
end

return ShiftCrewTracker
