--!strict
--[=[
	FootstepAssets: every footstep sound, per character set and per surface. THE table the sound work fills in:

	  SETS.<set>.surfaces.<surface> = { "rbxassetid://A", "rbxassetid://B", ... }

	- <set>: `pippa` (an employee's set is its EmployeeName attribute in lower case), `harlow` (the Manager, by his
	  Occupant tag), `default` (any other player character). A new character is one more entry; a model can also name
	  its set with the FootstepSet attribute.
	- <surface>: `default`, `carpet`, `tile`, `wood`, `concrete` (FootstepSurfaceUtils maps the floor's material, or
	  its FootstepSurface attribute). An empty surface plays the set's `default` pool, which must not be empty.
	- Each step plays ONE id from the pool at random (never the same one twice in a row on one foot), at a pitch picked
	  in `pitch`, then scaled by the gait (`gaits`: walk / sprint / crouch / hidden). Five to eight variants per pool is
	  plenty; a variant is one footfall, trimmed tight (its onset at 0 ms: the step plays the frame the foot lands).
	- Volume, roll-off and the gait scales are per set; the sounds play in the SFX group, 3D on the foot that landed.

	The in-house sets (round-3 picks, 2026-10-17): ONE sound per character, not per material (the user's call), so each
	set fills only its `default` pool, which every surface falls back to. Six walk variants each, at their real pitch
	(jitter about +-4 %); a run is the same files at the sprint gait's volume and pitch (measured: the run files are
	only +1.7 dB, 15 % shorter and 4 % brighter than the walk ones, which the sprint scale covers).
	- pippa: family C (felt + fur), the carpet set: felt taps, a light heel, a cloth/fur swish.
	- harlow: family B (porcelain heel), the tile set: a hard heel with a faint glassy porcelain ring.

	Also the body's other contacts with the floor (FootstepLandingSystem): LAND (round-3 pick B, a toon plush pad +
	scuff + cloth) and BODY_FALL (pick C, a plush flop + cushion + a tiny toy squeak, for a ragdoll landing); and
	DEFAULT_JUMP, the engine's own jump clip, kept until the in-house jump is remade (an `rbxasset://` content path the
	registry does not take, so it is played as it is).

	Registers each id in SoundRegistry at load (as `footstep_<set>_<surface>_<n>`, guarded) and exposes those names as
	SOUND_IDS[set][surface]. Static data + registration (spec-exempt).

	@class FootstepAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootstepTypes = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepTypes)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

type FootstepSet = FootstepTypes.FootstepSet
type SurfacePools = FootstepTypes.SurfacePools

