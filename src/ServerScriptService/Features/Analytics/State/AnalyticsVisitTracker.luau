--!strict
--[=[
	AnalyticsVisitTracker: what the visit events remember per player on this server: where they are (hub, training,
	shift, results; "shift" until told), when their hub stay began, their last catch, chase and knock-out, whether a
	truck ride is taking them (so leaving is not a quit), whether this server continues their visit, their shifts this
	visit and lifetime (mirrored from the saved slice, so a quit can read them after the save is gone) and which
	training steps were logged. Forgotten when the player leaves.

	@class AnalyticsVisitTracker
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsTypes = require(ServerScriptService.Features.Analytics.Data.AnalyticsTypes)

type Place = AnalyticsTypes.Place
type Moment = AnalyticsTypes.Moment

export type Shifts = { visit: number, lifetime: number }

export type AnalyticsVisitTracker = {
	setPlace: (self: AnalyticsVisitTracker, userId: number, place: Place) -> (),
	placeOf: (self: AnalyticsVisitTracker, userId: number) -> Place,
	enterHub: (self: AnalyticsVisitTracker, userId: number, at: number) -> (),
	-- The hub stay's start, cleared so a stay is reported once; nil when none is open.
	takeHub: (self: AnalyticsVisitTracker, userId: number) -> number?,
	note: (self: AnalyticsVisitTracker, userId: number, moment: Moment, at: number) -> (),
	momentsOf: (self: AnalyticsVisitTracker, userId: number) -> { [Moment]: number },
	setLeaving: (self: AnalyticsVisitTracker, userId: number, leaving: boolean) -> (),
	isLeaving: (self: AnalyticsVisitTracker, userId: number) -> boolean,
	setAgain: (self: AnalyticsVisitTracker, userId: number, again: boolean) -> (),
	isAgain: (self: AnalyticsVisitTracker, userId: number) -> boolean,
	setShifts: (self: AnalyticsVisitTracker, userId: number, visit: number, lifetime: number) -> (),
	shiftsOf: (self: AnalyticsVisitTracker, userId: number) -> Shifts,
	-- True the first time `step` is marked for the player.
	markTraining: (self: AnalyticsVisitTracker, userId: number, step: number) -> boolean,
	forget: (self: AnalyticsVisitTracker, userId: number) -> (),
}

local AnalyticsVisitTracker = {}

function AnalyticsVisitTracker.new(): AnalyticsVisitTracker
	local places: { [number]: Place } = {}
	local hubSince: { [number]: number } = {}
	local moments: { [number]: { [Moment]: number } } = {}
	local leaving: { [number]: boolean } = {}
	local again: { [number]: boolean } = {}
	local shifts: { [number]: Shifts } = {}
	local training: { [number]: { [number]: boolean } } = {}

	local tracker: AnalyticsVisitTracker = {
		setPlace = function(_self, userId, place)
			places[userId] = place
		end,

		placeOf = function(_self, userId)
			return places[userId] or "shift"
		end,

		enterHub = function(_self, userId, at)
			hubSince[userId] = at
		end,

		takeHub = function(_self, userId)
			local at = hubSince[userId]
			hubSince[userId] = nil
			return at
		end,

		note = function(_self, userId, moment, at)
			local noted = moments[userId]
			if noted == nil then
				noted = {}
				moments[userId] = noted
			end
			noted[moment] = at
		end,

		momentsOf = function(_self, userId)
			local noted = moments[userId]
			return if noted ~= nil then table.clone(noted) else {}
		end,

		setLeaving = function(_self, userId, value)
			if value then
				leaving[userId] = true
			else
				leaving[userId] = nil
			end
		end,

		isLeaving = function(_self, userId)
			return leaving[userId] == true
		end,

		setAgain = function(_self, userId, value)
			again[userId] = value
		end,

		isAgain = function(_self, userId)
			return again[userId] == true
		end,

		setShifts = function(_self, userId, visit, lifetime)
			shifts[userId] = { visit = visit, lifetime = lifetime }
		end,

		shiftsOf = function(_self, userId)
			local known = shifts[userId]
			return if known ~= nil then table.clone(known) else { visit = 0, lifetime = 0 }
		end,

		markTraining = function(_self, userId, step)
			local done = training[userId]
			if done == nil then
				done = {}
				training[userId] = done
			end
			if done[step] then
				return false
			end
			done[step] = true
			return true
		end,

		forget = function(_self, userId)
			places[userId] = nil
			hubSince[userId] = nil
			moments[userId] = nil
			leaving[userId] = nil
			again[userId] = nil
			shifts[userId] = nil
			training[userId] = nil
		end,
	}
	return tracker
end

return AnalyticsVisitTracker
