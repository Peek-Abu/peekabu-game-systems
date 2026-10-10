--!strict
--[=[
	ShiftSnapshotUtils: the `shift` world entry (spec §6.3). `build` turns the server's state plus the
	counters, vote counts and results into the plain snapshot published through StateSyncWorldStore;
	`decode` is the client's trust boundary for it (the RoundSnapshotUtils pattern): a wrong type anywhere
	rejects the whole value; absent vote counts read 0.

	@class ShiftSnapshotUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type WorldValue = WorldTypes.WorldValue
type ShiftSnapshot = ShiftTypes.ShiftSnapshot
type ShiftResults = ShiftTypes.ShiftResults

local function phaseOf(value: WorldValue?): ShiftTypes.ShiftPhase?
	if value == "lobby" then
		return "lobby"
	elseif value == "starting" then
		return "starting"
	elseif value == "running" then
		return "running"
	elseif value == "results" then
		return "results"
	end
	return nil
end

local function subOf(value: WorldValue?): ShiftTypes.ShiftSub?
	if value == "normal" then
		return "normal"
	elseif value == "clockout" then
		return "clockout"
	end
	return nil
end

-- The pacing stage: absent reads "normal" (an older snapshot); anything unknown is malformed.
local function stageOf(value: WorldValue?): ShiftTypes.ShiftStage?
	if value == nil or value == "normal" then
		return "normal"
	elseif value == "break" then
		return "break"
	elseif value == "warning" then
		return "warning"
	elseif value == "overtime" then
		return "overtime"
	end
	return nil
end

local function variantOf(value: WorldValue?): ShiftTypes.Variant?
	if value == "A" then
		return "A"
	elseif value == "B" then
		return "B"
	end
	return nil
end

-- An optional number: (value, ok). Absent is fine; any other type is not.
local function optionalNumber(value: WorldValue?): (number?, boolean)
	if value == nil then
		return nil, true
	end
	if type(value) == "number" then
		return value, true
	end
	return nil, false
end

-- A vote count: absent reads 0.
local function countOf(value: WorldValue?): (number, boolean)
	if value == nil then
		return 0, true
	end
	if type(value) == "number" then
		return value, true
	end
	return 0, false
end

local function crewOf(value: WorldValue?): { ShiftTypes.CrewLine }?
	local result: { ShiftTypes.CrewLine } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for _, item in value do
		if type(item) ~= "table" then
			return nil
		end
		local name = item.name
		local banked = item.banked
		local piles = item.piles
		local salvage = item.salvage
		if type(name) ~= "string" then
			return nil
		end
		if type(banked) ~= "number" then
			return nil
		end
		if type(piles) ~= "number" then
			return nil
		end
		if type(salvage) ~= "number" then
			return nil
		end
		table.insert(result, { name = name, banked = banked, piles = piles, salvage = salvage })
	end
	return result
end

local function awardsOf(value: WorldValue?): { ShiftTypes.Award }?
	local result: { ShiftTypes.Award } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for _, item in value do
		if type(item) ~= "table" then
			return nil
		end
		local title = item.title
		local name = item.name
		if type(title) ~= "string" then
			return nil
		end
		if type(name) ~= "string" then
			return nil
		end
		table.insert(result, { title = title, name = name })
	end
	return result
end

local function numberField(value: WorldValue?): number?
	return if type(value) == "number" then value else nil
end

-- The results: (results, ok). Absent is fine.
local function resultsOf(value: WorldValue?): (ShiftResults?, boolean)
	if value == nil then
		return nil, true
	end
	if type(value) ~= "table" then
		return nil, false
	end
	local outcome = value.outcome
	local quotaMet = value.quotaMet
	local quota = numberField(value.quota)
	local cleared = numberField(value.cleared)
	local bonus = numberField(value.bonus)
	local salvage = numberField(value.salvage)
	local piles = numberField(value.piles)
	local crew = crewOf(value.crew)
	local awards = awardsOf(value.awards)
	local catches, catchesOk = countOf(value.catches)
	if type(outcome) ~= "string" or type(quotaMet) ~= "boolean" then
		return nil, false
	end
	if quota == nil or cleared == nil or bonus == nil or salvage == nil or piles == nil then
		return nil, false
	end
	if crew == nil or awards == nil then
		return nil, false
	end
	if not catchesOk then
		return nil, false
	end
	return {
		outcome = outcome,
		quota = quota,
		cleared = cleared,
		bonus = bonus,
		salvage = salvage,
		piles = piles,
		catches = catches,
		quotaMet = quotaMet,
		crew = crew,
		awards = awards,
	},
		true
end

local ShiftSnapshotUtils = {}

--[=[
	The snapshot for `state` (a fresh table: publish a new one every time).
]=]
function ShiftSnapshotUtils.build(
	state: ShiftTypes.ShiftState,
	cleared: number,
	bonus: number,
	votesAnother: number,
	votesDepot: number,
	results: ShiftResults?
): ShiftSnapshot
	return {
		phase = state.phase,
		sub = state.sub,
		stage = state.stage,
		stageEndsAt = state.stageEndsAt,
		tier = state.tier,
		shift = state.shift,
		endsAt = state.endsAt,
		clockOutAt = state.clockOutAt,
		voteEndsAt = state.voteEndsAt,
		quota = state.quota,
		cleared = cleared,
		bonus = bonus,
		quotaMet = state.quotaMet,
		variant = state.variant,
		votesAnother = votesAnother,
		votesDepot = votesDepot,
		results = results,
	}
end

--[=[
	Decodes a replicated snapshot, or nil when it is malformed.
]=]
function ShiftSnapshotUtils.decode(value: WorldValue?): ShiftSnapshot?
	if type(value) ~= "table" then
		return nil
	end
	-- Annotated and tested with `not` (the RoundSnapshotUtils note: comparing an optional singleton union
	-- against nil widens it back to string).
	local phase: ShiftTypes.ShiftPhase? = phaseOf(value.phase)
	local sub: ShiftTypes.ShiftSub? = subOf(value.sub)
	local variant: ShiftTypes.Variant? = variantOf(value.variant)
	local stage: ShiftTypes.ShiftStage? = stageOf(value.stage)
	if not phase or not sub or not variant then
		return nil
	end
	if not stage then
		return nil
	end
	local quotaMet = value.quotaMet
	if type(quotaMet) ~= "boolean" then
		return nil
	end
	local shift = numberField(value.shift)
	local quota = numberField(value.quota)
	local cleared = numberField(value.cleared)
	local bonus = numberField(value.bonus)
	if shift == nil or quota == nil or cleared == nil or bonus == nil then
		return nil
	end
	local endsAt, endsOk = optionalNumber(value.endsAt)
	local clockOutAt, clockOk = optionalNumber(value.clockOutAt)
	local voteEndsAt, voteOk = optionalNumber(value.voteEndsAt)
	local votesAnother, anotherOk = countOf(value.votesAnother)
	local votesDepot, depotOk = countOf(value.votesDepot)
	local results, resultsOk = resultsOf(value.results)
	local stageEndsAt, stageEndsOk = optionalNumber(value.stageEndsAt)
	local tier, tierOk = countOf(value.tier)
	if not (endsOk and clockOk and voteOk and anotherOk and depotOk and resultsOk and stageEndsOk and tierOk) then
		return nil
	end
	local snapshot: ShiftSnapshot = {
		phase = phase,
		sub = sub,
		stage = stage,
		stageEndsAt = stageEndsAt,
		tier = tier,
		shift = shift,
		endsAt = endsAt,
		clockOutAt = clockOutAt,
		voteEndsAt = voteEndsAt,
		quota = quota,
		cleared = cleared,
		bonus = bonus,
		quotaMet = quotaMet,
		variant = variant,
		votesAnother = votesAnother,
		votesDepot = votesDepot,
		results = results,
	}
	return snapshot
end

return ShiftSnapshotUtils
