--!strict
--[=[
	OccupantTuningFormulas: Harlow's speeds and hearing for the shift's pressure tier and the crew size
	(Cleanup Crew spec §4 "Pacing"): each tier adds TIER_PATROL_SPEED to his patrol speed and multiplies his
	hearing by TIER_HEARING (compounding: ×1.2, ×1.44); a solo crew gets SOLO_HEARING and SOLO_CHASE_SPEED. A
	training run scales his speeds by TRAINING_SPEED and his hearing by TRAINING_HEARING (a little easier).
	The tier is clamped to 0..TOP_TIER; a crew of 0 counts as solo. The base speeds are the monster kind's
	(OccupantKindRegistry: Harlow patrol 10 / chase 20, Bramble 10 / 21); no kind is Harlow. Pure.

	@class OccupantTuningFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

export type Tuning = {
	walkSpeed: number,
	runSpeed: number,
	-- Multiplies every noise's radius (NoiseRules).
	hearing: number,
}

local OccupantTuningFormulas = {}

function OccupantTuningFormulas.tuning(
	tier: number,
	crew: number,
	training: boolean?,
	kind: OccupantKindRegistry.Kind?
): Tuning
	local patrol = if kind ~= nil then kind.patrolSpeed else OccupantConstants.PATROL_SPEED
	local chase = if kind ~= nil then kind.chaseSpeed else OccupantConstants.CHASE_SPEED
	local level = math.clamp(math.floor(tier), 0, ShiftConstants.TOP_TIER)
	local solo = crew <= 1
	local speed = if training then ShiftConstants.TRAINING_SPEED else 1
	local hearing = if training then ShiftConstants.TRAINING_HEARING else 1
	return {
		walkSpeed = (patrol + level * ShiftConstants.TIER_PATROL_SPEED) * speed,
		runSpeed = (chase + level * ShiftConstants.TIER_CHASE_SPEED + (if solo
			then ShiftConstants.SOLO_CHASE_SPEED
			else 0)) * speed,
		hearing = ShiftConstants.TIER_HEARING ^ level * (if solo then ShiftConstants.SOLO_HEARING else 1) * hearing,
	}
end

return OccupantTuningFormulas
