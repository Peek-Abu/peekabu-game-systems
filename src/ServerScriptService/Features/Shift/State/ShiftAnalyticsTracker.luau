--!strict
--[=[
	ShiftAnalyticsTracker: what Cleanup Crew's analytics remembers between events (spec §6.6, §6.4). Plain bookkeeping
	nothing subscribes to:
	- each player's platform: the first valid report wins ("unknown" is never accepted, a second report is ignored),
	  forgotten when they leave;
	- per shift: who has started their first cleanup, piles cleared per player, when the quota was met (seconds into
	  the shift);
	- the last few noises (which one Mr. Harlow most likely heard) and the last records (the in-server log the Studio
	  checks and the developer read).

	@class ShiftAnalyticsTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftAnalyticsUtils = require(ServerScriptService.Features.Shift.Utils.ShiftAnalyticsUtils)

type Platform = ShiftTypes.Platform
type Noise = ShiftAnalyticsUtils.Noise
type Record = ShiftAnalyticsUtils.Record

export type ShiftAnalyticsTracker = {
	setPlatform: (self: ShiftAnalyticsTracker, userId: number, platform: Platform) -> boolean,
	platformOf: (self: ShiftAnalyticsTracker, userId: number) -> Platform,
	forget: (self: ShiftAnalyticsTracker, userId: number) -> (),
	beginShift: (self: ShiftAnalyticsTracker) -> (),
	firstCleanup: (self: ShiftAnalyticsTracker, userId: number) -> boolean,
	addPile: (self: ShiftAnalyticsTracker, userId: number) -> (),
	pilesOf: (self: ShiftAnalyticsTracker, userId: number) -> number,
	markQuota: (self: ShiftAnalyticsTracker, at: number) -> boolean,
	quotaAt: (self: ShiftAnalyticsTracker) -> number?,
	noteNoise: (self: ShiftAnalyticsTracker, noise: Noise) -> (),
	noises: (self: ShiftAnalyticsTracker) -> { Noise },
	remember: (self: ShiftAnalyticsTracker, record: Record) -> (),
	recent: (self: ShiftAnalyticsTracker) -> { Record },
}

local ShiftAnalyticsTracker = {}

-- Appends `item`, dropping the oldest entries past `limit`.
local function push<T>(list: { T }, item: T, limit: number)
	table.insert(list, item)
	while #list > limit do
		table.remove(list, 1)
	end
end

function ShiftAnalyticsTracker.new(recentLimit: number, noiseLimit: number): ShiftAnalyticsTracker
	local platforms: { [number]: Platform } = {}
	local cleaned: { [number]: boolean } = {}
	local piles: { [number]: number } = {}
	local quotaMetAt: number? = nil
	local noiseList: { Noise } = {}
	local records: { Record } = {}

	local tracker: ShiftAnalyticsTracker = {
		setPlatform = function(_self, userId, platform)
			if platform == "unknown" or platforms[userId] ~= nil then
				return false
			end
			platforms[userId] = platform
			return true
		end,

		platformOf = function(_self, userId)
			return platforms[userId] or "unknown"
		end,

		forget = function(_self, userId)
			platforms[userId] = nil
			cleaned[userId] = nil
			piles[userId] = nil
		end,

		beginShift = function(_self)
			table.clear(cleaned)
			table.clear(piles)
			quotaMetAt = nil
			table.clear(noiseList)
		end,

		firstCleanup = function(_self, userId)
			if cleaned[userId] then
				return false
			end
			cleaned[userId] = true
			return true
		end,

		addPile = function(_self, userId)
			piles[userId] = (piles[userId] or 0) + 1
		end,

		pilesOf = function(_self, userId)
			return piles[userId] or 0
		end,

		markQuota = function(_self, at)
			if quotaMetAt ~= nil then
				return false
			end
			quotaMetAt = at
			return true
		end,

		quotaAt = function(_self)
			return quotaMetAt
		end,

		noteNoise = function(_self, noise)
			push(noiseList, noise, noiseLimit)
		end,

		noises = function(_self)
			return table.clone(noiseList)
		end,

		remember = function(_self, record)
			push(records, record, recentLimit)
		end,

		recent = function(_self)
			return table.clone(records)
		end,
	}
	return tracker
end

return ShiftAnalyticsTracker
