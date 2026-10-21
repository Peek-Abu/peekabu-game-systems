--!strict
--[=[
	ShiftQuotaFormulas: the shift's contract and its pay (docs/superpowers/specs/
	2026-10-16-cleanup-crew-gloom-gleam-economy-design.md: "Vacuum it = the job. Bank it = the pay."). The contract
	("quota" in code) is Gloom to remove, scaled with the crew (ShiftConstants.QUOTA_BY_CREW): a cleared pile counts
	`pileGloom` the instant it is vacuumed, a valuable only the grime cleaned off it (Cargo's grimeRemoved). Banking adds
	no Gloom: a Load pays its valuables in Credits (`pay`, Round's `bonus` counter); only the overtime batch's loot
	(`overtime` on its deposit line) pays x1.5, whenever it is banked. At clock-out every Gloom removed pays CREDITS_PER_GLOOM Credits, never multiplied
	(`breakdown`). Shared: the
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
	-- The Credits each pays (CREDITS_PER_GLOOM per Gloom).
	dustCredits: number,
	grimeCredits: number,
	-- The Credits for banked valuables (overtime's x1.5 included).
	valuables: number,
	-- Everything earned.
	credits: number,
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
	The Credits `deposit` pays when banked: its valuables, with each overtime item (`overtime = true`, the overtime
	batch) paying OVERTIME_SALVAGE_MULTIPLIER times its value and every other item x1, rounded once on the total (so
	10 + 10 with one overtime item is 25). Its trash pays nothing, and no Load adds Gloom.
]=]
function ShiftQuotaFormulas.pay(deposit: CargoTypes.Deposit): number
	local extra = 0
	for _, item in deposit.items do
		if item.overtime == true and item.category ~= "trash" then
			extra += math.max(0, item.value) * (ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER - 1)
		end
	end
	return whole(deposit.bonus + extra)
end

--[=[
	The Gloom one cleared pile removes toward the contract.
]=]
function ShiftQuotaFormulas.pileGloom(): number
	return VacuumConstants.PILE_GLOOM
end

--[=[
	The shift's pay split for the review: `gloom` removed (Round's clearance), `dust` of it from piles (the rest from
	cleaning valuables), and `valuables` Credits banked (Round's bonus).
]=]
function ShiftQuotaFormulas.breakdown(gloom: number, dust: number, valuables: number): Breakdown
	local total = whole(gloom)
	local fromDust = math.min(whole(dust), total)
	local fromGrime = total - fromDust
	local banked = whole(valuables)
	local rate = ShiftConstants.CREDITS_PER_GLOOM
	return {
		dust = fromDust,
		grime = fromGrime,
		gloom = total,
		dustCredits = fromDust * rate,
		grimeCredits = fromGrime * rate,
		valuables = banked,
		credits = total * rate + banked,
	}
end

--[=[
	The Gloom each crew member keeps (saved to their account) when the crew removed `cleared`:
	floor(cleared x SAVED_GLOOM_PER_CLEARED). The pay system pays it; the review shows it.
]=]
function ShiftQuotaFormulas.savedGloom(cleared: number): number
	return math.floor(math.max(0, cleared) * ShiftConstants.SAVED_GLOOM_PER_CLEARED)
end

return ShiftQuotaFormulas
