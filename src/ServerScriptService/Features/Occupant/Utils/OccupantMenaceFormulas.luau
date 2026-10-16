--!strict
--[=[
	OccupantMenaceFormulas: the director's pacing maths (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-
	design.md §4). The menace gauge (0..MENACE_MAX) rises while he chases, while he stares at or sits over a hider, and
	while someone is near him; it falls otherwise; a sighting and a catch add a lump. Full = a breather. How often he is
	steered toward the crew and how long a breather lasts follow the crew size, the pressure tier and overtime. Pure.

	@class OccupantMenaceFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)

export type Activity = {
	chasing: boolean,
	engaged: boolean,
	near: boolean,
}

local OccupantMenaceFormulas = {}

--[=[
	`roll` (0..1, clamped) mapped into `range`.
]=]
function OccupantMenaceFormulas.within(range: OccupantConstants.Range, roll: number): number
	return range.min + (range.max - range.min) * math.clamp(roll, 0, 1)
end

--[=[
	The gauge after `dt` seconds of `activity`.
]=]
function OccupantMenaceFormulas.step(menace: number, dt: number, activity: Activity): number
	local rate = 0
	if activity.chasing then
		rate += OccupantConstants.MENACE_CHASE
	end
	if activity.engaged then
		rate += OccupantConstants.MENACE_STARE
	end
	if activity.near then
		rate += OccupantConstants.MENACE_NEAR
	end
	if rate == 0 then
		rate = -OccupantConstants.MENACE_DECAY
	end
	return math.clamp(menace + rate * math.max(dt, 0), 0, OccupantConstants.MENACE_MAX)
end

function OccupantMenaceFormulas.bump(menace: number, amount: number): number
	return math.clamp(menace + amount, 0, OccupantConstants.MENACE_MAX)
end

function OccupantMenaceFormulas.full(menace: number): boolean
	return menace >= OccupantConstants.MENACE_MAX
end

--[=[
	Seconds between two steers toward the crew.
]=]
function OccupantMenaceFormulas.steerInterval(pacing: OccupantTypes.Pacing): number
	if pacing.overtime then
		return if pacing.solo then OccupantConstants.STEER_OVERTIME_SOLO else OccupantConstants.STEER_OVERTIME_CREW
	end
	local base = if pacing.solo then OccupantConstants.STEER_SOLO else OccupantConstants.STEER_CREW
	return math.max(base - math.max(pacing.tier, 0) * OccupantConstants.STEER_PER_TIER, 4)
end

--[=[
	A breather's length for `roll`.
]=]
function OccupantMenaceFormulas.breather(pacing: OccupantTypes.Pacing, roll: number): number
	if pacing.overtime then
		return OccupantMenaceFormulas.within(OccupantConstants.BREATHER_OVERTIME, roll)
	end
	local range = if pacing.solo then OccupantConstants.BREATHER_SOLO else OccupantConstants.BREATHER_CREW
	local seconds = OccupantMenaceFormulas.within(range, roll)
	return math.max(seconds - math.max(pacing.tier, 0) * OccupantConstants.BREATHER_PER_TIER, 5)
end

return OccupantMenaceFormulas
