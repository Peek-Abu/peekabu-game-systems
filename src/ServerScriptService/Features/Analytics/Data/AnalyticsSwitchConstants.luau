--!strict
--[=[
	AnalyticsSwitchConstants: THE OFF SWITCHES for the tracking picks (owner 11-17: "a flag or constant value I can
	change to turn these specific analytic tracking off when I have enough data").

	Two ways to turn a pick off:
	- No update needed: Creator Hub -> the game -> Configs, add a boolean config named the pick's CONFIG_KEYS value
	  (for example `analytics_quits`) and publish it as false. Live servers pick it up in about a minute
	  (AnalyticsSwitchSystem).
	- In the code: set the pick's line in SWITCHES below to false. This is the fallback the game uses whenever the
	  config is not set (or cannot be read), so it takes an update to change.

	A pick that is off runs nothing and sends nothing. The always-on fixes (the training truck kept out of the
	first-time funnel, no version number in event details, one bank event per load) have no switch.

	@class AnalyticsSwitchConstants
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsTypes = require(ServerScriptService.Features.Analytics.Data.AnalyticsTypes)

type Switch = AnalyticsTypes.Switch

-- true = tracking on, false = off (when Creator Hub's config is not set).
local SWITCHES: { [Switch]: boolean } = table.freeze({
	-- Pick 1: where players quit (hub, training, shift, results) and right after what (caught, chased, knocked out).
	quits = true,
	-- Pick 2: how long a hub stay lasts and how it ended (a truck, the Training truck, quitting).
	hubTime = true,
	-- Pick 3: the training funnel (the truck, each stop, done) and training skips.
	training = true,
	-- Pick 4: shifts this visit and the lifetime total, sent when a visit ends.
	shiftsPerVisit = true,
	-- Pick 5: every Gleam, Credits, Gloom and acorn in and out, with the item and its rarity.
	economy = true,
	-- Pick 6: Night Shift (owner 11-18): the mode picked at the truck, each night reached, how a run ended and on which
	-- night, each week completed and the Next night / Clock out vote (ShiftNightAnalyticsUtils).
	nightShift = true,
})

-- The Creator Hub config name for each switch.
local CONFIG_KEYS: { [Switch]: string } = table.freeze({
	quits = "analytics_quits",
	hubTime = "analytics_hub_time",
	training = "analytics_training",
	shiftsPerVisit = "analytics_shifts_per_visit",
	economy = "analytics_economy",
	nightShift = "analytics_night_shift",
})

-- Every switch, in pick order (for logs and the debug state).
local ORDER: { Switch } = { "quits", "hubTime", "training", "shiftsPerVisit", "economy", "nightShift" }

return table.freeze({
	SWITCHES = SWITCHES,
	CONFIG_KEYS = CONFIG_KEYS,
	ORDER = table.freeze(ORDER),
})
