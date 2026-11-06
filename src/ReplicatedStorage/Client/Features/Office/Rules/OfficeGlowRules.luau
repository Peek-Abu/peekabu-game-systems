--!strict
--[=[
	OfficeGlowRules: the office's light from cleaning and from the crew (OfficeGlowSystem). Pure.

	- A room glows (a soft warm light of its own, faded in over FADE_SECONDS) once it had Gloom piles this shift and
	  has none left. Only rooms within JUDGE_RANGE of the camera are judged: far piles may not be streamed in, and a
	  room must never glow because its piles are out of range.
	- Every crew member carries a small warm lantern. Yours always; a teammate's only within CULL_RANGE, and not at
	  all on low graphics (quality 1 to LOW_QUALITY; 0 is Automatic, not low). On low graphics, rooms do not glow.

	@class OfficeGlowRules
]=]

local OfficeGlowRules = {}

OfficeGlowRules.JUDGE_RANGE = 160
OfficeGlowRules.FADE_SECONDS = 1.5
OfficeGlowRules.GLOW_BRIGHTNESS = 0.9
OfficeGlowRules.MAX_RANGE = 40
OfficeGlowRules.LANTERN_BRIGHTNESS = 0.7
OfficeGlowRules.LANTERN_RANGE = 14
OfficeGlowRules.CULL_RANGE = 90
OfficeGlowRules.LOW_QUALITY = 3

function OfficeGlowRules.cleaned(pilesLeft: number, hadGloom: boolean): boolean
	return hadGloom and pilesLeft == 0
end

function OfficeGlowRules.judged(distance: number): boolean
	return distance <= OfficeGlowRules.JUDGE_RANGE
end

--[=[
	The glow's brightness `seconds` after the room was cleaned.
]=]
function OfficeGlowRules.glow(seconds: number): number
	local t = math.clamp(seconds / OfficeGlowRules.FADE_SECONDS, 0, 1)
	return OfficeGlowRules.GLOW_BRIGHTNESS * (t * t * (3 - 2 * t))
end

--[=[
	The glow's range for a room of floor `size`: across the room, up to MAX_RANGE.
]=]
function OfficeGlowRules.range(size: Vector3): number
	return math.min(math.max(size.X, size.Z) * 0.75 + 6, OfficeGlowRules.MAX_RANGE)
end

--[=[
	A lantern's brightness (nil: none): yours always; a teammate's within CULL_RANGE, never on low graphics.
]=]
function OfficeGlowRules.lantern(mine: boolean, quality: number, distance: number): number?
	if mine then
		return OfficeGlowRules.LANTERN_BRIGHTNESS
	end
	if OfficeGlowRules.lowEnd(quality) or distance > OfficeGlowRules.CULL_RANGE then
		return nil
	end
	return OfficeGlowRules.LANTERN_BRIGHTNESS
end

--[=[
	Whether a saved graphics quality (0 = Automatic, 1-10) is low.
]=]
function OfficeGlowRules.lowEnd(quality: number): boolean
	return quality >= 1 and quality <= OfficeGlowRules.LOW_QUALITY
end

return OfficeGlowRules
