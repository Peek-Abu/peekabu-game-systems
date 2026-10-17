--!strict
--[=[
	OccupantDreadFormulas: the Manager's proximity dread, as maths (2026-10-17 feedback: "getting chased doesn't feel
	scary"; "him nearby should have screen effects or heartbeats or both"). Every knob is OccupantConstants.DREAD.

	- `stage`: none (outside a shift, in the hub, him far or on his break, or catching you), near (he is within
	  RANGE_FAR and unaware), aware (he hunts, stares or turns on you), chase (he chases you), crew (a crewmate is chased
	  near you or the crewmate you spectate). A spectator only ever gets the crew look.
	- `proximity`: 0 at RANGE_FAR, 1 within RANGE_FULL; with no line of sight he counts OCCLUDED_SCALE times farther.
	- `target`: the stage's look (DREAD.LOOKS) at that proximity, chase closeness or crew weight; hiding near him makes
	  the heart loud and the world muffled.
	- `ease`: the look follows its target, rising faster than it falls (so an escape breathes out).
	- The heartbeat: `beatPeriod` (the chase's follows the music: `musicBeat`), `pulse` its shape.
	- `footfallTrauma`: his steps shake your camera while he sees or chases you, close.
	- `eq`: the ambience EQ's bands for a duck and a muffle.

	Shared and pure (the client's OccupantDreadSystem plays it).

	@class OccupantDreadFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)

type DreadLook = OccupantTypes.DreadLook
type DreadStage = OccupantTypes.DreadStage

local DREAD = OccupantConstants.DREAD

-- What the stage is read from (all replicated or local): whether this client is on a running shift and not in the
-- hub, whether it spectates, his mode / phase / target attribute, the local UserId, his proximity, and the crew weight
-- of a chased crewmate near the listener (0: none).
export type StageInput = {
	active: boolean,
	spectating: boolean,
	mode: string?,
	phase: string?,
	target: number,
	me: number,
	proximity: number,
	crew: number,
}

local ZERO: DreadLook = table.freeze({
	heart = 0,
	dread = 0,
	vignette = 0,
	desaturate = 0,
	grain = 0,
	red = 0,
	edge = 0,
	squeeze = 0,
	duck = 0,
	muffle = 0,
})

local function scaled(look: DreadLook, by: number): DreadLook
	return {
		heart = look.heart * by,
		dread = look.dread * by,
		vignette = look.vignette * by,
		desaturate = look.desaturate * by,
		grain = look.grain * by,
		red = look.red * by,
		edge = look.edge * by,
		squeeze = look.squeeze * by,
		duck = look.duck * by,
		muffle = look.muffle * by,
	}
end

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function blend(from: DreadLook, to: DreadLook, alpha: number): DreadLook
	return {
		heart = lerp(from.heart, to.heart, alpha),
		dread = lerp(from.dread, to.dread, alpha),
		vignette = lerp(from.vignette, to.vignette, alpha),
		desaturate = lerp(from.desaturate, to.desaturate, alpha),
		grain = lerp(from.grain, to.grain, alpha),
		red = lerp(from.red, to.red, alpha),
		edge = lerp(from.edge, to.edge, alpha),
		squeeze = lerp(from.squeeze, to.squeeze, alpha),
		duck = lerp(from.duck, to.duck, alpha),
		muffle = lerp(from.muffle, to.muffle, alpha),
	}
end

-- Modes in which he is hunting someone (or about to): "sees you or hunting".
-- `alert`: his head turned to something he half noticed (behaviours design §10.2).
local HUNTING: { [string]: boolean } =
	{ investigate = true, search = true, stare = true, chase = true, catch = true, alert = true }
-- Modes in which he goes about his business, unaware.
local UNAWARE: { [string]: boolean } = { patrol = true, work = true }

-- The slow turns' phases (behaviours design §11.2), standing (alert) or seated (work).
local SLOW_PHASES: { [string]: boolean } = { slowTurn = true, staring = true }

local OccupantDreadFormulas = {}

OccupantDreadFormulas.ZERO = ZERO

--[=[
	Whether he is in a slow turn or a stare (behaviours design §11.2): the aware stage at full strength, the music
	near-silent.
]=]
function OccupantDreadFormulas.slow(mode: string?, phase: string?): boolean
	return (mode == "alert" or mode == "work") and phase ~= nil and SLOW_PHASES[phase] == true
end

--[=[
	His proximity (0..1) at `distance` studs; `sight` 1 = clear line of sight to his head, 0 = none (blended between).
]=]
function OccupantDreadFormulas.proximity(distance: number, sight: number): number
	local scale = lerp(DREAD.OCCLUDED_SCALE, 1, math.clamp(sight, 0, 1))
	local effective = distance * scale
	return 1 - math.clamp((effective - DREAD.RANGE_FULL) / (DREAD.RANGE_FAR - DREAD.RANGE_FULL), 0, 1)
end

--[=[
	The weight of the crew look for a chased crewmate `distance` studs from the listener: 1 beside them, CREW_FLOOR at
	CREW_RANGE, 0 beyond.
]=]
function OccupantDreadFormulas.crewWeight(distance: number): number
	if distance > DREAD.CREW_RANGE then
		return 0
	end
	return lerp(1, DREAD.CREW_FLOOR, math.clamp(distance / DREAD.CREW_RANGE, 0, 1))
end

function OccupantDreadFormulas.stage(input: StageInput): DreadStage
	if not input.active then
		return "none"
	end
	local mode = input.mode
	local onMe = input.target ~= 0 and input.target == input.me
	if mode == "catch" and onMe then
		return "none"
	end
	if not input.spectating then
		if mode == "chase" and onMe then
			return "chase"
		end
		if input.proximity > 0 and mode ~= nil then
			if HUNTING[mode] or (onMe and mode ~= "rest") or OccupantDreadFormulas.slow(mode, input.phase) then
				return "aware"
			end
			if UNAWARE[mode] then
				return "near"
			end
		end
	end
	if input.crew > 0 and mode == "chase" then
		return "crew"
	end
	return "none"
end

--[=[
	The look `stage` aims for: near scaled by `proximity`; aware by max(proximity, AWARE_FLOOR); the chase blended
	chaseFar -> chaseNear by `closeness` (the chase music's layer, 0..1); crew scaled by `crew`. `hidden`: hiding while
	he is near (any stage but none and crew) holds the heart at HIDDEN_HEART and muffles the world. `slow`: his slow turn
	or stare (§11.2): the aware stage shows the slowTurn look, unscaled.
]=]
function OccupantDreadFormulas.target(
	stage: DreadStage,
	proximity: number,
	closeness: number,
	crew: number,
	hidden: boolean,
	slow: boolean?
): DreadLook
	local looks = DREAD.LOOKS
	local look: DreadLook
	if stage == "aware" and slow == true then
		look = scaled(looks.slowTurn, 1)
	elseif stage == "near" then
		look = scaled(looks.near, math.clamp(proximity, 0, 1))
	elseif stage == "aware" then
		look = scaled(looks.aware, math.max(math.clamp(proximity, 0, 1), DREAD.AWARE_FLOOR))
	elseif stage == "chase" then
		look = blend(looks.chaseFar, looks.chaseNear, math.clamp(closeness, 0, 1))
	elseif stage == "crew" then
		look = scaled(looks.crew, math.clamp(crew, 0, 1))
	else
		return ZERO
	end
	if hidden and stage ~= "crew" then
		look.heart = math.max(look.heart, DREAD.HIDDEN_HEART)
		look.muffle = math.min(look.muffle, DREAD.HIDDEN_MUFFLE)
		look.duck = math.min(look.duck, DREAD.HIDDEN_DUCK)
		look.vignette += DREAD.HIDDEN_VIGNETTE
	end
	look.vignette = math.clamp(look.vignette, 0, 1)
	look.grain = math.clamp(look.grain, 0, 1)
	return look
end

-- One field one step toward its target: RISE_SHARPNESS while it grows in strength, FALL_SHARPNESS while it lets go.
local function step(current: number, target: number, dt: number): number
	local sharpness = if math.abs(target) > math.abs(current) then DREAD.RISE_SHARPNESS else DREAD.FALL_SHARPNESS
	return current + (target - current) * (1 - math.exp(-sharpness * dt))
end

function OccupantDreadFormulas.ease(current: DreadLook, target: DreadLook, dt: number): DreadLook
	return {
		heart = step(current.heart, target.heart, dt),
		dread = step(current.dread, target.dread, dt),
		vignette = step(current.vignette, target.vignette, dt),
		desaturate = step(current.desaturate, target.desaturate, dt),
		grain = step(current.grain, target.grain, dt),
		red = step(current.red, target.red, dt),
		edge = step(current.edge, target.edge, dt),
		squeeze = step(current.squeeze, target.squeeze, dt),
		duck = step(current.duck, target.duck, dt),
		muffle = step(current.muffle, target.muffle, dt),
	}
end

--[=[
	The look with reduce motion applied (no FOV squeeze, no edge fringe); the same table when it is off.
]=]
function OccupantDreadFormulas.reduce(look: DreadLook, reduceMotion: boolean): DreadLook
	if not reduceMotion then
		return look
	end
	local copy = table.clone(look)
	copy.squeeze = 0
	copy.edge = 0
	return copy
end

--[=[
	Seconds per heartbeat for `stage` (nil: no heartbeat of its own; the chase's follows the music's beat).
]=]
function OccupantDreadFormulas.beatPeriod(stage: DreadStage, proximity: number, slow: boolean?): number?
	if stage == "aware" and slow == true then
		return DREAD.BEAT_SLOW
	elseif stage == "near" then
		return lerp(DREAD.BEAT_NEAR_SLOW, DREAD.BEAT_NEAR_FAST, math.clamp(proximity, 0, 1))
	elseif stage == "aware" then
		return DREAD.BEAT_AWARE
	elseif stage == "crew" then
		return DREAD.BEAT_CREW
	end
	return nil
end

--[=[
	A beat's pulse (0..1) `since` seconds after it, at `period` seconds per beat: 1 on the beat, easing to 0 at
	PULSE_WIDTH of the period.
]=]
function OccupantDreadFormulas.pulse(since: number, period: number): number
	if period <= 0 then
		return 0
	end
	local x = math.clamp(1 - since / (period * DREAD.PULSE_WIDTH), 0, 1)
	return x * x
end

--[=[
	Which beat of the chase music `position` seconds into its loop is (0-based).
]=]
function OccupantDreadFormulas.musicBeat(position: number): number
	return math.floor(position / OccupantConstants.CHASE_BEAT + 1e-6)
end

--[=[
	The camera trauma one of his footfalls `distance` studs away adds: only while he sees or chases you.
]=]
function OccupantDreadFormulas.footfallTrauma(stage: DreadStage, distance: number): number
	if stage ~= "aware" and stage ~= "chase" then
		return 0
	end
	return DREAD.SHAKE_TRAUMA * math.clamp(1 - distance / DREAD.SHAKE_RANGE, 0, 1)
end

--[=[
	The ambience EQ's low / mid / high gains (dB) for a `duck` and a `muffle` (both <= 0).
]=]
function OccupantDreadFormulas.eq(duck: number, muffle: number): (number, number, number)
	return duck, duck + muffle * DREAD.MUFFLE_MID, duck + muffle
end

return OccupantDreadFormulas
