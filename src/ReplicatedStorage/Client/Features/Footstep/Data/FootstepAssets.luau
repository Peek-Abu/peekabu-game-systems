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

	⚠ PLACEHOLDER: every pool below is the Manager's old single step (rbxassetid://119846856442242), Pippa's pitched up
	and quieter, until the in-house sets are uploaded.

	Registers each id in SoundRegistry at load (as `footstep_<set>_<surface>_<n>`, guarded) and exposes those names as
	SOUND_IDS[set][surface]. Static data + registration (spec-exempt).

	@class FootstepAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootstepTypes = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepTypes)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)

type FootstepSet = FootstepTypes.FootstepSet
type SurfacePools = FootstepTypes.SurfacePools

-- PLACEHOLDER: the Manager's old step, the only footfall uploaded so far.
local PLACEHOLDER_STEP = "rbxassetid://119846856442242"

local SETS: { [string]: FootstepSet } = {
	-- Pippa: a small bunny in work shoes. PLACEHOLDER pools.
	pippa = {
		volume = 0.35,
		pitch = { min = 1.3, max = 1.5 },
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
			default = { PLACEHOLDER_STEP },
			carpet = {},
			tile = {},
			wood = {},
			concrete = {},
		},
	},
	-- Mr. Harlow: heavy, uneven, heard through walls out to the far warning stage (OccupantConstants STAGE_FAR). His
	-- walk is planted at 10 st/s and his chase run at 20 (OccupantAssets.ANIMATIONS); a step lands up to 1.6x louder as
	-- he speeds up (2026-10-16: the crew near a chase hears him running). PLACEHOLDER pools.
	harlow = {
		volume = 0.7,
		pitch = { min = 0.9, max = 1.05 },
		rollOffMaxDistance = 85,
		walkSpeed = 10,
		runSpeed = 20,
		gaits = {
			walk = { volume = 1, pitch = 1 },
			sprint = { volume = 1.6, pitch = 1 },
			crouch = { volume = 0.5, pitch = 1 },
			hidden = { volume = 0, pitch = 1 },
		},
		surfaces = {
			default = { PLACEHOLDER_STEP },
			carpet = {},
			tile = {},
			wood = {},
			concrete = {},
		},
	},
	-- Any other player character. PLACEHOLDER pools.
	default = {
		volume = 0.35,
		pitch = { min = 1.1, max = 1.25 },
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
			default = { PLACEHOLDER_STEP },
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

return table.freeze({
	SETS = table.freeze(SETS),
	SOUND_IDS = table.freeze(SOUND_IDS),
})
