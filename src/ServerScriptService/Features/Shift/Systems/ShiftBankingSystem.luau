--!strict
--[=[
	ShiftBankingSystem: the shift's banking handler for Cargo (Cleanup Crew spec §4 "Banking", §6.4). Everything
	banked adds to Round's `clearance` counter, the quota, at x1; valuables (times the current multiplier: ×1.5 in
	overtime) also add to `bonus`, the pay (ShiftQuotaFormulas.credit, docs/superpowers/specs/
	2026-10-15-cleanup-crew-loot-loop-design.md §3.6); and the banker's run goes in the roster. Every refusal is decided before the first counter write; once a counter moved it
	returns true whatever else fails, or Cargo would release the claim and the same items would bank twice. It
	also returns the bonus it credited (after the multiplier), which Cargo's `Banked` floater shows (M3: the
	"Loaded: …" toast is gone).

	Moved out of ShiftServiceServer in M2 (the service was at the 400-line cap). Spec-exempt shell (Round); the
	multiplier and the quota are the specced ShiftPhaseRules. Each accepted Load is reported to ShiftAnalyticsSystem
	(cargo_banked, optional-salvage attempts).

	@class ShiftBankingSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftRosterTracker = require(ServerScriptService.Features.Shift.State.ShiftRosterTracker)
local ShiftQuotaFormulas = require(ServerScriptService.Features.Shift.Utils.ShiftQuotaFormulas)
local ShiftAnalyticsSystem = require(ServerScriptService.Features.Shift.Systems.ShiftAnalyticsSystem)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)

export type Deps = {
	roster: ShiftRosterTracker.ShiftRosterTracker,
	-- False refuses every deposit (no shift running, or the run is ending).
	isOpen: () -> boolean,
	-- Current authoritative crew eligibility, shared by explicit and automatic cargo loads.
	canBank: (Player) -> boolean,
	-- What salvage is multiplied by right now (ShiftPhaseRules.salvageMultiplier).
	multiplier: () -> number,
	-- After the counters moved: re-check the quota and republish (the service's state machine).
	afterBank: () -> (),
}

local log = Logger.new("ShiftBankingSystem")

local function guarded(label: string, step: () -> ()): boolean
	return xpcall(step, function(err: unknown): unknown
		log:error(`{label} failed: {err}`)
		return err
	end)
end

local ShiftBankingSystem = {}

function ShiftBankingSystem.new(deps: Deps): CargoTypes.BankHandler
	return function(player: Player, deposit: CargoTypes.Deposit): (boolean, number?)
		if not deps.isOpen() or not deps.canBank(player) then
			return false, nil
		end
		local multiplier = deps.multiplier()
		local credit = ShiftQuotaFormulas.credit(deposit, multiplier)
		local cleared, bonus = credit.cleared, credit.earned
		local salvage = 0
		for _, item in deposit.items do
			if item.category == "salvage" then
				salvage += 1
			end
		end
		local wrote = false
		local ok = guarded("banking", function()
			if cleared > 0 then
				RoundServiceServer:addTeam(ShiftConstants.CLEARANCE, cleared)
				wrote = true
			end
			if bonus > 0 then
				RoundServiceServer:addTeam(ShiftConstants.BONUS, bonus)
				wrote = true
			end
			RoundServiceServer:addScore(player, ShiftConstants.SCORE_BANKED, deposit.clearance + bonus)
			wrote = true
			if salvage > 0 then
				RoundServiceServer:addScore(player, ShiftConstants.SCORE_SALVAGE, salvage)
			end
			deps.roster:record(
				player.UserId,
				player.DisplayName,
				{ banked = deposit.clearance + bonus, salvage = salvage }
			)
		end)
		if not ok and not wrote then
			return false, nil
		end
		-- Analytics (M5): cargo_banked per item, at the quota tag before this Load; closes the loader's attempts.
		guarded("banking analytics", function()
			ShiftAnalyticsSystem.banked(player, deposit, multiplier)
		end)
		-- The quota stamp and the publish, in their own guard: a throwing follow-up never un-banks the deposit.
		guarded("banking follow-up", deps.afterBank)
		return true, bonus
	end
end

return ShiftBankingSystem
