--!strict
--[=[
	HideAssets: every asset id the Hide feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"). Registers its sounds at load on whichever realm requires this first (guarded):
	the server plays them through SoundServiceServer, the client requires this (HidePoseSystem) so the id is known.

	- TUMBLE: tumbling out of a spot pushed out "cramped" (the Manager's behaviours design §10.3). PLACEHOLDER: the
	  in-house body-fall C (characters/audio/listening/round3/masters/sfx/bodyfall_C.wav, the footstepBodyFall upload)
	  played quietly; a dedicated "tumble out of the furniture" sound is still to be made.
	- BREATH_CALM / BREATH_NERVOUS: Pippa's toon breath while you hide (2D, only for you; OccupantDreadSystem crossfades
	  them by the dread). In-house round-3 card 22 v2 "A, squeaky toy" (characters/audio/listening/round3/masters/breath2),
	  remade after "doesn't sound toony at all - sounds heavy like a person": no breath noise, all tonal and pitched in
	  F. A soft rubber-toy squeak goes "hee" up on the inhale and "hoo" down on the exhale, with triple-chirp bunny
	  sniffs, a felt "pum" and soft neck-bell tinkles; the nervous loop has fast wobbly pants up high, two-chirp sniffs
	  and her bell trembling. -24 / -22 LUFS loops, seamless.

	Static data + registration (spec-exempt).

	@class HideAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local TUMBLE = "hideTumble"
local BREATH_CALM = "hideBreathCalm"
local BREATH_NERVOUS = "hideBreathNervous"

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	[TUMBLE] = {
		assetId = "rbxassetid://83428002679573",
		group = "SFX",
		volume = 0.45,
		pitch = { min = 1.05, max = 1.15 },
		rollOffMaxDistance = 45,
	},
	[BREATH_CALM] = { assetId = "rbxassetid://140150448225283", group = "SFX", volume = 0.6, looped = true },
	[BREATH_NERVOUS] = { assetId = "rbxassetid://72152719558413", group = "SFX", volume = 0.6, looped = true },
}

for id, def in SOUNDS do
	if not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	SOUNDS = table.freeze(SOUNDS),
	TUMBLE = TUMBLE,
	BREATH_CALM = BREATH_CALM,
	BREATH_NERVOUS = BREATH_NERVOUS,
})
