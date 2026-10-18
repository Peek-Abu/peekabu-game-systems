--!strict
--[=[
	HideOccupancyTracker: who hides where (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §4). One
	player per spot and one spot per player; each stay remembers since when and whether the Manager saw them go in
	(`seenEntering`, which a later behaviour may set). A spot a player was pushed out of cools off for that player
	until a given time. Plain bookkeeping, changed only by its owner (HideServiceServer).

	@class HideOccupancyTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideTypes = require(ReplicatedStorage.Shared.Features.Hide.Data.HideTypes)

type Occupancy = HideTypes.Occupancy

export type HideOccupancyTracker = {
	enter: (self: HideOccupancyTracker, userId: number, spotId: string, now: number, seen: boolean) -> boolean,
	leave: (self: HideOccupancyTracker, userId: number) -> Occupancy?,
	of: (self: HideOccupancyTracker, userId: number) -> Occupancy?,
	occupant: (self: HideOccupancyTracker, spotId: string) -> number?,
	setSeen: (self: HideOccupancyTracker, userId: number, seen: boolean) -> boolean,
	cool: (self: HideOccupancyTracker, userId: number, spotId: string, untilTime: number) -> (),
	cooling: (self: HideOccupancyTracker, userId: number, spotId: string, now: number) -> boolean,
	forget: (self: HideOccupancyTracker, userId: number) -> (),
	all: (self: HideOccupancyTracker) -> { [number]: Occupancy },
	clear: (self: HideOccupancyTracker) -> (),
}

local HideOccupancyTracker = {}

function HideOccupancyTracker.new(): HideOccupancyTracker
	local stays: { [number]: Occupancy } = {}
	local bySpot: { [string]: number } = {}
	-- userId → spotId → until when that spot refuses them.
	local cools: { [number]: { [string]: number } } = {}

	local tracker: HideOccupancyTracker = {
		enter = function(_self, userId, spotId, now, seen)
			if stays[userId] ~= nil or bySpot[spotId] ~= nil then
				return false
			end
			stays[userId] = { spotId = spotId, since = now, seenEntering = seen }
			bySpot[spotId] = userId
			return true
		end,

		leave = function(_self, userId)
			local stay = stays[userId]
			if stay == nil then
				return nil
			end
			stays[userId] = nil
			if bySpot[stay.spotId] == userId then
				bySpot[stay.spotId] = nil
			end
			return stay
		end,

		of = function(_self, userId)
			local stay = stays[userId]
			return if stay ~= nil then table.clone(stay) else nil
		end,

		occupant = function(_self, spotId)
			return bySpot[spotId]
		end,

		setSeen = function(_self, userId, seen)
			local stay = stays[userId]
			if stay == nil then
				return false
			end
			stay.seenEntering = seen
			return true
		end,

		cool = function(_self, userId, spotId, untilTime)
			local mine = cools[userId]
			if mine == nil then
				mine = {}
				cools[userId] = mine
			end
			mine[spotId] = untilTime
		end,

		cooling = function(_self, userId, spotId, now)
			local mine = cools[userId]
			local untilTime = if mine ~= nil then mine[spotId] else nil
			if mine ~= nil and untilTime ~= nil and now >= untilTime then
				-- Over: drop it, so the map only holds spots still cooling.
				mine[spotId] = nil
				if next(mine) == nil then
					cools[userId] = nil
				end
			end
			return untilTime ~= nil and now < untilTime
		end,

		-- The player left: their stay and every spot cooling for them go.
		forget = function(self, userId)
			self:leave(userId)
			cools[userId] = nil
		end,

		all = function(_self)
			local copy: { [number]: Occupancy } = {}
			for userId, stay in stays do
				copy[userId] = table.clone(stay)
			end
			return copy
		end,

		clear = function(_self)
			table.clear(stays)
			table.clear(bySpot)
			table.clear(cools)
		end,
	}
	return tracker
end

return HideOccupancyTracker
