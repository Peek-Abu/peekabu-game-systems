--!strict
--[=[
	FootstepBodyAssets: the body's other contacts with the floor (FootstepLandingSystem), split out of FootstepAssets.
	Per character in BODY_SETS: `default` (Pippa's: JUMPS, round-3 final pick J4 "ears + bell", four variants, one at
	random each jump, +-4 % speed, and LAND, final pick A), `cappy` (his shuffle's jump and skid-free land) and
	`prickles` (roots pulling free, a stump landing). BODY_FALL (pick C, a plush flop + cushion + a tiny toy squeak) is
	everyone's ragdoll landing.

	Registers each sound in SoundRegistry at load (guarded, through the Steps bus). FootstepAssets requires it at the
	point the body sounds used to register (after the step sets and the layers) and re-exports LAND, BODY_FALL, JUMPS
	and BODY_SETS; it freezes BODY_SETS there, so this module leaves that table unfrozen. Static data + registration
	(spec-exempt).

	@class FootstepBodyAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootstepTypes = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepTypes)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

-- The body meeting the floor (FootstepLandingSystem): 3D on the root, every character this client sees.
local LAND = "footstepLand"
local BODY_FALL = "footstepBodyFall"
local JUMPS: { string } = { "footstepJump1", "footstepJump2", "footstepJump3", "footstepJump4" }
local JUMP_PITCH = { min = 0.96, max = 1.04 }
local BODY_SOUNDS: { [string]: SoundTypes.SoundDef } = {
	[LAND] = {
		assetId = "rbxassetid://74178964320795",
		group = "SFX",
		volume = 0.65,
		rollOffMaxDistance = 50,
	},
	[BODY_FALL] = {
		assetId = "rbxassetid://83428002679573",
		group = "SFX",
		volume = 0.7,
		rollOffMaxDistance = 70,
	},
	footstepJump1 = {
		assetId = "rbxassetid://75215822235284",
		group = "SFX",
		volume = 0.9,
		pitch = JUMP_PITCH,
		rollOffMaxDistance = 50,
	},
	footstepJump2 = {
		assetId = "rbxassetid://92706735865785",
		group = "SFX",
		volume = 0.9,
		pitch = JUMP_PITCH,
		rollOffMaxDistance = 50,
	},
	footstepJump3 = {
		assetId = "rbxassetid://120963948172610",
		group = "SFX",
		volume = 0.9,
		pitch = JUMP_PITCH,
		rollOffMaxDistance = 50,
	},
	footstepJump4 = {
		assetId = "rbxassetid://103405107640627",
		group = "SFX",
		volume = 0.9,
		pitch = JUMP_PITCH,
		rollOffMaxDistance = 50,
	},
	-- Cappy's (the shuffle, set C) and Prickles' (roots A) jumps and lands. Their lands measure within 1 dB of Pippa's, so all play at 0.9.
	footstepJump_cappy_1 = {
		assetId = "rbxassetid://102041040422298",
		group = "SFX",
		volume = 0.9,
		pitch = JUMP_PITCH,
		rollOffMaxDistance = 50,
	},
	footstepJump_cappy_2 = {
		assetId = "rbxassetid://134205180375692",
		group = "SFX",
		volume = 0.9,
		pitch = JUMP_PITCH,
		rollOffMaxDistance = 50,
	},
	footstepJump_cappy_3 = {
		assetId = "rbxassetid://117292305416586",
		group = "SFX",
		volume = 0.9,
		pitch = JUMP_PITCH,
		rollOffMaxDistance = 50,
	},
	footstepJump_cappy_4 = {
		assetId = "rbxassetid://76252590538496",
		group = "SFX",
		volume = 0.9,
		pitch = JUMP_PITCH,
		rollOffMaxDistance = 50,
	},
	footstepLand_cappy = {
		assetId = "rbxassetid://139676980813049",
		group = "SFX",
		volume = 0.65,
		rollOffMaxDistance = 50,
	},
	footstepJump_prickles_1 = {
		assetId = "rbxassetid://98559040398080",
		group = "SFX",
		volume = 0.9,
		pitch = JUMP_PITCH,
		rollOffMaxDistance = 50,
	},
	footstepJump_prickles_2 = {
		assetId = "rbxassetid://82600384396505",
		group = "SFX",
		volume = 0.9,
		pitch = JUMP_PITCH,
		rollOffMaxDistance = 50,
	},
	footstepJump_prickles_3 = {
		assetId = "rbxassetid://131517456957543",
		group = "SFX",
		volume = 0.9,
		pitch = JUMP_PITCH,
		rollOffMaxDistance = 50,
	},
	footstepJump_prickles_4 = {
		assetId = "rbxassetid://104478192930648",
		group = "SFX",
		volume = 0.9,
		pitch = JUMP_PITCH,
		rollOffMaxDistance = 50,
	},
	footstepLand_prickles = {
		assetId = "rbxassetid://89284924285103",
		group = "SFX",
		volume = 0.65,
		rollOffMaxDistance = 50,
	},
}
-- Every jump, land and fall plays through the Steps bus with the footsteps.
for id, def in BODY_SOUNDS do
	if not SoundRegistry.has(id) then
		local stepped = table.clone(def)
		stepped.bus = "Steps"
		SoundRegistry.register(id, stepped)
	end
end

-- Each character's jump and land (FootstepLandingFormulas.bodySet picks the set; `default` is Pippa's, for everyone else).
local BODY_SETS: { [string]: FootstepTypes.BodySet } = {
	default = { land = LAND, jumps = JUMPS },
	cappy = {
		land = "footstepLand_cappy",
		jumps = { "footstepJump_cappy_1", "footstepJump_cappy_2", "footstepJump_cappy_3", "footstepJump_cappy_4" },
	},
	prickles = {
		land = "footstepLand_prickles",
		jumps = {
			"footstepJump_prickles_1",
			"footstepJump_prickles_2",
			"footstepJump_prickles_3",
			"footstepJump_prickles_4",
		},
	},
}
-- This freezes JUMPS too (BODY_SETS.default shares it), so the return below must not freeze it again.
for _, bodySet in BODY_SETS do
	table.freeze(bodySet.jumps)
	table.freeze(bodySet)
end

return table.freeze({
	LAND = LAND,
	BODY_FALL = BODY_FALL,
	JUMPS = JUMPS,
	BODY_SETS = BODY_SETS,
})
