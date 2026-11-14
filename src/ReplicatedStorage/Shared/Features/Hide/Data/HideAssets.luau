--!strict
--[=[
	HideAssets: every asset id the Hide feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"). Registers its sounds at load on whichever realm requires this first (guarded):
	the server plays them through SoundServiceServer, the client requires this (HidePoseSystem) so the id is known.

	- IN / OUT: crawling into a spot (cloth rustle + a soft wood creak) and climbing out on your own (cloth + a light
	  wood knock), 3D from the spot (P0.5 round 2 picks A, in-house SA3 foley, the event alone; Icey Labs 2026-11-14).
	- TUMBLE: tumbling out of a spot pushed out "cramped" (the Manager's behaviours design §10.3): its own bump on the
	  furniture, body thud and roll (P0.5 round 2 pick A), no longer the body-fall it borrowed.

	Static data + registration (spec-exempt).

	@class HideAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local TUMBLE = "hideTumble"
local IN = "hideIn"
local OUT = "hideOut"

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	[TUMBLE] = {
		assetId = "rbxassetid://122926404383994",
		group = "SFX",
		bus = "Action",
		volume = 0.9,
		pitch = { min = 0.97, max = 1.03 },
		rollOffMaxDistance = 45,
	},
	[IN] = {
		assetId = "rbxassetid://112669131353651",
		group = "SFX",
		bus = "Action",
		volume = 1,
		pitch = { min = 0.96, max = 1.04 },
		rollOffMaxDistance = 45,
	},
	[OUT] = {
		assetId = "rbxassetid://138926184712996",
		group = "SFX",
		bus = "Action",
		volume = 1,
		pitch = { min = 0.96, max = 1.04 },
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
	IN = IN,
	OUT = OUT,
})
