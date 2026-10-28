--!strict
--[=[
	TimecardMomentStore: the Timecard's moments on this client. `stamp` is the punch whose stamp is showing (nil when
	none); `clear(id)` takes it down only if it is still that punch, so an old timer never hides a newer stamp.
	`greeted` is the UTC day the hub already opened the clipboard by itself this session. `expecting` is true from a
	punch request until its stamp shows (or the request times out), so a card arriving from the first sync never
	stamps.

	@class TimecardMomentStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local TimecardMomentUtils = require(ReplicatedStorage.Client.Features.Timecard.Utils.TimecardMomentUtils)

local stamp = Charm.atom(nil :: TimecardMomentUtils.Moment?) -- type the atom's empty initial value
local greeted = Charm.atom(nil :: number?) -- type the atom's empty initial value
local expecting = Charm.atom(false)

local TimecardMomentStore = {
	stamp = stamp,
	greeted = greeted,
	expecting = expecting,
}

function TimecardMomentStore.show(moment: TimecardMomentUtils.Moment)
	stamp(moment)
end

function TimecardMomentStore.clear(id: string)
	local current = stamp()
	if current ~= nil and current.id == id then
		stamp(nil)
	end
end

function TimecardMomentStore.greet(day: number)
	greeted(day)
end

function TimecardMomentStore.expect(value: boolean)
	expecting(value)
end

function TimecardMomentStore.reset()
	stamp(nil)
	greeted(nil)
	expecting(false)
end

return TimecardMomentStore
