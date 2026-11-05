--!strict
--[=[
	SoundTypes: the types the Sound feature shares. Types only (spec-exempt).

	@class SoundTypes
]=]

export type SoundGroupName = "Music" | "SFX" | "UI" | "Ambient"

-- Where a positional sound plays, for the place cut (design: docs/superpowers/specs/2026-11-04-sound-places.md):
-- inside the building, or out in the yard and car park. Only the listener's own place is heard.
export type SoundPlace = "Building" | "Outside"

-- An outdoor volume in the world, min and max corners: a point in one is Outside.
export type SoundPlaceBox = { min: Vector3, max: Vector3 }

export type SoundDef = {
	-- Canonical `rbxassetid://N`.
	assetId: string,
	group: SoundGroupName,
	-- 0..10 (the Sound.Volume range).
	volume: number,
	-- PlaybackSpeed range; each play picks a value in it (variety for repeated sounds). Absent = 1.
	pitch: { min: number, max: number }?,
	looped: boolean?,
	-- At most this many copies of this id play at once; a new one stops the oldest. Absent = unlimited.
	maxConcurrent: number?,
	-- Positional sounds: the distance at which the sound is inaudible. Absent = the engine default.
	rollOffMaxDistance: number?,
	-- A rare positional world sound that must carry everywhere (an alarm, a horn): never cut by the places. Absent =
	-- false.
	heardEverywhere: boolean?,
	-- Pins the sound to one place wherever it plays, 2D included: a 2D bed of the yard (Outside) or of the office
	-- (Building) is then heard only there, and the place switch crossfades the two at every door (design:
	-- docs/superpowers/specs/2026-11-04-yard-place-design.md). Absent = placed by where it plays (2D: placeless).
	place: SoundPlace?,
}

-- Where a sound plays from: nothing (2D), a part or attachment (follows it), or a fixed point.
export type PlayAt = BasePart | Attachment | Vector3

export type PlayOptions = {
	at: PlayAt?,
	-- Multiplies the registry volume (1 = as registered).
	volumeScale: number?,
	-- Multiplies the picked pitch (PlaybackSpeed; 1 = as registered).
	pitchScale: number?,
}

return {}
