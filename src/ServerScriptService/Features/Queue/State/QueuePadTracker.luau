--!strict
--[=[
	QueuePadTracker: who is aboard which pad, each pad's countdown and whether it is departing. Plain
	bookkeeping keyed by pad ids (strings) and UserIds; QueuePadSystem owns the Instances and samples who
	stands where. The decisions are QueuePadRules.

	A player is aboard at most one pad (the first that claims them). While a pad departs its party is
	frozen; `unlock` reopens it empty and the next sample re-boards whoever still stands there, which is
	how a failed teleport puts the party back on its pad.

	@class QueuePadTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local QueuePadRules = require(ServerScriptService.Features.Queue.Rules.QueuePadRules)

type PadConfig = QueueTypes.PadConfig

type Pad = {
	config: PadConfig,
	members: { number },
	endsAt: number?,
	status: QueueTypes.PadStatus,
}

export type QueuePadTracker = {
	add: (self: QueuePadTracker, padId: string, config: PadConfig) -> (),
	remove: (self: QueuePadTracker, padId: string) -> { number },
	has: (self: QueuePadTracker, padId: string) -> boolean,
	config: (self: QueuePadTracker, padId: string) -> PadConfig?,
	sync: (self: QueuePadTracker, padId: string, aboard: { number }, now: number) -> boolean,
	members: (self: QueuePadTracker, padId: string) -> { number },
	padOf: (self: QueuePadTracker, userId: number) -> string?,
	departNow: (self: QueuePadTracker, userId: number, now: number) -> string?,
	due: (self: QueuePadTracker, now: number) -> { string },
	lock: (self: QueuePadTracker, padId: string) -> { number },
	unlock: (self: QueuePadTracker, padId: string) -> (),
	forget: (self: QueuePadTracker, userId: number) -> boolean,
	snapshot: (self: QueuePadTracker) -> WorldTypes.WorldTable,
}

local function sameList(a: { number }, b: { number }): boolean
	if #a ~= #b then
		return false
	end
	for index, value in a do
		if b[index] ~= value then
			return false
		end
	end
	return true
end

local QueuePadTracker = {}

function QueuePadTracker.new(): QueuePadTracker
	local pads: { [string]: Pad } = {}

	local tracker: QueuePadTracker
	tracker = {
		add = function(_self, padId, config)
			assert(pads[padId] == nil, `pad "{padId}" is already tracked`)
			pads[padId] = { config = config, members = {}, endsAt = nil, status = "open" }
		end,

		remove = function(_self, padId)
			local pad = pads[padId]
			pads[padId] = nil
			return if pad ~= nil then pad.members else {}
		end,

		has = function(_self, padId)
			return pads[padId] ~= nil
		end,

		config = function(_self, padId)
			local pad = pads[padId]
			return if pad ~= nil then pad.config else nil
		end,

		--[=[
			Applies one sample: the user ids standing on the pad now (sorted). Returns whether the members or
			the countdown changed. A departing pad ignores samples.
		]=]
		sync = function(self, padId, aboard, now)
			local pad = pads[padId]
			if pad == nil or pad.status ~= "open" then
				return false
			end
			local free: { number } = {}
			for _, userId in aboard do
				local current = self:padOf(userId)
				if current == nil or current == padId then
					table.insert(free, userId)
				end
			end
			local members = QueuePadRules.admit(pad.members, free, pad.config.capacity)
			local endsAt = QueuePadRules.deadline(pad.members, members, pad.endsAt, now, pad.config.countdown)
			local changed = not sameList(members, pad.members) or endsAt ~= pad.endsAt
			pad.members = members
			pad.endsAt = endsAt
			return changed
		end,

		members = function(_self, padId)
			local pad = pads[padId]
			return if pad ~= nil then table.clone(pad.members) else {}
		end,

		padOf = function(_self, userId)
			for padId, pad in pads do
				if table.find(pad.members, userId) ~= nil then
					return padId
				end
			end
			return nil
		end,

		-- Depart now: a member of an open pad makes it due immediately. The pad id, or nil when refused.
		departNow = function(self, userId, now)
			local padId = self:padOf(userId)
			local pad = if padId ~= nil then pads[padId] else nil
			if padId == nil or pad == nil or not QueuePadRules.canDepart(pad.members, pad.status, userId) then
				return nil
			end
			pad.endsAt = now
			return padId
		end,

		due = function(_self, now)
			local list: { string } = {}
			for padId, pad in pads do
				local endsAt = pad.endsAt
				if pad.status == "open" and #pad.members > 0 and endsAt ~= nil and endsAt <= now then
					table.insert(list, padId)
				end
			end
			table.sort(list)
			return list
		end,

		-- Freezes the party for departure and returns it.
		lock = function(_self, padId)
			local pad = pads[padId]
			if pad == nil then
				return {}
			end
			pad.status = "departing"
			pad.endsAt = nil
			return table.clone(pad.members)
		end,

		unlock = function(_self, padId)
			local pad = pads[padId]
			if pad == nil then
				return
			end
			pad.status = "open"
			pad.members = {}
			pad.endsAt = nil
		end,

		forget = function(_self, userId)
			for _, pad in pads do
				local index = table.find(pad.members, userId)
				if index ~= nil then
					table.remove(pad.members, index)
					if #pad.members == 0 and pad.status == "open" then
						pad.endsAt = nil
					end
					return true
				end
			end
			return false
		end,

		-- Plain data for the `queue` world entry (decoded on clients by QueueSnapshotUtils).
		snapshot = function(_self)
			local list: WorldTypes.WorldTable = {}
			for padId, pad in pads do
				local members: WorldTypes.WorldTable = table.clone(pad.members)
				local entry: WorldTypes.WorldTable = {
					members = members,
					capacity = pad.config.capacity,
					destination = pad.config.destination,
					departing = pad.status == "departing",
				}
				local endsAt = pad.endsAt
				if endsAt ~= nil then
					entry.endsAt = endsAt
				end
				list[padId] = entry
			end
			return { pads = list }
		end,
	}
	return tracker
end

return QueuePadTracker
