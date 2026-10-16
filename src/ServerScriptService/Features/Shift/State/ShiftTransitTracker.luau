--!strict
--[=[
	ShiftTransitTracker: who a transit holds behind the load screen (ShiftTransitSystem). A hold is a group of players
	under one id with a deadline; each player is placed (built, with their spot and the office's seed) and then reports
	ready for that id. `status` says whether a hold is still waiting, ready (everyone in it reported), timed out or
	empty (everyone left). A ready player stays held (still anchored, waiting for the crew) but leaves the published
	`list`, so their screen clears. Bookkeeping only (no Instances, no time source: `now` is passed in).

	@class ShiftTransitTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type TransitHold = ShiftTypes.TransitHold

export type TransitStatus = "waiting" | "ready" | "timeout" | "empty"

type Entry = {
	id: number,
	built: boolean,
	ready: boolean,
	seed: number?,
	spot: Vector3?,
}

export type ShiftTransitTracker = {
	hold: (self: ShiftTransitTracker, userIds: { number }, now: number, timeout: number) -> number,
	join: (self: ShiftTransitTracker, userId: number, id: number) -> boolean,
	place: (self: ShiftTransitTracker, userId: number, spot: Vector3, seed: number?) -> (),
	markReady: (self: ShiftTransitTracker, userId: number, id: number) -> boolean,
	release: (self: ShiftTransitTracker, userId: number) -> boolean,
	isHeld: (self: ShiftTransitTracker, userId: number) -> boolean,
	idOf: (self: ShiftTransitTracker, userId: number) -> number?,
	spotOf: (self: ShiftTransitTracker, userId: number) -> Vector3?,
	members: (self: ShiftTransitTracker, id: number) -> { number },
	unready: (self: ShiftTransitTracker, id: number) -> { number },
	status: (self: ShiftTransitTracker, id: number, now: number) -> TransitStatus,
	list: (self: ShiftTransitTracker) -> { TransitHold },
	clear: (self: ShiftTransitTracker) -> (),
}

local ShiftTransitTracker = {}

function ShiftTransitTracker.new(): ShiftTransitTracker
	local entries: { [number]: Entry } = {}
	local deadlines: { [number]: number } = {}
	local nextId = 0

	local function sortedIds(filter: (userId: number, entry: Entry) -> boolean): { number }
		local ids: { number } = {}
		for userId, entry in entries do
			if filter(userId, entry) then
				table.insert(ids, userId)
			end
		end
		table.sort(ids)
		return ids
	end

	local tracker: ShiftTransitTracker = {
		hold = function(_self, userIds, now, timeout)
			nextId += 1
			deadlines[nextId] = now + timeout
			for _, userId in userIds do
				entries[userId] = { id = nextId, built = false, ready = false }
			end
			return nextId
		end,

		join = function(_self, userId, id)
			if deadlines[id] == nil then
				return false
			end
			entries[userId] = { id = id, built = false, ready = false }
			return true
		end,

		place = function(_self, userId, spot, seed)
			local entry = entries[userId]
			if entry == nil then
				return
			end
			entry.built = true
			entry.spot = spot
			entry.seed = seed
		end,

		markReady = function(_self, userId, id)
			local entry = entries[userId]
			if entry == nil or entry.id ~= id or not entry.built or entry.ready then
				return false
			end
			entry.ready = true
			return true
		end,

		release = function(_self, userId)
			if entries[userId] == nil then
				return false
			end
			entries[userId] = nil
			return true
		end,

		isHeld = function(_self, userId)
			return entries[userId] ~= nil
		end,

		idOf = function(_self, userId)
			local entry = entries[userId]
			return if entry ~= nil then entry.id else nil
		end,

		spotOf = function(_self, userId)
			local entry = entries[userId]
			return if entry ~= nil then entry.spot else nil
		end,

		members = function(_self, id)
			return sortedIds(function(_userId, entry)
				return entry.id == id
			end)
		end,

		unready = function(_self, id)
			return sortedIds(function(_userId, entry)
				return entry.id == id and not entry.ready
			end)
		end,

		status = function(self, id, now)
			local members = self:members(id)
			if #members == 0 then
				return "empty"
			end
			if #self:unready(id) == 0 then
				return "ready"
			end
			local deadline = deadlines[id]
			if deadline ~= nil and now >= deadline then
				return "timeout"
			end
			return "waiting"
		end,

		list = function(_self)
			local list: { TransitHold } = {}
			for _, userId in
				sortedIds(function(_userId, entry)
					return not entry.ready
				end)
			do
				local entry = entries[userId]
				table.insert(list, {
					userId = userId,
					id = entry.id,
					built = entry.built,
					seed = entry.seed,
					spot = entry.spot,
				})
			end
			return list
		end,

		clear = function(_self)
			table.clear(entries)
			table.clear(deadlines)
		end,
	}
	return tracker
end

return ShiftTransitTracker
