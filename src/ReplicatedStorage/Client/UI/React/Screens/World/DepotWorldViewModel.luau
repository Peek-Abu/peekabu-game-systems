--!strict
--[=[
	DepotWorldViewModel: what the depot's world signs say (Figma World UI 2a). The truck pad tag (W1): "TRUCK n", a seat
	per place (filled = aboard), "n / 4 ABOARD" and line 3: the red "Leaving in m:ss" when the truck is full or
	DepotConstants.TAG_WARN_SECONDS or fewer remain, "Leaving now" while it departs, else how to join. `padFor` finds the
	Queue pad whose crew stand in a truck (by their public `truck` field); `sameTag` says whether two tags draw the same,
	so an unchanged tag is not re-rendered. Pure.

	@class DepotWorldViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type TruckTagView = {
	title: string,
	seats: { boolean },
	count: string,
	line: string,
	warn: boolean,
}

local JOIN_LINE = "Stand in the bed to join"
local LEAVING_NOW = "Leaving now"

local DepotWorldViewModel = {}

function DepotWorldViewModel.truckTag(
	truck: number,
	capacity: number,
	pad: QueueTypes.PadSnapshot?,
	now: number
): TruckTagView
	local aboard = if pad ~= nil then #pad.members else 0
	local seats: { boolean } = {}
	for seat = 1, capacity do
		table.insert(seats, seat <= aboard)
	end
	local endsAt = if pad ~= nil then pad.endsAt else nil
	local line = JOIN_LINE
	local warn = false
	if pad ~= nil and pad.departing then
		line = LEAVING_NOW
		warn = true
	elseif endsAt ~= nil then
		local left = endsAt - now
		if aboard >= capacity or left <= DepotConstants.TAG_WARN_SECONDS then
			line = `Leaving in {ShiftHudViewModel.clock(left)}`
			warn = true
		end
	end
	return {
		title = `TRUCK {truck}`,
		seats = seats,
		count = `{aboard} / {capacity} ABOARD`,
		line = line,
		warn = warn,
	}
end

-- The Queue pad of `truck`: the first pad with a member whose public `truck` field names it; nil when nobody is aboard.
function DepotWorldViewModel.padFor(
	snapshot: QueueTypes.QueueSnapshot?,
	truck: number,
	players: PublicPlayerTypes.PublicPlayerMap
): QueueTypes.PadSnapshot?
	if snapshot == nil then
		return nil
	end
	for _, pad in snapshot.pads do
		for _, userId in pad.members do
			local entry = players[StateSyncConstants.publicEntryKey(userId)]
			if entry ~= nil and entry[DepotConstants.PUBLIC_TRUCK] == truck then
				return pad
			end
		end
	end
	return nil
end

function DepotWorldViewModel.sameTag(a: TruckTagView?, b: TruckTagView?): boolean
	if a == nil or b == nil then
		return a == nil and b == nil
	end
	if a.title ~= b.title or a.count ~= b.count or a.line ~= b.line or a.warn ~= b.warn or #a.seats ~= #b.seats then
		return false
	end
	for index, filled in a.seats do
		if b.seats[index] ~= filled then
			return false
		end
	end
	return true
end

return DepotWorldViewModel
