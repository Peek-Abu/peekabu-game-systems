--!strict
--[=[
	VoiceConstants: the input name, the public field, the falloff curve and the radio tuning.

	@class VoiceConstants
]=]

-- Volume by distance (studs): full to 10, silent at 80.
local FALLOFF: { [number]: number } = { [0] = 1, [10] = 1, [45] = 0.35, [80] = 0 }

local VoiceConstants = {
	-- The AudioDeviceInput the server creates under each Player.
	INPUT_NAME = "VoiceInput",
	-- Public-player field naming the radio channel a player is on (absent = no radio).
	RADIO_FIELD = "radio",
	FALLOFF = FALLOFF,
	-- The dead hear the living (spatially) as well as each other.
	DEAD_HEAR_LIVING = true,
	-- Radio sound: an equalizer that cuts lows and highs (decibels).
	RADIO_LOW_GAIN = -40,
	RADIO_MID_GAIN = 4,
	RADIO_HIGH_GAIN = -30,
	-- How often the server re-checks routing for access lists (seconds).
	ACCESS_INTERVAL = 0.5,
}

return VoiceConstants
