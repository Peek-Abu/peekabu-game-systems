--!strict
--[=[
	ShiftWiringSystem: the shift service's start-up wiring, moved out of ShiftServiceServer: the work-order progress, the
	contract, banking, analytics, review, pay, crew status, time clock, entrances, overtime and clock-out subsystems
	started with the service, the Round phase and tick connections, and the results vote. Each stopper is appended to
	the service's `stoppers` list in the order it was made, so the service's `stop` undoes them as before. What the
	service owns (its state, the run's record, the systems it built) is handed in as Deps; spec-exempt shell.

	@class ShiftWiringSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftEvents = require(ReplicatedStorage.Shared.Features.Shift.Net.ShiftEvents)
local ShiftServer = ServerScriptService.Features.Shift
local ShiftRosterTracker = require(ShiftServer.State.ShiftRosterTracker)
local ShiftRunTracker = require(ShiftServer.State.ShiftRunTracker)
local ShiftAnalyticsSystem = require(ShiftServer.Systems.ShiftAnalyticsSystem)
local ShiftAnalyticsWatchSystem = require(ShiftServer.Systems.ShiftAnalyticsWatchSystem)
local ShiftBankingSystem = require(ShiftServer.Systems.ShiftBankingSystem)
local ShiftClockOutSystem = require(ShiftServer.Systems.ShiftClockOutSystem)
local ShiftCrewStatusSystem = require(ShiftServer.Systems.ShiftCrewStatusSystem)
local ShiftGloomSystem = require(ShiftServer.Systems.ShiftGloomSystem)
local ShiftLivesSystem = require(ShiftServer.Systems.ShiftLivesSystem)
local ShiftOvertimeSystem = require(ShiftServer.Systems.ShiftOvertimeSystem)
local ShiftPaySystem = require(ShiftServer.Systems.ShiftPaySystem)
local ShiftReviewSystem = require(ShiftServer.Systems.ShiftReviewSystem)
local ShiftTimeClockSystem = require(ShiftServer.Systems.ShiftTimeClockSystem)
local ShiftTripSystem = require(ShiftServer.Systems.ShiftTripSystem)
local ShiftVoteSystem = require(ShiftServer.Systems.ShiftVoteSystem)
local ShiftWorkOrderSystem = require(ShiftServer.Systems.ShiftWorkOrderSystem)
local AnalyticsTypes = require(ServerScriptService.Features.Analytics.Data.AnalyticsTypes)
local AnalyticsServiceServer = require(ServerScriptService.Features.Analytics.AnalyticsServiceServer)
local CurrencyServiceServer = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local OfficeEntranceSystem = require(ServerScriptService.Features.Office.Systems.OfficeEntranceSystem)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local WorkOrderServiceServer = require(ServerScriptService.Features.WorkOrder.WorkOrderServiceServer)

export type Deps = {
	-- Every state change (a copy), and every counted catch (the service's signals).
	changed: SignalTyped.Signal<ShiftTypes.ShiftState>,
	caught: SignalTyped.Signal<Player, number, number>,
	-- Cargo's banking handler's deps; the contract shares its gate and its re-check.
	banking: ShiftBankingSystem.Deps,
	run: ShiftRunTracker.ShiftRunTracker,
	roster: ShiftRosterTracker.ShiftRosterTracker,
	trip: ShiftTripSystem.ShiftTripSystem,
	isRunning: () -> boolean,
	timeClock: ShiftTimeClockSystem.ShiftTimeClockSystem,
	entrances: OfficeEntranceSystem.OfficeEntranceSystem,
	overtime: ShiftOvertimeSystem.ShiftOvertimeSystem,
	clockOuts: ShiftClockOutSystem.ShiftClockOutSystem,
	voting: ShiftVoteSystem.ShiftVoteSystem,
	onRoundPhase: (roundState: RoundTypes.RoundState) -> (),
	step: () -> (),
}

local ShiftWiringSystem = {}

--[=[
	The office's entrances (outside door <-> inside exit): only the running shift's crew still working (not clocked out),
	up and playing, goes through.
]=]
function ShiftWiringSystem.entrances(
	isRunning: () -> boolean,
	working: (player: Player) -> boolean,
	lives: ShiftLivesSystem.ShiftLivesSystem
): OfficeEntranceSystem.OfficeEntranceSystem
	return OfficeEntranceSystem.new({
		inCrew = function(player: Player): boolean
			return isRunning() and working(player)
		end,
		alive = function(player: Player): boolean
			return not DeathServiceServer:isDead(player)
				and not DeathServiceServer:isDown(player)
				and not lives:isKnockedOut(player)
		end,
		entrance = function(id)
			return OfficeServiceServer:entrance(id)
		end,
		fade = function(player: Player, covered: boolean, seconds: number)
			ShiftEvents.packets.EntranceFade.sendTo({ covered = covered, seconds = seconds }, player)
		end,
	})
end

--[=[
	Starts the work orders' progress (pile clears, the crew's work, the review's roster), appending its stopper.
]=]
function ShiftWiringSystem.workOrders(deps: Deps, stoppers: { () -> () })
	local run = deps.run
	table.insert(
		stoppers,
		ShiftWorkOrderSystem.start({
			piles = VacuumServiceServer.pileCleared,
			loaded = ShiftAnalyticsSystem.loaded,
			changed = deps.changed,
			eligible = deps.banking.canBank,
			crew = function()
				return ShiftAnalyticsSystem.crew()
			end,
			worked = function()
				return if run.results ~= nil then RankFormulas.workedIds(run.results) else {}
			end,
			training = function()
				return run.training
			end,
		}, function(player, kind, amount)
			WorkOrderServiceServer:record(player, kind, amount)
		end)
	)
end

--[=[
	The visit analytics (AnalyticsServiceServer): where the crew is as the phase changes (a run, its results screen, or
	training), and each worked shift once its results exist (RankFormulas.workedIds, the rule pay and rank use; never a
	training run). Returns the stopper.
]=]
local function reportVisits(deps: Deps): () -> ()
	local run = deps.run
	local lastPhase: string? = nil
	local counted: { [number]: boolean } = {}
	local connection = deps.changed:Connect(function(state: ShiftTypes.ShiftState)
		if state.phase ~= lastPhase then
			lastPhase = state.phase
			local place: AnalyticsTypes.Place? = nil
			if run.training then
				place = "training"
			elseif state.phase == "running" then
				place = "shift"
			elseif state.phase == "results" then
				place = "results"
			end
			if place ~= nil then
				for _, player in ShiftAnalyticsSystem.crew() do
					AnalyticsServiceServer:place(player, place)
				end
			end
		end
		local results = run.results
		if state.phase ~= "results" or run.training or results == nil or counted[state.shift] then
			return
		end
		counted[state.shift] = true
		for _, userId in RankFormulas.workedIds(results) do
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				AnalyticsServiceServer:shiftWorked(player)
			end
		end
	end)
	return function()
		connection:Disconnect()
	end
end

--[=[
	Takes over Cargo's banking, starts the contract, analytics, review, pay, crew status, time clock, entrances, overtime
	and clock-out subsystems, follows Round's phases, runs the clock's tick and opens the results vote, appending every
	stopper.
]=]
function ShiftWiringSystem.start(deps: Deps, stoppers: { () -> () })
	local run = deps.run
	local trip = deps.trip
	CargoServiceServer:onBanked(ShiftBankingSystem.new(deps.banking))
	-- The contract's progress: every cleared pile and cleaning step adds its Gloom live (same gate and re-check).
	table.insert(stoppers, ShiftGloomSystem.start(deps.banking.isOpen, deps.banking.afterBank))
	table.insert(stoppers, ShiftAnalyticsWatchSystem.start(deps.changed, deps.caught, trip))
	table.insert(stoppers, reportVisits(deps))
	table.insert(stoppers, ShiftReviewSystem.start(deps.roster, deps.isRunning))
	-- Pay: every crew member still here gets the full Credits and saved Gloom when the review opens.
	table.insert(
		stoppers,
		ShiftPaySystem.start({
			changed = deps.changed,
			results = function()
				return run.results
			end,
			present = function()
				return trip:crewIds()
			end,
		}, function(userId: number, amounts)
			return CurrencyServiceServer:grant(userId, amounts, "shiftPay")
		end)
	)
	table.insert(stoppers, ShiftCrewStatusSystem.start(trip, deps.isRunning))
	table.insert(stoppers, deps.timeClock.start())
	table.insert(stoppers, deps.entrances.start())
	table.insert(stoppers, deps.overtime.start())
	table.insert(stoppers, deps.clockOuts.start())

	local phases = RoundServiceServer.phaseChanged:Connect(deps.onRoundPhase)
	local elapsed = 0
	local ticking = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed >= ShiftConstants.TICK_INTERVAL then
			elapsed = 0
			deps.step()
		end
	end)
	table.insert(stoppers, function()
		phases:Disconnect()
		ticking:Disconnect()
	end)
	table.insert(stoppers, deps.voting:start())
end

return ShiftWiringSystem
