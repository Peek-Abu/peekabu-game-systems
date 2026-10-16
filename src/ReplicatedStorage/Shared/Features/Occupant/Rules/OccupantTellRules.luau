--!strict
--[=[
	OccupantTellRules: what Harlow's tells show (Cleanup Crew spec §4 "Tells", §7; since 2026-10-16 nothing is drawn
	over his head: no "?" / "!" and no speech text, the tells are diegetic): a voiced line per cue; a heartbeat while he is within
	HEARTBEAT_RANGE and not chasing you, beating faster the closer he is; lights within FLICKER_RADIUS of him
	flicker (deterministic noise per light, mostly on). The behaviour set (docs/superpowers/specs/2026-10-15-cleanup-
	crew-manager-behaviours-design.md §5): his typing plays while he sits typing; the warning stage by distance (far: footsteps and a pen click; mid: flicker and the PA; near: the
	heartbeat and the dread swell; chase: his chase on you); a PA line with the called-out name. Shared: the server uses the cues and lines, the client
	the heartbeat and flicker. Pure.

	@class OccupantTellRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local OccupantAssets = require(OccupantShared.Data.OccupantAssets)
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local OccupantTypes = require(OccupantShared.Data.OccupantTypes)
local OccupantFaceUtils = require(OccupantShared.Utils.OccupantFaceUtils)
local OccupantGestureFormulas = require(OccupantShared.Utils.OccupantGestureFormulas)

-- Below this noise value a light near him is dark this instant.
local FLICKER_THRESHOLD = -0.1
-- How fast the flicker noise moves (per second).
local FLICKER_RATE = 7

local OccupantTellRules = {}

export type Stage = "none" | "far" | "mid" | "near" | "chase"

-- What his model shows for a mind (the server publishes it as attributes): his mode and target, the phase, the painted
-- face, the gesture (and the point a swivel turns to) and the catch's head tilt.
export type View = {
	mode: OccupantTypes.Mode,
	target: number,
	phase: string,
	face: OccupantAssets.Face,
	gesture: string,
	gestureTarget: Vector3?,
	tilt: boolean,
}

function OccupantTellRules.lineFor(cue: string?): string?
	if cue == nil then
		return nil
	end
	return OccupantConstants.LINES[cue]
end

--[=[
	What his model shows for `mind` at `now`.
]=]
function OccupantTellRules.view(mind: OccupantTypes.Mind, now: number): View
	local phaseAt = mind.phaseAt
	local swivelUntil = mind.swivelUntil
	local swivelling = swivelUntil ~= nil and now < swivelUntil and mind.point ~= nil
	return {
		mode = mind.mode,
		-- His chase target, or the hider he is at (a stare's or a sit-in's quarry: their client's reveal camera).
		target = mind.target or mind.quarry or 0,
		phase = mind.phase or "",
		face = OccupantFaceUtils.faceFor(mind.mode, mind.phase, if phaseAt ~= nil then now - phaseAt else 0),
		gesture = OccupantGestureFormulas.gestureFor(
			mind.mode,
			mind.phase,
			swivelling,
			mind.sitIn == true,
			mind.spot ~= nil
		),
		gestureTarget = if swivelling then mind.point else nil,
		tilt = mind.mode == "catch" and now - mind.since < OccupantConstants.SNAP_SECONDS + 0.5,
	}
end

--[=[
	Whether a hider's camera turns to his face: he is at their spot (`targetsMe`) bending down to look under it, opening
	the supply cabinet they hide in, or tipping his head under the desk they hide under, and they are hiding.
]=]
function OccupantTellRules.revealed(mode: string?, phase: string?, targetsMe: boolean, hiding: boolean): boolean
	if not targetsMe or not hiding then
		return false
	end
	return (mode == "stare" and (phase == "check" or phase == "open"))
		or (mode == "work" and (phase == "tip" or phase == "tipHold"))
end

--[=[
	Whether his typing plays: he sits at a desk typing (it stops dead in the ambush and while his head tips down).
]=]
function OccupantTellRules.typing(mode: string?, phase: string?): boolean
	return mode == "work" and (phase == "type" or phase == "typeMore")
end

--[=[
	The warning stage for a player `distance` studs from him; `huntingMe`: he chases this player.
]=]
function OccupantTellRules.stage(distance: number, mode: string?, huntingMe: boolean): Stage
	if mode == "chase" and huntingMe then
		return "chase"
	end
	if mode == "rest" or mode == nil then
		return "none"
	end
	if distance < OccupantConstants.STAGE_NEAR then
		return "near"
	elseif distance < OccupantConstants.STAGE_MID then
		return "mid"
	elseif distance < OccupantConstants.STAGE_FAR then
		return "far"
	end
	return "none"
end

--[=[
	A PA line with "{name}" replaced by `name`.
]=]
function OccupantTellRules.paLine(template: string, name: string): string
	local line = string.gsub(template, "{name}", function()
		return name
	end)
	return line
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

-- Only actual luminous panels or explicitly marked emitter geometry change, never the fixture housing.
function OccupantTellRules.isEmitter(material: Enum.Material, explicit: boolean): boolean
	return explicit or material == Enum.Material.Neon
end

return OccupantTellRules
