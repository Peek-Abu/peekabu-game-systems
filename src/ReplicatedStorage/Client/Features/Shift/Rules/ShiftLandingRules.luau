--!strict
--[=[
	ShiftLandingRules: the landing status card (the night's temperature, time, weather and danger, ShiftLandingHud) that
	shows once when a crew arrives at a shift.

	`shows`: whether an arrival gets the card: never in the hub (the depot) and never on a training trip.

	`seedOf`: the shared value the night is drawn from (ShiftLandingFormulas): the built office's layout seed, or, for
	the office built at boot (no seed), the transit hold's id, which the server gives the whole crew held together.

	`alpha`: how far the card is in (0..1) `elapsed` seconds after this client's reveal (ShiftTransitSystem): nothing
	until the route slip's ARRIVED beat and fade are over (TIMING.delay), then in over TIMING.fadeIn, up for
	TIMING.hold, out over TIMING.fadeOut. `over` once it has gone. Pure.

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

local ShiftLandingRules = {}

-- Seconds: the wait after the reveal (the ARRIVED stamp, the cover's fade and a short beat), the card's fade in, its
-- time fully up and its fade out.
ShiftLandingRules.TIMING = table.freeze({
	delay = ShiftConstants.TRANSIT_ARRIVED_SECONDS + ShiftConstants.TRANSIT_FADE_OUT + 0.6,
	fadeIn = 0.35,
	hold = 6,
	fadeOut = 0.6,
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

-- Seconds from the reveal until the card has gone.
function ShiftLandingRules.total(): number
	local timing = ShiftLandingRules.TIMING
	return timing.delay + timing.fadeIn + timing.hold + timing.fadeOut
end

function ShiftLandingRules.alpha(elapsed: number): number
	if elapsed ~= elapsed or ShiftLandingRules.over(elapsed) then
		return 0
	end
	local timing = ShiftLandingRules.TIMING
	local t = elapsed - timing.delay
	if t <= 0 then
		return 0
	end
	if t < timing.fadeIn then
		return t / timing.fadeIn
	end
	t -= timing.fadeIn
	if t < timing.hold then
		return 1
	end
	t -= timing.hold
	if t < timing.fadeOut then
		return 1 - t / timing.fadeOut
	end
	return 0
end

function ShiftLandingRules.over(elapsed: number): boolean
	return elapsed >= ShiftLandingRules.total()
end

return ShiftLandingRules
