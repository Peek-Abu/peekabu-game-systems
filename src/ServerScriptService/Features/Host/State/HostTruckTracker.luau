--!strict
--[=[
	HostTruckTracker: who hosts each truck and how long it has waited unstarted. Plain bookkeeping keyed by Queue pad
	ids and UserIds; HostServiceServer reads each held pad's members and countdown from Queue every tick and syncs
	them here. The decisions are HostRules.

	A truck's idle wait starts when it gets a host, restarts when the host changes and when a countdown stops without
	the truck leaving (cancelled, or a failed trip put the crew back), and pauses while a countdown runs. An emptied
	truck is forgotten, with its kicks and lock. A kick lasts until the truck empties (it leaves, or everyone steps
	out), across host changes; the friends-only lock turns off when the host changes, since it was the old host's
	friends.

	@class HostTruckTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local HostRules = require(ReplicatedStorage.Shared.Features.Host.Rules.HostRules)

type Truck = {
	host: number,
	-- When the idle wait began (server time).
	since: number,
	started: boolean,
	locked: boolean,
	kicked: { [number]: boolean },
}

export type HostTruckTracker = {
	sync: (self: HostTruckTracker, padId: string, members: { number }, started: boolean, now: number) -> boolean,
	hostOf: (self: HostTruckTracker, padId: string) -> number?,
	idleDue: (self: HostTruckTracker, now: number) -> { string },
	kick: (self: HostTruckTracker, padId: string, userId: number) -> boolean,
	isKicked: (self: HostTruckTracker, padId: string, userId: number) -> boolean,
	setLocked: (self: HostTruckTracker, padId: string, locked: boolean) -> boolean,
	locked: (self: HostTruckTracker, padId: string) -> boolean,
	remove: (self: HostTruckTracker, padId: string) -> (),
	snapshot: (self: HostTruckTracker) -> WorldTypes.WorldTable,
}

local HostTruckTracker = {}

function HostTruckTracker.new(): HostTruckTracker
	local trucks: { [string]: Truck } = {}

	local tracker: HostTruckTracker = {
		--[=[
			Applies one tick: the pad's members (boarding order) and whether its countdown runs. Returns whether the
			published state (the host) changed.
		]=]
		sync = function(_self, padId, members, started, now)
			local truck = trucks[padId]
			local host = HostRules.hostAfter(if truck ~= nil then truck.host else nil, members)
			if host == nil then
				trucks[padId] = nil
				return truck ~= nil
			end
			if truck == nil or truck.host ~= host then
				local kicked = if truck ~= nil then truck.kicked else {}
				trucks[padId] = { host = host, since = now, started = started, locked = false, kicked = kicked }
				return true
			end
			if truck.started and not started then
				truck.since = now
			end
			truck.started = started
			return false
		end,

		hostOf = function(_self, padId)
			local truck = trucks[padId]
			return if truck ~= nil then truck.host else nil
		end,

		-- The trucks whose idle wait ran out at `now`, sorted.
		idleDue = function(_self, now)
			local list: { string } = {}
			for padId, truck in trucks do
				if HostRules.idleDue(truck.since, truck.started, now) then
					table.insert(list, padId)
				end
			end
			table.sort(list)
			return list
		end,

		-- Keeps `userId` off a hosted truck. Whether it was hosted.
		kick = function(_self, padId, userId)
			local truck = trucks[padId]
			if truck == nil then
				return false
			end
			truck.kicked[userId] = true
			return true
		end,

		isKicked = function(_self, padId, userId)
			local truck = trucks[padId]
			return truck ~= nil and truck.kicked[userId] == true
		end,

		-- Turns a hosted truck's friends-only lock on or off. Whether it changed.
		setLocked = function(_self, padId, locked)
			local truck = trucks[padId]
			if truck == nil or truck.locked == locked then
				return false
			end
			truck.locked = locked
			return true
		end,

		locked = function(_self, padId)
			local truck = trucks[padId]
			return truck ~= nil and truck.locked
		end,

		remove = function(_self, padId)
			trucks[padId] = nil
		end,

		-- Plain data for the `host` world entry (decoded on clients by HostSnapshotUtils).
		snapshot = function(_self)
			local list: WorldTypes.WorldTable = {}
			for padId, truck in trucks do
				local entry: WorldTypes.WorldTable = { host = truck.host, locked = truck.locked }
				list[padId] = entry
			end
			return { trucks = list }
		end,
	}
	return tracker
end

return HostTruckTracker
