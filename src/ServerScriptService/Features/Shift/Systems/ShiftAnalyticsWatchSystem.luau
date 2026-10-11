--!strict
--[=[
	ShiftAnalyticsWatchSystem: turns what the features already announce into Cleanup Crew's analytics events (spec
	§6.6), so no feature carries analytics code and no service near the line cap grows. Every event goes out through
	ShiftAnalyticsSystem.emit; banking's events are ShiftBankingSystem's (ShiftAnalyticsSystem.banked).

	- Shift `changed`: contract_started when a run starts (target = how the variant was chosen), replay_started when
	  that run is not the server's first (an Another shift), quota_met when the quota is met;
	- Round `runEnded`: open optional-salvage attempts close as "unbanked", then shift_ended for each crew member (value
	  = their attempts this shift, target = their cleaning bucket, outcome = how the run ended : whether the quota was
	  met). The crew is the trip's (`start`'s `trip`): the signal is deferred and Round has already cleared its
	  participants by then; the outcome is the signal's argument and the quota comes from the last running copy, so
	  neither depends on Round's cleanup.

	Spec-exempt shell (signals); the decisions are the specced ShiftAnalyticsUtils, ShiftAnalyticsTracker and
	ShiftSalvageTracker.

	@class ShiftAnalyticsWatchSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ShiftAnalyticsSystem = require(ServerScriptService.Features.Shift.Systems.ShiftAnalyticsSystem)
local ShiftAnalyticsUtils = require(ServerScriptService.Features.Shift.Utils.ShiftAnalyticsUtils)
local ShiftTripSystem = require(ServerScriptService.Features.Shift.Systems.ShiftTripSystem)

-- The last shift state seen (the `changed` copies arrive in order).
local before: ShiftTypes.ShiftState? = nil

local function onChanged(state: ShiftTypes.ShiftState)
	local previous = before
	before = state
	ShiftAnalyticsSystem.setShift(state)
	if state.phase ~= "running" then
		return
	end
	if previous == nil or previous.phase ~= "running" then
		ShiftAnalyticsSystem.beginShift()
		local replay = state.shift > 1
		ShiftAnalyticsSystem.emit("contract_started", "crew", {
			target = ShiftAnalyticsSystem.variantSource(),
			outcome = if replay then "replay" else "first",
			value = state.shift,
		})
		if replay then
			ShiftAnalyticsSystem.emit("replay_started", "crew", {
				target = "another_shift",
				outcome = "same_server",
				value = state.shift,
			})
		end
	elseif previous ~= nil and state.quotaMet and not previous.quotaMet then
		local at = ShiftAnalyticsSystem.elapsed()
		ShiftAnalyticsSystem.tracker:markQuota(at)
		ShiftAnalyticsSystem.emit("quota_met", "crew", { target = "clearance", outcome = "met", value = at })
	end
end

local function onRunEnded(outcome: string)
	ShiftAnalyticsSystem.closeAttempts(ShiftAnalyticsSystem.salvage:resolveAll("unbanked"))
	local state = ShiftAnalyticsSystem.shift()
	local reason = if state ~= nil and state.quotaMet then "quota_met" else "quota_missed"
	for _, player in ShiftAnalyticsSystem.crew() do
		ShiftAnalyticsSystem.emit("shift_ended", player, {
			target = ShiftAnalyticsUtils.pileBucket(ShiftAnalyticsSystem.tracker:pilesOf(player.UserId)),
			outcome = outcome,
			reason = reason,
			value = ShiftAnalyticsSystem.salvage:attemptsBy(player.UserId),
		})
	end
end

local ShiftAnalyticsWatchSystem = {}

--[=[
	Starts ShiftAnalyticsSystem (its crew = `trip`'s) and subscribes to the features. Returns the function that undoes
	both.
]=]
function ShiftAnalyticsWatchSystem.start(
	changed: SignalTyped.Signal<ShiftTypes.ShiftState>,
	trip: ShiftTripSystem.ShiftTripSystem
): () -> ()
	ShiftAnalyticsSystem.start(function()
		return trip:crew()
	end)
	local stops: { () -> () } = {}
	local function keep(stop: () -> ())
		table.insert(stops, stop)
	end
	local shiftChanged = changed:Connect(onChanged)
	keep(function()
		shiftChanged:Disconnect()
	end)
	local ended = RoundServiceServer.runEnded:Connect(onRunEnded)
	keep(function()
		ended:Disconnect()
	end)
	return function()
		for _, stop in stops do
			stop()
		end
		before = nil
		ShiftAnalyticsSystem.stop()
	end
end

return ShiftAnalyticsWatchSystem
