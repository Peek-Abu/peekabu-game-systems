--!strict
--[=[
	ShiftLandingFormulas: the night a crew lands in (the landing readout, ShiftLandingViewModel). Always night: the
	clock time is between 11:00 PM and 3:59 AM, the temperature a whole number from 30 to 48 °F, and the weather one of
	WEATHER, which has no gameplay effect and nothing the scene would contradict (no rain, snow or fog). Every value is
	drawn from Random.new(seed) in a fixed order, so the same shift seed (ShiftLandingRules.seedOf, which every member of
	the crew reads off the same transit) gives every player the same night. Pure.

	@class ShiftLandingFormulas
]=]

export type Weather = "Clear" | "Cloudy" | "Windy"

export type Night = {
	-- Whole degrees Fahrenheit.
	temperature: number,
	-- The clock time as minutes after midnight (0..1439): 23:00 to 23:59 or 00:00 to 03:59.
	minutes: number,
	weather: Weather,
}

local ShiftLandingFormulas = {}

ShiftLandingFormulas.TEMPERATURE = table.freeze({ min = 30, max = 48 })
-- The clock: from START minutes after midnight (11:00 PM), for SPAN minutes (to 3:59 AM).
ShiftLandingFormulas.CLOCK = table.freeze({ start = 23 * 60, span = 5 * 60 })
local WEATHER: { Weather } = { "Clear", "Cloudy", "Windy" }
ShiftLandingFormulas.WEATHER = table.freeze(WEATHER)

local DAY_MINUTES = 24 * 60

-- The night for `seed` (any number: it is floored and kept in Random's range).
function ShiftLandingFormulas.night(seed: number): Night
	local safe = if seed == seed then math.floor(math.abs(seed)) % 2 ^ 31 else 0
	local rng = Random.new(safe)
	local range = ShiftLandingFormulas.TEMPERATURE
	local temperature = rng:NextInteger(range.min, range.max)
	local clock = ShiftLandingFormulas.CLOCK
	local minutes = (clock.start + rng:NextInteger(0, clock.span - 1)) % DAY_MINUTES
	local weather: Weather = WEATHER[rng:NextInteger(1, #WEATHER)]
	return { temperature = temperature, minutes = minutes, weather = weather }
end

return ShiftLandingFormulas
