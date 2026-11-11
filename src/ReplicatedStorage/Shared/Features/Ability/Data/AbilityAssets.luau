--!strict
--[=[
	AbilityAssets: the ability sounds (in-house, owner-approved 2026-11-03; sources and settings in
	characters/launch/sounds-2026-10-30/WIRING.md), registered at load on whichever realm requires this first
	(guarded). `CLIP_SOUNDS` names the sound a clip plays from its first frame (each file has its lead silence built in,
	never trimmed): AbilityVfxSystem starts it as that clip starts on any character and fades it over CUT_FADE when the
	clip is cut short; a clip that ends on its own lets the tail ring. Popping out of a plant early has no sound
	(owner).

	Static data + registration (spec-exempt).

	@class AbilityAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- Pippa's rally, as the press is accepted: 3D on her root, everyone near.
	abilityLetsGo = {
		assetId = "rbxassetid://139330570557645",
		group = "SFX",
		bus = "Action",
		volume = 1,
		rollOffMaxDistance = 70,
		maxConcurrent = 4,
	},
	-- Cappy's ping as the treasure lights up: 2D, his ears only (stereo).
	abilitySpotPing = {
		assetId = "rbxassetid://118490563116936",
		group = "SFX",
		bus = "Action",
		volume = 0.8,
		maxConcurrent = 1,
	},
	-- Cappy's phone, from the Spot It! clip's first frame: 3D, everyone near.
	abilitySpotPhone = {
		assetId = "rbxassetid://106880741715758",
		group = "SFX",
		bus = "Action",
		volume = 0.9,
		rollOffMaxDistance = 40,
		maxConcurrent = 4,
	},
	-- Prickles into the pot and back out (the calm exit only), from the clips' first frames: very quiet on purpose
	-- (it is stealth), 3D, near only.
	abilityPlantIn = {
		assetId = "rbxassetid://88077512145082",
		group = "SFX",
		bus = "Action",
		volume = 5,
		rollOffMaxDistance = 20,
		maxConcurrent = 4,
	},
	abilityPlantOut = {
		assetId = "rbxassetid://137494633014979",
		group = "SFX",
		bus = "Action",
		volume = 5,
		rollOffMaxDistance = 20,
		maxConcurrent = 4,
	},
}

for id, def in SOUNDS do
	if not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

local CLIP_SOUNDS: { [string]: string } = {
	cappyspotit = "abilitySpotPhone",
	cappyspotitupper = "abilitySpotPhone",
	pricklesplantenter = "abilityPlantIn",
	pricklesplantexit = "abilityPlantOut",
}

return table.freeze({
	LETS_GO = "abilityLetsGo",
	SPOT_PING = "abilitySpotPing",
	CLIP_SOUNDS = table.freeze(CLIP_SOUNDS),
	-- A clip-timed sound whose clip is cut short fades out over this many seconds, never stops dead.
	CUT_FADE = 0.3,
})
