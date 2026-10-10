--!strict
--[=[
	ShiftBankingSystem: the shift's banking handler for Cargo (Cleanup Crew spec §4 "Banking", §6.4). Trash adds
	to Round's `clearance` counter, salvage (times the current multiplier: ×1.5 in overtime) to `bonus`, and the
	banker's run in the roster. Every refusal is decided before the first counter write; once a counter moved it
	returns true whatever else fails, or Cargo would release the claim and the same items would bank twice.

	Moved out of ShiftServiceServer in M2 (the service was at the 400-line cap). Spec-exempt shell (Round,
	Toast); the multiplier and the quota are the specced ShiftPhaseRules.

	@class ShiftBankingSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftRosterTracker = require(ServerScriptService.Features.Shift.State.ShiftRosterTracker)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

export type Deps = {
	roster: ShiftRosterTracker.ShiftRosterTracker,
	-- False refuses every deposit (no shift running, or the run is ending).
	isOpen: () -> boolean,
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
	return function(player: Player, deposit: CargoTypes.Deposit): boolean
		if not deps.isOpen() then
			return false
		end
		local multiplier = deps.multiplier()
		local bonus = math.floor(deposit.bonus * multiplier + 0.5)
		local salvage = 0
		for _, item in deposit.items do
			if item.category == "salvage" then
				salvage += 1
			end
		end
		local wrote = false
		local ok = guarded("banking", function()
			if deposit.clearance > 0 then
				RoundServiceServer:addTeam(ShiftConstants.CLEARANCE, deposit.clearance)
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
			return false
		end
		-- The quota stamp and the publish come before the toast, each in its own guard: a throwing toast can
		-- never skip them.
		guarded("banking follow-up", deps.afterBank)
		guarded("banking toast", function()
			local overtime = if multiplier > 1 then ` (overtime x{multiplier})` else ""
			local text = `Loaded: +{deposit.clearance} clearance, +{bonus} bonus{overtime}`
			ToastServiceServer:send(player, { text = text, duration = 2 })
		end)
		return true
	end
end

return ShiftBankingSystem
