--!strict
--[=[
	RankShiftSystem: pays out the company rank's shift XP (Cleanup Crew "Clearance Level"). It follows Shift's state
	(`ShiftServiceServer.changed`): when a shift it has not paid reaches its review (phase "results"), every crew
	member on the shift's roster (ShiftReviewSystem.crew) gets `award(userId, runId, facts)` once, with facts from
	RankFormulas.factsFor: the roster's catches, cargo items and overtime salvage, whether the quota was met, and who is
	still with the crew (ShiftAnalyticsSystem.crew), and how the shift ended (the results state's `outcome`: the
	"Clocked out" line is paid only after a clock-out). A run that ends in a reset never reaches "results" and pays nothing.

	The run id is `<session>:<shift>`: the session is a GUID per server start (Shift's counter restarts with the
	server), so a run id never repeats; RankRules.applyAward refuses a run already paid, so even a replayed state cannot
	pay twice. Each award runs in its own guard, so one failure never skips the rest of the crew.

	`start` takes its source (the signal and the two readers) so the spec drives it without a running shift; the
	service hands it the real Shift ones (`RankShiftSystem.shiftSource`).

	@class RankShiftSystem
]=]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local RankTypes = require(ReplicatedStorage.Shared.Features.Rank.Data.RankTypes)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftAnalyticsSystem = require(ServerScriptService.Features.Shift.Systems.ShiftAnalyticsSystem)
local ShiftReviewSystem = require(ServerScriptService.Features.Shift.Systems.ShiftReviewSystem)
local ShiftResultsUtils = require(ServerScriptService.Features.Shift.Utils.ShiftResultsUtils)

export type Award = (userId: number, runId: string, facts: RankTypes.ShiftFacts) -> ()

export type Source = {
	changed: SignalTyped.Signal<ShiftTypes.ShiftState>,
	-- Every crew member's run this shift.
	crew: () -> { ShiftTypes.CrewStats },
	-- The crew members still in the server.
	present: () -> { number },
}

local log = Logger.new("RankShiftSystem")

local RankShiftSystem = {}

-- Shift's real source: its state signal, the review roster and the crew still present.
function RankShiftSystem.shiftSource(changed: SignalTyped.Signal<ShiftTypes.ShiftState>): Source
	return {
		changed = changed,
		crew = ShiftReviewSystem.crew,
		present = function(): { number }
			local ids: { number } = {}
			for _, player in ShiftAnalyticsSystem.crew() do
				table.insert(ids, player.UserId)
			end
			return ids
		end,
	}
end

-- The roster as crew entries (absent counts read 0).
local function entriesOf(crew: { ShiftTypes.CrewStats }): { RankTypes.CrewEntry }
	local entries: { RankTypes.CrewEntry } = {}
	for _, member in crew do
		table.insert(entries, {
			userId = member.userId,
			caught = member.caught or 0,
			items = member.items or 0,
			overtimeSalvage = member.overtimeSalvage or 0,
		})
	end
	return entries
end

--[=[
	Starts paying out reviews from `source` through `award`. `session` names the run ids (a fresh GUID when absent).
	Returns the function that stops it.
]=]
function RankShiftSystem.start(source: Source, award: Award, session: string?): () -> ()
	local prefix = session or HttpService:GenerateGUID(false)
	local paid: { [number]: true } = {}

	local connection = source.changed:Connect(function(state: ShiftTypes.ShiftState)
		if state.phase ~= "results" or paid[state.shift] then
			return
		end
		paid[state.shift] = true
		local runId = `{prefix}:{state.shift}`
		local entries = entriesOf(source.crew())
		local present = source.present()
		local outcome = state.outcome or ""
		for _, entry in entries do
			local facts = RankFormulas.factsFor(
				entries,
				ShiftResultsUtils.met(outcome, state.quotaMet),
				present,
				entry.userId,
				outcome
			)
			if facts ~= nil then
				xpcall(award, function(err: unknown): unknown
					log:error(`rank award for {entry.userId} in run {runId} failed: {err}`)
					return err
				end, entry.userId, runId, facts)
			end
		end
	end)
	return function()
		connection:Disconnect()
	end
end

return RankShiftSystem
