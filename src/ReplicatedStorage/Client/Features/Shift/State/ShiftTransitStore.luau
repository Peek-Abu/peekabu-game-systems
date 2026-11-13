--!strict
--[=[
	ShiftTransitStore: the transit as this client sees it. `snapshot` is a Charm computed atom over the `shiftTransit`
	world entry, decoded by ShiftTransitUtils (nil before the first sync); what the transit screen shows
	(ShiftTransitRules.cover) rides three flags, `covered` (anything: black, the slip or the welcome card), `slip` (the
	route slip) and `welcome` (a first join's welcome card in the hub), read together by `coverOf`; `arrived` says whether the slip carries the ARRIVED stamp; `progress` is how far the held client is toward its reveal
	(the loading bar); `fadeSeconds` overrides how long the cover's next fade takes (nil: TRANSIT_FADE_IN / OUT; an
	office entrance's quick black cover sets it). ShiftTransitSystem writes them; the screen (ShiftTransitScreen), the atmosphere (instant changes while covered) and the
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
local welcome = Charm.atom(false)
local arrived = Charm.atom(false)
-- How far this client is toward its reveal (ShiftTransitRules.progress; 1 once arrived), drawn by the loading bar.
local progress = Charm.atom(0)
-- How long the cover's next fade in or out takes; nil = the transit's own TRANSIT_FADE_IN / TRANSIT_FADE_OUT.
local initialFadeSeconds: number? = nil
local fadeSeconds = Charm.atom(initialFadeSeconds)

-- The cover the flags make.
local function coverOf(isCovered: boolean, isSlip: boolean, isWelcome: boolean?): ShiftTypes.TransitCover
	if not isCovered then
		return "none"
	end
	if isSlip then
		return "slip"
	end
	return if isWelcome == true then "welcome" else "black"
end

return {
	snapshot = snapshot,
	covered = covered,
	slip = slip,
	welcome = welcome,
	arrived = arrived,
	progress = progress,
	fadeSeconds = fadeSeconds,
	coverOf = coverOf,
}
