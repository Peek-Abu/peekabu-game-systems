--!strict
--[=[
	HideAssets: every asset id the Hide feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"). Registers its sounds at load on whichever realm requires this first (guarded):
	the server plays them through SoundServiceServer, the client requires this (HidePoseSystem) so the id is known.

	- TUMBLE: tumbling out of a spot pushed out "cramped" (the Manager's behaviours design §10.3). PLACEHOLDER: the
	  in-house body-fall C (characters/audio/listening/round3/masters/sfx/bodyfall_C.wav, the footstepBodyFall upload)
	  played quietly; a dedicated "tumble out of the furniture" sound is still to be made.

	Static data + registration (spec-exempt).

	@class HideAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local TUMBLE = "hideTumble"

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	[TUMBLE] = {
		assetId = "rbxassetid://83428002679573",
		group = "SFX",
		volume = 0.45,
		pitch = { min = 1.05, max = 1.15 },
		rollOffMaxDistance = 45,
	},
}

for id, def in SOUNDS do
	if not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	SOUNDS = table.freeze(SOUNDS),
	TUMBLE = TUMBLE,
})
