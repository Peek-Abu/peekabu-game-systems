--!strict
--[=[
	VoiceTypes: how one player hears another (design: docs/superpowers/specs/2026-10-09-voice-design.md).

	@class VoiceTypes
]=]

-- none: not heard; spatial: from their head by distance; radio: band-limited, at any range; direct: flat,
-- at any range (the dead channel).
export type Route = "none" | "spatial" | "radio" | "direct"

-- What routing needs to know about a player (read from their public entry).
export type VoiceInfo = {
	dead: boolean,
	radio: string?,
}

return {}
