--!strict
--[=[
	QueueArrivalTracker: an arrival server's party. Who is expected (from the first ticket seen), who has
	arrived, and when the wait is over: once everyone expected has shown up, or `timeout` seconds after the
	first arrival. Decides each joining player's admission. Plain bookkeeping keyed by UserIds;
	QueueArrivalSystem reads join data and does the teleports.

	Seats are kept for expected players still on their way, so a stranger following a friend in never
	takes a party member's place. After the party has started, an expected straggler is "late" (the game
	decides what to do) and a stranger is redirected.

	@class QueueArrivalTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)

type QueueTicket = QueueTypes.QueueTicket

export type QueueArrivalTracker = {
	expect: (self: QueueArrivalTracker, ticket: QueueTicket, now: number) -> (),
	join: (self: QueueArrivalTracker, userId: number, now: number) -> QueueTypes.Admission,
	leave: (self: QueueArrivalTracker, userId: number) -> (),
	ready: (self: QueueArrivalTracker, now: number) -> boolean,
	close: (self: QueueArrivalTracker) -> { number },
	isClosed: (self: QueueArrivalTracker) -> boolean,
	ticket: (self: QueueArrivalTracker) -> QueueTicket?,
	crew: (self: QueueArrivalTracker) -> { number },
}

local QueueArrivalTracker = {}

function QueueArrivalTracker.new(timeout: number, defaultCapacity: number): QueueArrivalTracker
	local current: QueueTicket? = nil
	local crew: { number } = {}
	local seen: { [number]: boolean } = {}
	local startedAt: number? = nil
	local closed = false

	local function isExpected(userId: number): boolean
		local ticket = current
		return ticket ~= nil and table.find(ticket.party, userId) ~= nil
	end

	-- Seats left for strangers: capacity minus the crew minus expected players still on their way.
	local function room(): number
		local ticket = current
		local capacity = if ticket ~= nil then ticket.capacity else defaultCapacity
		local coming = 0
		if ticket ~= nil then
			for _, userId in ticket.party do
				if not seen[userId] then
					coming += 1
				end
			end
		end
		return capacity - #crew - coming
	end

	local function board(userId: number)
		if table.find(crew, userId) == nil then
			table.insert(crew, userId)
		end
	end

	local tracker: QueueArrivalTracker
	tracker = {
		-- The first ticket wins (one reserved server per departure); the wait starts at the first arrival.
		expect = function(_self, ticket, now)
			if current == nil then
				current = ticket
			end
			if startedAt == nil then
				startedAt = now
			end
		end,

		join = function(_self, userId, now)
			if startedAt == nil then
				startedAt = now
			end
			local expected = isExpected(userId)
			if closed then
				if expected then
					board(userId)
					return "late"
				end
				return "redirect"
			end
			if expected then
				seen[userId] = true
				board(userId)
				return "crew"
			end
			if room() > 0 then
				board(userId)
				return "crew"
			end
			return "redirect"
		end,

		leave = function(_self, userId)
			local index = table.find(crew, userId)
			if index ~= nil then
				table.remove(crew, index)
			end
			if isExpected(userId) then
				seen[userId] = true
			end
		end,

		ready = function(_self, now)
			local began = startedAt
			if closed or began == nil then
				return false
			end
			if now - began >= timeout then
				return true
			end
			local ticket = current
			if ticket == nil or #ticket.party == 0 then
				return false
			end
			for _, userId in ticket.party do
				if not seen[userId] then
					return false
				end
			end
			return true
		end,

		close = function(_self)
			closed = true
			return table.clone(crew)
		end,

		isClosed = function(_self)
			return closed
		end,

		ticket = function(_self)
			return current
		end,

		crew = function(_self)
			return table.clone(crew)
		end,
	}
	return tracker
end

return QueueArrivalTracker
