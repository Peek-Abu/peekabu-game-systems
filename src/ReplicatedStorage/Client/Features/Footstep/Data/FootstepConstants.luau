--!strict
--[=[
	FootstepConstants: footsteps driven by the feet (FootstepPlantFormulas reads each foot's height; a step plays the
	frame it lands). Every number was checked live on Pippa and the Manager (see FootstepServiceClient). Static data
	(spec-exempt).

	@class FootstepConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootstepTypes = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepTypes)
local CrouchConstants = require(ReplicatedStorage.Shared.Features.Crouch.Data.CrouchConstants)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

type Surface = FootstepTypes.Surface

local MATERIAL_SURFACES: { [Enum.Material]: Surface } = {
	[Enum.Material.Carpet] = "carpet",
	[Enum.Material.Fabric] = "carpet",
	[Enum.Material.CeramicTiles] = "tile",
	[Enum.Material.Marble] = "tile",
	[Enum.Material.Granite] = "tile",
	[Enum.Material.Slate] = "tile",
	[Enum.Material.Wood] = "wood",
	[Enum.Material.WoodPlanks] = "wood",
	[Enum.Material.Concrete] = "concrete",
	[Enum.Material.Pavement] = "concrete",
	[Enum.Material.Asphalt] = "concrete",
	[Enum.Material.Brick] = "concrete",
	[Enum.Material.Cobblestone] = "concrete",
}

return table.freeze({
	-- The plant detector (FootstepPlantFormulas): each foot's last WINDOW seconds of height (longer than the slowest
	-- stride); armed above LIFT_FRACTION of its swing, planted back below PLANT_FRACTION, or where it bottoms out in the
	-- lower STAND_FRACTION (a stride that stands higher than the deepest one); no step for a swing under
	-- MIN_RANGE x the rig's HipHeight, nor for a foot held up longer than MAX_SWING seconds. Measured 2026-10-16 (foot
	-- centre swing): Pippa (HipHeight 0.375) walk 0.33 / sprint 0.35 studs; the Manager (3.6) a stiff 0.41 walk
	-- (0.11 x his HipHeight) and a 1.1 chase run; both idles 0. Foot-falls at a stride of 0.63 s (his walk at 10 st/s).
	WINDOW = 2,
	LIFT_FRACTION = 0.55,
	PLANT_FRACTION = 0.1,
	-- Measured 2026-10-17 at sprint: Pippa's run clip loops two strides, the second standing 0.08-0.11 studs above the
	-- first (24-35 % of her 0.32-stud swing), so every second contact never reached PLANT_FRACTION (a gallop, half the
	-- steps). Her walk's stance wobbles (under 20 %) come after its plant, while the foot is disarmed.
	STAND_FRACTION = 0.5,
	-- ... after coming down at least BOTTOM_DROP x the rig's HipHeight from its peak: her sprint's shallow strides drop
	-- 0.21-0.22 studs (0.56 x her 0.375), the shuffle as she sets off from idle 0.036 (0.1 x) while the other foot plants.
	BOTTOM_DROP = 0.3,
	MIN_RANGE = 0.04,
	MAX_SWING = 1.2,
	-- Moving on the ground: the root really crosses the floor at MOVING_SPEED studs/s or more (its own displacement,
	-- smoothed over SPEED_SMOOTHING seconds; a jump of TELEPORT studs in a frame is a teleport, not speed), a floor is
	-- under it (a ray GROUND_SLACK studs past the HipHeight), and it is alive and not seated.
	MOVING_SPEED = 1.5,
	SPEED_SMOOTHING = 0.15,
	TELEPORT = 6,
	GROUND_SLACK = 1.5,
	-- Characters farther than their set's roll-off plus CULL_MARGIN from the camera are not sampled.
	CULL_MARGIN = 10,
	-- A floor's attribute naming its surface (overrides its material).
	SURFACE_ATTRIBUTE = "FootstepSurface",
	-- A model's attribute naming its footstep set (overrides everything below).
	SET_ATTRIBUTE = "FootstepSet",
	-- A character's attribute: crouching (CrouchServiceServer sets it; the crouch gait).
	CROUCH_ATTRIBUTE = CrouchConstants.CROUCHING_ATTRIBUTE,
	-- The set for a tagged non-player character.
	TAG_SETS = table.freeze({ [OccupantConstants.TAG] = "harlow" }),
	-- The set for a player character without an employee set of its own.
	DEFAULT_SET = "default",
	MATERIAL_SURFACES = table.freeze(MATERIAL_SURFACES),
	-- How many recent steps getState keeps (the live sync check reads them).
	RECENT = 64,
	-- Idle one-shot Sounds made on each foot (and a player's root, for the jump and land) as its character is
	-- followed: a walk reuses one a foot, a sprint's overlapping steps two, so steady play never creates a Sound
	-- (SoundServiceClient:prewarm; a third overlap still grows the pool, up to its idle cap).
	PREWARM_PER_ANCHOR = 2,
	-- Roblox's own character sounds (RbxCharacterSounds' Sounds in each character's root), all muted on every
	-- followed character: the game plays its own steps, jump, land and body-fall, and the caught "FIRED" replaces the
	-- "oof". Measured 2026-10-17: an empty RbxCharacterSounds override no longer holds (SoundService
	-- CharacterSoundsUseNewApi = Default puts the engine's script back in Play), so they are muted instead.
	DEFAULT_SOUNDS = table.freeze({
		"Running",
		"Died",
		"Jumping",
		"Landing",
		"FreeFalling",
		"GettingUp",
		"Climbing",
		"Swimming",
		"Splash",
	}),
	-- The body meeting the floor (FootstepLandingSystem, FootstepLandingFormulas), from the root's vertical speed: a
	-- land is an impact from LAND_SPEED studs/s down (a jump lands at ~50, a step off a kerb under it); a jump is a
	-- take-off to JUMP_SPEED up (a full jump leaves at ~50); one land per LAND_GAP seconds. A dead body's first impact
	-- from BODY_FALL_SPEED, within BODY_FALL_WINDOW seconds of the death (the catch's throw lands in ~1 s), is the
	-- body-fall, once.
	LAND_SPEED = 18,
	JUMP_SPEED = 25,
	LAND_GAP = 0.25,
	BODY_FALL_SPEED = 8,
	BODY_FALL_WINDOW = 4,
})
