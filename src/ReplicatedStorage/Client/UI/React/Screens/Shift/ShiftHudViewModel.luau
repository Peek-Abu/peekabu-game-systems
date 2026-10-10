--!strict
--[=[
	ShiftHudViewModel: the strings the M1 placeholder Shift HUD and results panel show, from the shift
	snapshot and the local player's public entry. Pure (specced); the components only lay them out. Final
	screens replace these components after the developer's Figma approval (M3); the view model can stay.

	@class ShiftHudViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

type ShiftSnapshot = ShiftTypes.ShiftSnapshot

export type HudView = {
	timer: string,
	clearance: string,
	quotaMet: boolean,
	bonus: string,
	canister: string,
	hands: string,
	pockets: string,
	clockOut: string?,
}

export type ResultsView = {
	title: string,
	lines: { string },
	another: string,
	depot: string,
	countdown: string,
}

local EMPTY = "-"
local OUTCOME_TEXT: { [string]: string } = {
	clockout = "Clocked out",
	timeout = "Time's up",
	abandoned = "Everyone left",
}

local function nameOf(kind: PublicPlayerTypes.PublicValue?): string
	if type(kind) ~= "string" then
		return EMPTY
	end
	local def = CargoRegistry.get(kind)
	return if def ~= nil then def.name else kind
end

local ShiftHudViewModel = {}

-- "m:ss", seconds rounded up, never below 0:00.
function ShiftHudViewModel.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

--[=[
	The HUD's lines while a shift runs; nil otherwise. `me` is the local player's public entry.
]=]
function ShiftHudViewModel.hud(snapshot: ShiftSnapshot?, me: PublicPlayerTypes.PublicPlayer?, now: number): HudView?
	if snapshot == nil or snapshot.phase ~= "running" then
		return nil
	end
	local entry: PublicPlayerTypes.PublicPlayer = me or {}
	local fill = entry[VacuumConstants.PUBLIC_FIELD]
	local pockets: { string } = {}
	for _, field in CargoConstants.PUBLIC_POCKET_FIELDS do
		table.insert(pockets, nameOf(entry[field]))
	end
	local endsAt = snapshot.endsAt
	local clockOutAt = snapshot.clockOutAt
	return {
		timer = `Shift {snapshot.shift} | {ShiftHudViewModel.clock(if endsAt ~= nil then endsAt - now else 0)}`,
		clearance = `Clearance {snapshot.cleared} / {snapshot.quota}`,
		quotaMet = snapshot.quotaMet,
		bonus = `Bonus {snapshot.bonus}`,
		canister = `Canister {if type(fill) == "number" then fill else 0} / {VacuumConstants.CANISTER_CAPACITY}`,
		hands = `Hands: {nameOf(entry[CarryConstants.PUBLIC_FIELD])}`,
		pockets = `Pockets: {table.concat(pockets, " | ")}`,
		clockOut = if snapshot.sub == "clockout" and clockOutAt ~= nil
			then `CLOCKING OUT {ShiftHudViewModel.clock(clockOutAt - now)}`
			else nil,
	}
end

--[=[
	The results panel's lines while the crew votes; nil otherwise.
]=]
function ShiftHudViewModel.results(snapshot: ShiftSnapshot?, now: number): ResultsView?
	if snapshot == nil or snapshot.phase ~= "results" then
		return nil
	end
	local lines: { string } = {}
	local review = snapshot.results
	if review ~= nil then
		table.insert(lines, OUTCOME_TEXT[review.outcome] or review.outcome)
		table.insert(
			lines,
			`Cleared {review.cleared} / {review.quota} - {if review.quotaMet then "QUOTA MET" else "quota missed"}`
		)
		table.insert(lines, `Bonus {review.bonus}`)
		table.insert(lines, `Salvage found {review.salvage} | Piles vacuumed {review.piles}`)
		for _, member in review.crew do
			table.insert(lines, `{member.name}: banked {member.banked}, piles {member.piles}`)
		end
		for _, award in review.awards do
			table.insert(lines, `{award.title}: {award.name}`)
		end
	end
	local voteEndsAt = snapshot.voteEndsAt
	return {
		title = `Shift {snapshot.shift} performance review`,
		lines = lines,
		another = `Another shift ({snapshot.votesAnother})`,
		depot = `Back to depot ({snapshot.votesDepot})`,
		countdown = `Deciding in {ShiftHudViewModel.clock(if voteEndsAt ~= nil then voteEndsAt - now else 0)}`,
	}
end

return ShiftHudViewModel
