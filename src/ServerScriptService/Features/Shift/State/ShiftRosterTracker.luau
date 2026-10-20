--!strict
--[=[
	ShiftRosterTracker: every crew member's run in the current shift, kept by UserId so what a player did stays
	in the crew totals after they leave. Lists are handed out as copies.

	@class ShiftRosterTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

export type Delta = {
	banked: number?,
	piles: number?,
	salvage: number?,
	caught: number?,
	noise: number?,
	woke: number?,
	-- Cargo items banked, and salvage banked during overtime (ShiftReviewSystem, from each accepted Load).
	items: number?,
	overtimeSalvage: number?,
}

export type ShiftRosterTracker = {
	-- Lists the player (at zero if new, under the name first seen) and adds `delta` to their run.
	record: (self: ShiftRosterTracker, userId: number, name: string, delta: Delta) -> (),
	-- One drop by hand (or a fragile throw); keeps the most valuable item dropped (the first on a tie).
	noteDrop: (self: ShiftRosterTracker, userId: number, name: string, kind: string, value: number) -> (),
	list: (self: ShiftRosterTracker) -> { ShiftTypes.CrewStats },
	-- Marks the player (listed at zero if new) as knocked out for the rest of the shift.
	markOut: (self: ShiftRosterTracker, userId: number, name: string) -> (),
	clear: (self: ShiftRosterTracker) -> (),
}

local ShiftRosterTracker = {}

function ShiftRosterTracker.new(): ShiftRosterTracker
	local roster: { [number]: ShiftTypes.CrewStats } = {}

	local function entryFor(userId: number, name: string): ShiftTypes.CrewStats
		local entry = roster[userId]
		if entry == nil then
			entry = {
				userId = userId,
				name = name,
				banked = 0,
				piles = 0,
				salvage = 0,
				caught = 0,
				drops = 0,
				noise = 0,
				woke = 0,
				items = 0,
				overtimeSalvage = 0,
			}
			roster[userId] = entry
		end
		return entry
	end

	local tracker: ShiftRosterTracker = {
		record = function(_self, userId, name, delta)
			local entry = entryFor(userId, name)
			entry.banked += delta.banked or 0
			entry.piles += delta.piles or 0
			entry.salvage += delta.salvage or 0
			entry.caught = (entry.caught or 0) + (delta.caught or 0)
			entry.noise = (entry.noise or 0) + (delta.noise or 0)
			entry.woke = (entry.woke or 0) + (delta.woke or 0)
			entry.items = (entry.items or 0) + (delta.items or 0)
			entry.overtimeSalvage = (entry.overtimeSalvage or 0) + (delta.overtimeSalvage or 0)
		end,

		noteDrop = function(_self, userId, name, kind, value)
			local entry = entryFor(userId, name)
			entry.drops = (entry.drops or 0) + 1
			if entry.dropKind == nil or value > (entry.dropValue or 0) then
				entry.dropKind = kind
				entry.dropValue = value
			end
		end,

		markOut = function(_self, userId, name)
			entryFor(userId, name).knockedOut = true
		end,

		list = function(_self)
			local result: { ShiftTypes.CrewStats } = {}
			for _, entry in roster do
				table.insert(result, table.clone(entry))
			end
			return result
		end,

		clear = function(_self)
			table.clear(roster)
		end,
	}
	return tracker
end

return ShiftRosterTracker
