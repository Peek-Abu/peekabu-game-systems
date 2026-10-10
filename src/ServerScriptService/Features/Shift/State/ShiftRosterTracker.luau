--!strict
--[=[
	ShiftRosterTracker: every crew member's run in the current shift, kept by UserId so what a player did stays
	in the crew totals after they leave. Lists are handed out as copies.

	@class ShiftRosterTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

export type Delta = { banked: number?, piles: number?, salvage: number? }

export type ShiftRosterTracker = {
	-- Lists the player (at zero if new, under the name first seen) and adds `delta` to their run.
	record: (self: ShiftRosterTracker, userId: number, name: string, delta: Delta) -> (),
	list: (self: ShiftRosterTracker) -> { ShiftTypes.CrewStats },
	clear: (self: ShiftRosterTracker) -> (),
}

local ShiftRosterTracker = {}

function ShiftRosterTracker.new(): ShiftRosterTracker
	local roster: { [number]: ShiftTypes.CrewStats } = {}

	local tracker: ShiftRosterTracker = {
		record = function(_self, userId, name, delta)
			local entry = roster[userId]
			if entry == nil then
				entry = { userId = userId, name = name, banked = 0, piles = 0, salvage = 0 }
				roster[userId] = entry
			end
			entry.banked += delta.banked or 0
			entry.piles += delta.piles or 0
			entry.salvage += delta.salvage or 0
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
