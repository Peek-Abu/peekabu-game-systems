--!strict
--[=[
	SoundTypes: the types the Sound feature shares. Types only (spec-exempt).

	@class SoundTypes
]=]

export type SoundGroupName = "Music" | "SFX" | "UI" | "Ambient"

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
}

-- Where a sound plays from: nothing (2D), a part or attachment (follows it), or a fixed point.
export type PlayAt = BasePart | Attachment | Vector3

export type PlayOptions = {
	at: PlayAt?,
	-- Multiplies the registry volume (1 = as registered).
	volumeScale: number?,
}

return {}
