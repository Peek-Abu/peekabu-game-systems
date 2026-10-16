--!strict
--[=[
	ShiftQuotaFormulas: the shift's contract and its pay (docs/superpowers/specs/
	2026-10-16-cleanup-crew-gloom-gleam-economy-design.md: "Vacuum it = the job. Bank it = the pay."). The contract
	("quota" in code) is Gloom to remove, scaled with the crew (ShiftConstants.QUOTA_BY_CREW): a cleared pile counts
	`pileGloom` the instant it is vacuumed, a valuable only the grime cleaned off it (Cargo's grimeRemoved). Banking adds
	no Gloom: a Load pays its valuables in Gleam (`pay`, Round's `bonus` counter), times the salvage multiplier (x1.5 in
	overtime). At clock-out every Gloom removed pays GLEAM_PER_GLOOM Gleam, never multiplied (`breakdown`). Shared: the
	run sets its contract with it, the depot posts the contract for a truck's crew, and the review splits the pay. Pure.

	@class ShiftQuotaFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

export type Breakdown = {
	-- Gloom removed from piles, from cleaning valuables, and both.
	dust: number,
	grime: number,
	gloom: number,
	-- The Gleam each pays (GLEAM_PER_GLOOM per Gloom).
	dustGleam: number,
	grimeGleam: number,
	-- The Gleam for banked valuables (overtime's x1.5 included).
	valuables: number,
	-- Everything earned.
	gleam: number,
}

local function whole(value: number): number
	return math.max(0, math.floor(value + 0.5))
end

local ShiftQuotaFormulas = {}

--[=[
	The contract (Gloom) for a crew of `crew` (clamped to QUOTA_BY_CREW's sizes).
]=]
function ShiftQuotaFormulas.quota(crew: number): number
	local byCrew = ShiftConstants.QUOTA_BY_CREW
	return byCrew[math.clamp(math.floor(crew), 1, #byCrew)]
end

--[=[
	The Gleam `deposit` pays when banked: its valuables x `multiplier`, rounded. Its trash pays nothing, and no Load
	adds Gloom.
]=]
function ShiftQuotaFormulas.pay(deposit: CargoTypes.Deposit, multiplier: number): number
	return whole(deposit.bonus * multiplier)
end

--[=[
	The Gloom one cleared pile removes toward the contract.
]=]
function ShiftQuotaFormulas.pileGloom(): number
	return VacuumConstants.PILE_GLOOM
end

--[=[
	The shift's pay split for the review: `gloom` removed (Round's clearance), `dust` of it from piles (the rest from
	cleaning valuables), and `valuables` Gleam banked (Round's bonus).
]=]
function ShiftQuotaFormulas.breakdown(gloom: number, dust: number, valuables: number): Breakdown
	local total = whole(gloom)
	local fromDust = math.min(whole(dust), total)
	local fromGrime = total - fromDust
	local banked = whole(valuables)
	local rate = ShiftConstants.GLEAM_PER_GLOOM
	return {
		dust = fromDust,
		grime = fromGrime,
		gloom = total,
		dustGleam = fromDust * rate,
		grimeGleam = fromGrime * rate,
		valuables = banked,
		gleam = total * rate + banked,
	}
end

return ShiftQuotaFormulas
