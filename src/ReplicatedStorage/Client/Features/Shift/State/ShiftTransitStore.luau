--!strict
--[=[
	ShiftTransitStore: the transit as this client sees it. `snapshot` is a Charm computed atom over the `shiftTransit`
	world entry, decoded by ShiftTransitUtils (nil before the first sync); what the transit screen shows
	(ShiftTransitRules.cover) rides two flags, `covered` (anything: black or the slip) and `slip` (the route slip), read
	together by `coverOf`; `arrived` says whether the slip carries the ARRIVED stamp; `progress` is how far the held client is toward its reveal
	(the loading bar). ShiftTransitSystem writes them; the screen (ShiftTransitScreen), the atmosphere (instant changes while covered) and the
	depot's travel cards read them. The client never writes the transit itself.

	@class ShiftTransitStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftTransitUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftTransitUtils)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local snapshot = Charm.computed(function(): ShiftTypes.TransitSnapshot?
	return ShiftTransitUtils.decode(StateSyncClientStore.world()[ShiftConstants.TRANSIT_ENTRY])
end)

-- Covered (black) from the start: the client covers its screen until its first sync (ShiftTransitSystem).
local covered = Charm.atom(true)
local slip = Charm.atom(false)
local arrived = Charm.atom(false)
-- How far this client is toward its reveal (ShiftTransitRules.progress; 1 once arrived), drawn by the loading bar.
local progress = Charm.atom(0)

-- The cover the two flags make.
local function coverOf(isCovered: boolean, isSlip: boolean): ShiftTypes.TransitCover
	if not isCovered then
		return "none"
	end
	return if isSlip then "slip" else "black"
end

return {
	snapshot = snapshot,
	covered = covered,
	slip = slip,
	arrived = arrived,
	progress = progress,
	coverOf = coverOf,
}
