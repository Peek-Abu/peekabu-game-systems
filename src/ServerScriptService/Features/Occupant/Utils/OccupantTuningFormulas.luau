--!strict
--[=[
	OccupantTuningFormulas: Harlow's speeds and hearing for the shift's pressure tier and the crew size
	(Cleanup Crew spec §4 "Pacing"): each tier adds TIER_PATROL_SPEED to his patrol speed and multiplies his
	hearing by TIER_HEARING (compounding: ×1.2, ×1.44); a solo crew gets SOLO_HEARING and SOLO_CHASE_SPEED.
	The tier is clamped to 0..TOP_TIER; a crew of 0 counts as solo. Pure.

	@class OccupantTuningFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

export type Tuning = {
	walkSpeed: number,
	runSpeed: number,
	-- Multiplies every noise's radius (NoiseRules).
	hearing: number,
}

local OccupantTuningFormulas = {}

function OccupantTuningFormulas.tuning(tier: number, crew: number): Tuning
	local level = math.clamp(math.floor(tier), 0, ShiftConstants.TOP_TIER)
	local solo = crew <= 1
	return {
		walkSpeed = OccupantConstants.PATROL_SPEED + level * ShiftConstants.TIER_PATROL_SPEED,
		runSpeed = OccupantConstants.CHASE_SPEED + (if solo then ShiftConstants.SOLO_CHASE_SPEED else 0),
		hearing = ShiftConstants.TIER_HEARING ^ level * (if solo then ShiftConstants.SOLO_HEARING else 1),
	}
end

return OccupantTuningFormulas
