--!strict
--[=[
	ShiftLandingRules: the landing readout (the night's temperature and weather, the time, then the anomaly level,
	ShiftLandingHud) that plays once when a crew arrives at a shift.

	`shows`: whether an arrival gets the readout: never in the hub (the depot) and never on a training trip.

	`seedOf`: the shared value the night is drawn from (ShiftLandingFormulas): the built office's layout seed, or, for
	the office built at boot (no seed), the transit hold's id, which the server gives the whole crew held together.

	`watch` / `startAt`: the readout waits for the big ARRIVAL contract card in the centre (DepotStore.card of kind
	"arrival") to close. `watch` notes when that card was first seen and when it closed (the store moved off it);
	`startAt` starts TIMING.beat after it closed. While it is still up nothing starts, unless it is still up
	TIMING.wait after the reveal (it never closes: start now). With no arrival card by TIMING.fallback after the reveal
	(a late joiner's card can miss), the readout starts then, the old trigger: after the route slip's ARRIVED beat
	and fade.

	`screenAt`: which of the SCREENS (or of `count` screens: a Night Shift plays four, its NIGHT n / WEEK w first) shows `elapsed` seconds after the start and how far it is in (0..1): each screen
	tweens in over TIMING.fadeIn, holds TIMING.hold, tweens out over TIMING.fadeOut, then TIMING.gap of nothing before
	the next; one screen at a time. `over` once the last has gone.

	`nightSting`: whether the night start sting plays now (owner Night Shift pick 2026-11-18): as a Night Shift's
	first screen (NIGHT n / WEEK w) comes up, once. Pure.

	@class ShiftLandingRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)

export type ShowInput = {
	-- This server is the hub (the depot).
	hub: boolean,
	-- The transit's contract client (nil: not named yet).
	client: string?,
}

-- The ARRIVAL card as this client has seen it (os.clock() times): when it first showed and when it closed.
export type CardWatch = {
	seenAt: number?,
	closedAt: number?,
}

export type StartInput = {
	-- os.clock() of this client's reveal (ShiftTransitStore.landing.at).
	revealAt: number,
	now: number,
	seenAt: number?,
	closedAt: number?,
}

local ShiftLandingRules = {}

-- How many screens play: temperature and weather, the time, the anomaly level.
ShiftLandingRules.SCREENS = 3

-- Seconds. `beat`: after the ARRIVAL card closes. `fallback`: after the reveal when no ARRIVAL card showed (the route
-- slip's ARRIVED beat and fade, and a little more for a card still on its way). `wait`: the longest an ARRIVAL card
-- that never closes holds the readout back. Each screen: `fadeIn`, `hold`, `fadeOut`, then `gap` before the next.
ShiftLandingRules.TIMING = table.freeze({
	beat = 0.6,
	fallback = ShiftConstants.TRANSIT_ARRIVED_SECONDS + ShiftConstants.TRANSIT_FADE_OUT + 1.5,
	wait = 15,
	fadeIn = 0.5,
	hold = 2,
	fadeOut = 0.45,
	gap = 0.2,
})

function ShiftLandingRules.shows(input: ShowInput): boolean
	if input.hub then
		return false
	end
	return input.client ~= TrainingConstants.CONTRACT.client
end

function ShiftLandingRules.seedOf(hold: ShiftTypes.TransitHold): number
	local seed = hold.seed
	return if seed ~= nil then seed else hold.id
end

-- The watch after a look at the store at `now`: `arrival` is whether the ARRIVAL card is the card shown.
function ShiftLandingRules.watch(state: CardWatch, arrival: boolean, now: number): CardWatch
	if arrival then
		return { seenAt = state.seenAt or now, closedAt = nil }
	end
	if state.seenAt ~= nil and state.closedAt == nil then
		return { seenAt = state.seenAt, closedAt = now }
	end
	return state
end

-- The os.clock() time the readout starts, or nil while it waits.
function ShiftLandingRules.startAt(input: StartInput): number?
	local timing = ShiftLandingRules.TIMING
	local closedAt = input.closedAt
	if closedAt ~= nil then
		return closedAt + timing.beat
	end
	if input.seenAt ~= nil then
		return if input.now >= input.revealAt + timing.wait then input.now else nil
	end
	local fallback = input.revealAt + timing.fallback
	return if input.now >= fallback then fallback else nil
end

-- Seconds from the start until the last of `count` screens (SCREENS when nil) has gone.
function ShiftLandingRules.total(count: number?): number
	local timing = ShiftLandingRules.TIMING
	local slot = timing.fadeIn + timing.hold + timing.fadeOut
	return (count or ShiftLandingRules.SCREENS) * (slot + timing.gap) - timing.gap
end

function ShiftLandingRules.over(elapsed: number, count: number?): boolean
	return elapsed >= ShiftLandingRules.total(count)
end

-- The screen showing `elapsed` seconds after the start (1..count, SCREENS when nil; 0: none) and how far it is in
-- (0..1).
function ShiftLandingRules.screenAt(elapsed: number, count: number?): (number, number)
	local screens = count or ShiftLandingRules.SCREENS
	if elapsed ~= elapsed or elapsed < 0 or ShiftLandingRules.over(elapsed, screens) then
		return 0, 0
	end
	local timing = ShiftLandingRules.TIMING
	local slot = timing.fadeIn + timing.hold + timing.fadeOut
	local pitch = slot + timing.gap
	local index = math.floor(elapsed / pitch) + 1
	local t = elapsed - (index - 1) * pitch
	if index > screens or t >= slot then
		return 0, 0
	end
	if t < timing.fadeIn then
		return index, t / timing.fadeIn
	end
	t -= timing.fadeIn
	if t < timing.hold then
		return index, 1
	end
	return index, math.clamp(1 - (t - timing.hold) / timing.fadeOut, 0, 1)
end

-- Whether the night sting plays: the screen went from `shown` to `index`, and it is a Night Shift's first screen.
function ShiftLandingRules.nightSting(shown: number, index: number, night: boolean): boolean
	return night and index == 1 and shown ~= 1
end

return ShiftLandingRules
