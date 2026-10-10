--!strict
--[=[
	QueueDepartureTracker: teleports in flight, per player. A departure is a group sent together; each
	member is outstanding until they leave the server (teleported) or are given up on. Failures count per
	player and only while that player's attempt is in flight (so a watchdog timeout and a late
	TeleportInitFailed for one attempt count once); a partial failure therefore retries only the players
	it hit. Plain bookkeeping keyed by UserIds; QueueTeleportSystem talks to TeleportService.

	@class QueueDepartureTracker
]=]

type Member = { departure: number, failures: number, since: number? }

type Departure = { outstanding: number, gaveUp: { number }, reason: string? }

export type Outcome = { gaveUp: { number }, reason: string? }

export type QueueDepartureTracker = {
	begin: (self: QueueDepartureTracker, userIds: { number }) -> number?,
	departureOf: (self: QueueDepartureTracker, userId: number) -> number?,
	attempt: (self: QueueDepartureTracker, userId: number, now: number) -> (),
	fail: (self: QueueDepartureTracker, userId: number) -> number?,
	giveUp: (self: QueueDepartureTracker, userId: number, reason: string) -> number?,
	arrive: (self: QueueDepartureTracker, userId: number) -> number?,
	finished: (self: QueueDepartureTracker, departure: number) -> Outcome?,
	stale: (self: QueueDepartureTracker, now: number, watchdog: number) -> { number },
}

local QueueDepartureTracker = {}

function QueueDepartureTracker.new(): QueueDepartureTracker
	local members: { [number]: Member } = {}
	local departures: { [number]: Departure } = {}
	local nextId = 0

	-- Ends a member's part in their departure; returns the departure id, or nil when they had none.
	local function settle(userId: number): number?
		local member = members[userId]
		if member == nil then
			return nil
		end
		members[userId] = nil
		local departure = departures[member.departure]
		if departure ~= nil then
			departure.outstanding -= 1
		end
		return member.departure
	end

	local tracker: QueueDepartureTracker
	tracker = {
		--[=[
			A new departure for `userIds`; a player already in flight stays with their first departure. Nil
			when nobody is free to go: an empty departure would otherwise report a success nobody had.
		]=]
		begin = function(_self, userIds)
			local fresh: { number } = {}
			for _, userId in userIds do
				if members[userId] == nil and table.find(fresh, userId) == nil then
					table.insert(fresh, userId)
				end
			end
			if #fresh == 0 then
				return nil
			end
			nextId += 1
			departures[nextId] = { outstanding = #fresh, gaveUp = {}, reason = nil }
			for _, userId in fresh do
				members[userId] = { departure = nextId, failures = 0, since = nil }
			end
			return nextId
		end,

		departureOf = function(_self, userId)
			local member = members[userId]
			return if member ~= nil then member.departure else nil
		end,

		-- An attempt for this player started at `now` (os.clock()).
		attempt = function(_self, userId, now)
			local member = members[userId]
			if member ~= nil then
				member.since = now
			end
		end,

		-- Counts a failure of the attempt in flight: the player's failures so far, or nil.
		fail = function(_self, userId)
			local member = members[userId]
			if member == nil or member.since == nil then
				return nil
			end
			member.failures += 1
			member.since = nil
			return member.failures
		end,

		giveUp = function(_self, userId, reason)
			local member = members[userId]
			if member == nil then
				return nil
			end
			local departure = departures[member.departure]
			if departure ~= nil then
				table.insert(departure.gaveUp, userId)
				departure.reason = reason
			end
			return settle(userId)
		end,

		-- The player left the server: their teleport went through.
		arrive = function(_self, userId)
			return settle(userId)
		end,

		-- The outcome once nobody is outstanding (reported once), else nil.
		finished = function(_self, id)
			local departure = departures[id]
			if departure == nil or departure.outstanding > 0 then
				return nil
			end
			departures[id] = nil
			return { gaveUp = departure.gaveUp, reason = departure.reason }
		end,

		stale = function(_self, now, watchdog)
			local list: { number } = {}
			for userId, member in members do
				local since = member.since
				if since ~= nil and now - since >= watchdog then
					table.insert(list, userId)
				end
			end
			table.sort(list)
			return list
		end,
	}
	return tracker
end

return QueueDepartureTracker
