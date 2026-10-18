--!strict
--[=[
	OccupantTellRules: what Harlow's tells show (Cleanup Crew spec §4 "Tells", §7): "?" over his head while he
	investigates or searches, "!" while he chases; a speech-bubble line per cue; a heartbeat while he is within
	HEARTBEAT_RANGE and not chasing you, beating faster the closer he is; lights within FLICKER_RADIUS of him
	flicker (deterministic noise per light, mostly on). Shared: the server uses the cues and lines, the client
	the heartbeat and flicker. Pure.

	@class OccupantTellRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

-- Below this noise value a light near him is dark this instant.
local FLICKER_THRESHOLD = -0.1
-- How fast the flicker noise moves (per second).
local FLICKER_RATE = 7

local OccupantTellRules = {}

function OccupantTellRules.cueFor(mode: string?): string
	if mode == "investigate" or mode == "search" then
		return "?"
	end
	if mode == "chase" then
		return "!"
	end
	return ""
end

function OccupantTellRules.lineFor(cue: string?): string?
	if cue == nil then
		return nil
	end
	return OccupantConstants.LINES[cue]
end

--[=[
	Whether your heartbeat sounds: he is within HEARTBEAT_RANGE and not chasing you.
]=]
function OccupantTellRules.heartbeat(distance: number, mode: string?, huntingMe: boolean): boolean
	if distance > OccupantConstants.HEARTBEAT_RANGE then
		return false
	end
	return not (mode == "chase" and huntingMe)
end

--[=[
	Seconds per beat: BEAT_SLOW at the edge of the range, BEAT_FAST with him on top of you.
]=]
function OccupantTellRules.period(distance: number): number
	local closeness = 1 - math.clamp(distance / OccupantConstants.HEARTBEAT_RANGE, 0, 1)
	return OccupantConstants.BEAT_SLOW + (OccupantConstants.BEAT_FAST - OccupantConstants.BEAT_SLOW) * closeness
end

--[=[
	The beat's strength (0..1) `elapsed` seconds into the heartbeat: full at each beat, gone a third of the way
	to the next.
]=]
function OccupantTellRules.pulse(elapsed: number, distance: number): number
	local period = OccupantTellRules.period(distance)
	local phase = (elapsed % period) / period
	return math.clamp(1 - phase * 3, 0, 1)
end

--[=[
	Whether a light `distance` studs from him is lit at `now` (`seed` tells lights apart).
]=]
function OccupantTellRules.flicker(distance: number, now: number, seed: number): boolean
	if distance > OccupantConstants.FLICKER_RADIUS then
		return true
	end
	return math.noise(now * FLICKER_RATE, seed) > FLICKER_THRESHOLD
end

return OccupantTellRules