local SETS: { [string]: FootstepSet } = {
	-- Pippa: a small bunny in work shoes (family C, felt + fur; the files sit at -28 LUFS, soft on purpose).
	pippa = {
		volume = 0.9,
		pitch = { min = 0.96, max = 1.04 },
		rollOffMaxDistance = 45,
		-- Her WalkSpeed and her sprint (SprintConstants.SPRINT_SPEED).
		walkSpeed = 16,
		runSpeed = 23,
		gaits = {
			walk = { volume = 1, pitch = 1 },
			sprint = { volume = 1.5, pitch = 1.05 },
			crouch = { volume = 0.4, pitch = 0.95 },
			hidden = { volume = 0, pitch = 1 },
		},
		surfaces = {
			default = {
				"rbxassetid://101017787523662",
				"rbxassetid://127149738397603",
				"rbxassetid://127212551313099",
				"rbxassetid://120263733467035",
				"rbxassetid://73106734062818",
				"rbxassetid://91206486483140",
			},
			carpet = {},
			tile = {},
			wood = {},
			concrete = {},
		},
	},
	-- Mr. Harlow: hard porcelain heels, too regular, heard through walls out to the far warning stage (OccupantConstants
	-- STAGE_FAR). His walk is planted at 10 st/s and his chase run at 20 (OccupantAssets.ANIMATIONS); a step lands up to
	-- 1.6x louder as he speeds up (2026-10-16: the crew near a chase hears him running).
	harlow = {
		volume = 0.8,
		pitch = { min = 0.97, max = 1.03 },
		rollOffMaxDistance = 85,
		walkSpeed = 10,
		runSpeed = 20,
		gaits = {
			walk = { volume = 1, pitch = 1 },
			sprint = { volume = 1.6, pitch = 1.05 },
			crouch = { volume = 0.5, pitch = 1 },
			hidden = { volume = 0, pitch = 1 },
		},
		surfaces = {
			default = {
				"rbxassetid://133551413381168",
				"rbxassetid://88106743907925",
				"rbxassetid://98010848069196",
				"rbxassetid://88206001507305",
				"rbxassetid://135732299311630",
				"rbxassetid://85044629522323",
			},
			carpet = {},
			tile = {},
			wood = {},
			concrete = {},
		},
	},
	-- Any other player character: Pippa's steps (every employee is a Pippa today).
	default = {
		volume = 0.9,
		pitch = { min = 0.96, max = 1.04 },
		rollOffMaxDistance = 45,
		walkSpeed = 16,
		runSpeed = 23,
		gaits = {
			walk = { volume = 1, pitch = 1 },
			sprint = { volume = 1.5, pitch = 1.05 },
			crouch = { volume = 0.4, pitch = 0.95 },
			hidden = { volume = 0, pitch = 1 },
		},
		surfaces = {
			default = {
				"rbxassetid://101017787523662",
				"rbxassetid://127149738397603",
				"rbxassetid://127212551313099",
				"rbxassetid://120263733467035",
				"rbxassetid://73106734062818",
				"rbxassetid://91206486483140",
			},
			carpet = {},
			tile = {},
			wood = {},
			concrete = {},
		},
	},
}

-- SOUND_IDS[set][surface] = the SoundRegistry names of that pool, in order.
local SOUND_IDS: { [string]: SurfacePools } = {}

-- Registers `from` (asset ids) as `footstep_<set>_<surface>_<n>` and lists those names in `into`.
local function register(set: FootstepSet, setName: string, surface: string, from: { string }, into: { string })
	for index, assetId in from do
		local id = `footstep_{setName}_{surface}_{index}`
		if not SoundRegistry.has(id) then
			SoundRegistry.register(id, {
				assetId = assetId,
				group = "SFX",
				volume = set.volume,
				pitch = set.pitch,
				rollOffMaxDistance = set.rollOffMaxDistance,
			})
		end
		table.insert(into, id)
	end
end

for setName, set in SETS do
	assert(#set.surfaces.default > 0, `FootstepAssets: set "{setName}" has an empty default pool`)
	local from = set.surfaces
	local named: SurfacePools = { default = {}, carpet = {}, tile = {}, wood = {}, concrete = {} }
	register(set, setName, "default", from.default, named.default)
	register(set, setName, "carpet", from.carpet, named.carpet)
	register(set, setName, "tile", from.tile, named.tile)
	register(set, setName, "wood", from.wood, named.wood)
	register(set, setName, "concrete", from.concrete, named.concrete)
	SOUND_IDS[setName] = named
end

-- The body meeting the floor (FootstepLandingSystem): 3D on the root, every character this client sees.
local LAND = "footstepLand"
local BODY_FALL = "footstepBodyFall"
local BODY_SOUNDS: { [string]: SoundTypes.SoundDef } = {
	[LAND] = { assetId = "rbxassetid://98850900822779", group = "SFX", volume = 0.9, rollOffMaxDistance = 50 },
	[BODY_FALL] = { assetId = "rbxassetid://83428002679573", group = "SFX", volume = 1, rollOffMaxDistance = 70 },
}
for id, def in BODY_SOUNDS do
	if not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	SETS = table.freeze(SETS),
	SOUND_IDS = table.freeze(SOUND_IDS),
	LAND = LAND,
	BODY_FALL = BODY_FALL,
	-- The engine's jump clip (RbxCharacterSounds' Jumping, at its volume), kept until the in-house jump is remade.
	DEFAULT_JUMP = "rbxasset://sounds/action_jump.mp3",
	DEFAULT_JUMP_VOLUME = 0.65,
})
