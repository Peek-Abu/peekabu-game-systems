--!strict
--[=[
	OccupantDreadConstants: the dread table (the proximity dread and the chase's feel and mix). Split out of
	OccupantConstants, which re-exports it unchanged as OccupantConstants.DREAD: read it from there. Static data
	(spec-exempt).

	@class OccupantDreadConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)

type DreadLook = OccupantTypes.DreadLook

local function look(values: DreadLook): DreadLook
	return table.freeze(values)
end

--[=[
	THE dread table (2026-10-17 feedback: "getting chased doesn't feel scary", "him nearby should have screen effects or
	heartbeats or both"). Every knob of the proximity dread and the chase's feel and mix (OccupantDreadFormulas,
	OccupantDreadSystem, OccupantChaseMusicSystem). Kid-safe: nothing strobes, the vignette never closes the view, and
	every change eases. No markers over him: all of it is screen mood and sound.
]=]
local DREAD = {
	-- Distance (studs) where the dread starts, and where it is full. Beyond RANGE_FAR nothing shows.
	RANGE_FAR = 60,
	RANGE_FULL = 20,
	-- With no line of sight to his head his distance counts this many times farther (walls take the edge off).
	OCCLUDED_SCALE = 1.6,
	-- The line-of-sight ray is re-cast this often (s), and a change in sight blends in over SIGHT_EASE (s).
	SIGHT_INTERVAL = 0.15,
	SIGHT_EASE = 0.5,
	-- "Sees you or hunting" never shows weaker than this share of the aware look, however far he is.
	AWARE_FLOOR = 0.55,
	-- A crewmate chased within CREW_RANGE studs of you (or of the crewmate you spectate) gives you the crew look,
	-- weighted from 1 next to them down to CREW_FLOOR at the edge.
	CREW_RANGE = 45,
	CREW_FLOOR = 0.4,
	-- How fast the look follows its target (1/s, exponential): it rises quickly and breathes out slowly after an escape.
	RISE_SHARPNESS = 3,
	FALL_SHARPNESS = 1.1,
	-- Heartbeat seconds per beat: near ramps BEAT_NEAR_SLOW (at RANGE_FAR) to BEAT_NEAR_FAST (at RANGE_FULL); aware and
	-- crew beat at their own rates. The chase's beat is the music's (CHASE_BEAT, locked to the stems' TimePosition).
	BEAT_NEAR_SLOW = 1.15,
	BEAT_NEAR_FAST = 0.7,
	BEAT_AWARE = 0.55,
	BEAT_CREW = 0.62,
	-- A slow turn or a stare (behaviours design §11.2): the aware stage at full strength, beating faster.
	BEAT_SLOW = 0.5,
	-- The heartbeat sound's volumeScale = look.heart * HEART_GAIN (harlowHeartbeat is registered at 0.8). Measured live
	-- 2026-10-17 in a chase at ~19 studs (RMS of PlaybackLoudness x Volume x group volume): the old heartbeat sat
	-- ~19 dB over the old chase music; at 0.75 (chase heart 0.65-0.8) it sits ~5 dB over the louder music.
	HEART_GAIN = 0.75,
	-- A pulse peaks on the beat and is gone PULSE_WIDTH of the way to the next (a quick attack, eased decay).
	PULSE_WIDTH = 0.45,
	-- The colour the beat pulses toward (multiplied into the screen tint), kept soft.
	PULSE_TINT = Color3.fromRGB(255, 150, 150),
	-- The edge fringe's two tints (a red and a cyan copy of the vignette pushed apart on the beat: the chromatic split).
	EDGE_RED = Color3.fromRGB(255, 70, 70),
	EDGE_CYAN = Color3.fromRGB(70, 230, 255),
	-- How far (screen scale) the edge fringe's copies spread at a full pulse.
	EDGE_SPREAD = 0.035,
	-- The vignette is dark ink, never black, at most VIGNETTE_MAX opaque at the edge.
	VIGNETTE_COLOR = Color3.fromRGB(8, 4, 10),
	VIGNETTE_MAX = 0.85,
	-- How much the vignette tightens (screen scale shrink) at full strength.
	VIGNETTE_TIGHTEN = 0.12,
	-- The grain's tile size (pixels) and its opacity at full strength.
	GRAIN_TILE = 180,
	GRAIN_MAX = 0.22,
	-- His footfalls shake your camera (trauma, camera-setting scaled) within SHAKE_RANGE studs while he sees you or
	-- chases you: SHAKE_TRAUMA at his feet, 0 at the range.
	SHAKE_RANGE = 22,
	SHAKE_TRAUMA = 0.16,
	-- The ambience EQ: the duck on every band, and the muffle on the highs (the mids take MUFFLE_MID of it). Applied to
	-- the Ambient group and to every other Music-group sound (never to his sounds, the chase stems or the dread loop).
	MUFFLE_MID = 0.35,
	-- The chase music's stems play this much louder than registered (+8 dB). Measured 2026-10-17 (offline, in-game
	-- volume chain): the old chase sat 3-11 dB under his running steps and 2-3 dB under the office bed; at 2.5 it sits
	-- level with his steps at 15 studs, 3.6 dB under them at 8 and ~19 dB over the ducked bed.
	CHASE_MUSIC_GAIN = 2.5,
	-- Intensity 2 of the chase music (motif, ticks, pulse): silent from CHASE_LAYER_FAR studs out, full within
	-- CHASE_LAYER_NEAR (2026-10-17: was 34 / 14, so it already sounds dangerous at mid distance).
	CHASE_LAYER_NEAR = 18,
	CHASE_LAYER_FAR = 50,
	-- The dread loop fades out over this (s) when the dread lets go.
	DREAD_FADE = 1.5,
	-- Accessibility default (OccupantDreadSystem.setReduceMotion): no FOV squeeze, no edge fringe, no beat flashing
	-- (the red holds steady at REDUCED_RED of its peak), still grain. Camera shake follows the cameraShake setting.
	REDUCE_MOTION = false,
	REDUCED_RED = 0.35,
	-- Each stage's look. near is scaled by proximity, aware by max(proximity, AWARE_FLOOR), the chase blends
	-- CHASE_FAR -> CHASE_NEAR by the chase layer's closeness, crew is scaled by the crew weight.
	LOOKS = table.freeze({
		near = look({
			heart = 0.5,
			dread = 1,
			vignette = 0.45,
			desaturate = 0.22,
			grain = 0.5,
			red = 0.1,
			edge = 0,
			squeeze = 0,
			duck = -5,
			muffle = -3,
		}),
		aware = look({
			heart = 0.8,
			dread = 1,
			vignette = 0.55,
			desaturate = 0.3,
			grain = 0.75,
			red = 0.28,
			edge = 0.45,
			squeeze = 0,
			duck = -8,
			muffle = -6,
		}),
		chaseFar = look({
			heart = 0.65,
			dread = 0,
			vignette = 0.5,
			desaturate = 0.3,
			grain = 0.8,
			red = 0.5,
			edge = 0.5,
			squeeze = 2,
			duck = -12,
			muffle = -6,
		}),
		chaseNear = look({
			heart = 0.8,
			dread = 0,
			vignette = 0.7,
			desaturate = 0.4,
			grain = 1,
			red = 0.7,
			edge = 0.9,
			squeeze = 7,
			duck = -15,
			muffle = -20,
		}),
		-- His slow turn or his stare (§11.2): unscaled by distance. The music ducks to near-silence (-30 dB) so the creak
		-- and your heartbeat are all there is; the dread loop sits back too.
		slowTurn = look({
			heart = 1,
			dread = 0.5,
			vignette = 0.7,
			desaturate = 0.4,
			grain = 0.9,
			red = 0.35,
			edge = 0.4,
			squeeze = 3,
			duck = -30,
			muffle = -12,
		}),
		crew = look({
			heart = 0.45,
			dread = 0.5,
			vignette = 0.3,
			desaturate = 0.15,
			grain = 0.4,
			red = 0.12,
			edge = 0.2,
			squeeze = 0,
			duck = -5,
			muffle = -4,
		}),
	}),
	-- Hiding while he is near (near, aware or chase): the heart at least HIDDEN_HEART, the world muffled to at least
	-- HIDDEN_MUFFLE and ducked to at least HIDDEN_DUCK (dB), the vignette HIDDEN_VIGNETTE stronger.
	HIDDEN_HEART = 1,
	HIDDEN_MUFFLE = -22,
	HIDDEN_DUCK = -9,
	HIDDEN_VIGNETTE = 0.1,
	-- While a camera frames his face (the catch's jumpscare, the hider's reveal; OccupantFaceLightSystem lights it), the
	-- screen side of the look eases back to these shares (OccupantDreadFormulas.framed) over FACE_EASE (1/s): the
	-- vignette, the grey and the red pulse had stacked with the catch's own red screen and the lights-out until his
	-- face was a dark smudge (user, 2026-10-17). The fringe goes entirely.
	FACE_VIGNETTE = 0.35,
	FACE_DESATURATE = 0.3,
	FACE_RED = 0.2,
	FACE_GRAIN = 0.5,
	FACE_EASE = 12,
	-- The "monster near" sting (OccupantAssets monsterNear, every kind's; owner 2026-11-17: "any monster getting close, a
	-- new sound for all"): once as the near or aware stage begins, then not again for this many seconds. Your own chase
	-- restarts the wait too (its sting covers that moment), so the end of a chase never stings
	-- (OccupantDreadFormulas.nearSting).
	NEAR_STING_COOLDOWN = 25,
}

return table.freeze(DREAD)
