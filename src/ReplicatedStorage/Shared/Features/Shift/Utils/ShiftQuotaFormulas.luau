--!strict
--[=[
	ShiftQuotaFormulas: the shift's quota and what a Load is worth to it (docs/superpowers/specs/
	2026-10-15-cleanup-crew-loot-loop-design.md §3.6). The quota scales with the crew (ShiftConstants.QUOTA_BY_CREW);
	everything banked counts toward it at x1 (trash plus valuables at their current, grime-scaled value), while the
	pay (Recovery pay, the `bonus` counter) is valuables only, times the salvage multiplier (x1.5 in overtime). Shared:
	the run sets its quota with it and the depot posts the quota for a truck's crew. Pure.

	@class ShiftQuotaFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

export type Credit = {
	-- Toward the quota (Round's `clearance` counter).
	cleared: number,
	-- Recovery pay (Round's `bonus` counter).
	earned: number,
}

local ShiftQuotaFormulas = {}

--[=[
	The quota for a crew of `crew` (clamped to QUOTA_BY_CREW's sizes).
]=]
function ShiftQuotaFormulas.quota(crew: number): number
	local byCrew = ShiftConstants.QUOTA_BY_CREW
	return byCrew[math.clamp(math.floor(crew), 1, #byCrew)]
end

--[=[
	What `deposit` adds: cleared = its trash plus its valuables at x1; earned = its valuables x `multiplier`, rounded.
]=]
function ShiftQuotaFormulas.credit(deposit: CargoTypes.Deposit, multiplier: number): Credit
	return {
		cleared = deposit.clearance + deposit.bonus,
		earned = math.floor(deposit.bonus * multiplier + 0.5),
	}
end

return ShiftQuotaFormulas
