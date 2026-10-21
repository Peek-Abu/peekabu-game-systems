--!strict
--[=[
	ShiftGloomSystem: the contract's progress, live (docs/superpowers/specs/
	2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §3.1-3.2: "Vacuum it = the job"). While a shift runs:

	- a cleared pile (Vacuum's `pileCleared`) removes ShiftQuotaFormulas.pileGloom() Gloom: added to Round's `clearance`
	  counter (the contract) and its `dust` counter (the review's split), the instant it is cleared;
	- a cleaning step on a valuable (Cargo's `grimeRemoved`, the Gloom that step took off it) adds to `clearance` only.

	Banking adds no Gloom (ShiftBankingSystem pays Credits). After each credit `afterCredit` runs: the service re-checks
	the contract (CONTRACT MET, clock-out unlocks) and republishes. The counters are written through `addTeam`, so the
	spec drives it without Round; `ShiftGloomSystem.start` is the service's one-line wiring onto Round, Vacuum and Cargo.

	@class ShiftGloomSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftQuotaFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftQuotaFormulas)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

export type Deps = {
	-- False credits nothing (no shift running, or the run is ending).
	isOpen: () -> boolean,
	-- Adds to one of Round's team counters (RoundServiceServer:addTeam).
	addTeam: (counter: string, amount: number) -> (),
	-- After a credit: re-check the contract and republish.
	afterCredit: () -> (),
}

export type ShiftGloomSystem = {
	pile: (self: ShiftGloomSystem) -> boolean,
	grime: (self: ShiftGloomSystem, gloom: number) -> boolean,
	start: (
		self: ShiftGloomSystem,
		piles: SignalTyped.Signal<BasePart, { Player }>,
		grime: SignalTyped.Signal<Instance, number>
	) -> () -> (),
}

local ShiftGloomSystem = {}

function ShiftGloomSystem.new(deps: Deps): ShiftGloomSystem
	local system: ShiftGloomSystem = {
		--[=[
			One pile cleared: its Gloom to the contract and the dust. False when no shift takes it.
		]=]
		pile = function(_self)
			if not deps.isOpen() then
				return false
			end
			local gloom = ShiftQuotaFormulas.pileGloom()
			deps.addTeam(ShiftConstants.CLEARANCE, gloom)
			deps.addTeam(ShiftConstants.DUST, gloom)
			deps.afterCredit()
			return true
		end,

		--[=[
			`gloom` cleaned off a valuable: to the contract. False when no shift takes it or there is nothing to add.
		]=]
		grime = function(_self, gloom)
			if not deps.isOpen() or gloom ~= gloom or gloom <= 0 then
				return false
			end
			deps.addTeam(ShiftConstants.CLEARANCE, gloom)
			deps.afterCredit()
			return true
		end,

		--[=[
			Follows the vacuum's `piles` and the cargo's `grime` signals. Returns the stopper.
		]=]
		start = function(self, piles, grime)
			local cleared = piles:Connect(function()
				self:pile()
			end)
			local cleaned = grime:Connect(function(_item: Instance, gloom: number)
				self:grime(gloom)
			end)
			return function()
				cleared:Disconnect()
				cleaned:Disconnect()
			end
		end,
	}
	return system
end

--[=[
	The live wiring: credits Round's counters from Vacuum's `pileCleared` and Cargo's `grimeRemoved` while `isOpen`, and
	runs `afterCredit` after each credit. Returns the stopper.
]=]
function ShiftGloomSystem.start(isOpen: () -> boolean, afterCredit: () -> ()): () -> ()
	local system = ShiftGloomSystem.new({
		isOpen = isOpen,
		addTeam = function(counter: string, amount: number)
			RoundServiceServer:addTeam(counter, amount)
		end,
		afterCredit = afterCredit,
	})
	return system:start(VacuumServiceServer.pileCleared, CargoServiceServer.grimeRemoved)
end

return ShiftGloomSystem
