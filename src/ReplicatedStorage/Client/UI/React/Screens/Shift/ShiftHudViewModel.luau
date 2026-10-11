--!strict
--[=[
	ShiftHudViewModel: what the approved Shift HUD (Figma 1a-1c: the time card, the clearance folder and finder's fee
	plate, the carry panel and the clock-out slip) shows, as display-ready fields per piece, from the shift snapshot and
	the local player's public entry; and the results panel's strings (its final screen is Task 15). Pure (specced); the
	components only lay the fields out. The crew roster has its own view model (ShiftCrewViewModel).

	@class ShiftHudViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

type ShiftSnapshot = ShiftTypes.ShiftSnapshot

export type HandsView = {
	name: string,
	value: string,
	traits: string,
	short: string,
	-- Whether the traits are written in red (a FRAGILE item).
	fragile: boolean,
}

export type PocketView = {
	name: string,
	empty: boolean,
}

export type HudView = {
	-- The time card.
	clockLabel: string,
	time: string,
	outText: string,
	overtime: boolean,
	punched: number,
	pressure: number,
	-- The clearance folder and the finder's fee plate.
	cleared: string,
	quotaText: string,
	clearedShort: string,
	fill: number,
	quotaMet: boolean,
	fee: string,
	feeBoost: string?,
	-- The carry panel.
	hands: HandsView?,
	pockets: { PocketView },
	canister: number,
	canisterMax: number,
	-- The clock-out slip's countdown, while one runs.
	clockOut: string?,
	truck: number?,
}

export type ResultsView = {
	title: string,
	lines: { string },
	another: string,
	depot: string,
	countdown: string,
}

local OUTCOME_TEXT: { [string]: string } = {
	clockout = "Clocked out",
	timeout = "Time's up",
	abandoned = "Everyone left",
}

local ShiftHudViewModel = {}

-- "m:ss", seconds rounded up, never below 0:00.
function ShiftHudViewModel.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

ShiftHudViewModel.PUNCH_HOLES = 5
ShiftHudViewModel.PRESSURE_PIPS = 3

local function traitsOf(def: CargoTypes.ItemDef): string
	local parts: { string } = { def.size }
	if def.fragile then
		table.insert(parts, "FRAGILE")
	end
	if def.rattly then
		table.insert(parts, "RATTLY")
	end
	return table.concat(parts, " · ")
end

local function handsOf(kind: PublicPlayerTypes.PublicValue?): HandsView?
	if type(kind) ~= "string" then
		return nil
	end
	local def = CargoRegistry.get(kind)
	if def == nil then
		return { name = kind, value = "", traits = "", short = "", fragile = false }
	end
	return {
		name = def.name,
		value = `+{def.value}`,
		traits = traitsOf(def),
		short = `+{def.value}{if def.fragile then " fragile" else ""}`,
		fragile = def.fragile,
	}
end

local function stageLabel(snapshot: ShiftSnapshot, now: number): string
	local stageEndsAt = snapshot.stageEndsAt
	local left = if stageEndsAt ~= nil then stageEndsAt - now else 0
	if snapshot.stage == "break" then
		return `HARLOW ON BREAK {ShiftHudViewModel.clock(left)}`
	elseif snapshot.stage == "warning" then
		return `OVERTIME IN {ShiftHudViewModel.clock(left)}`
	elseif snapshot.stage == "overtime" then
		return "OVERTIME"
	end
	return "SHIFT"
end

--[=[
	The HUD's pieces while a shift runs; nil otherwise, and nil while `hidden` (the scare beat, or the local player is
	caught: the CCTV takes the screen). `me` is the local player's public entry.
]=]
function ShiftHudViewModel.hud(
	snapshot: ShiftSnapshot?,
	me: PublicPlayerTypes.PublicPlayer?,
	now: number,
	hidden: boolean
): HudView?
	if hidden or snapshot == nil or snapshot.phase ~= "running" then
		return nil
	end
	local entry: PublicPlayerTypes.PublicPlayer = me or {}
	local endsAt = snapshot.endsAt
	local left = if endsAt ~= nil then endsAt - now else 0
	local total = ShiftConstants.SHIFT_SECONDS
	local elapsed = math.clamp(total - left, 0, total)
	local pockets: { PocketView } = {}
	for _, field in CargoConstants.PUBLIC_POCKET_FIELDS do
		local kind = entry[field]
		local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
		table.insert(pockets, {
			name = if def ~= nil then def.name elseif type(kind) == "string" then kind else "empty",
			empty = type(kind) ~= "string",
		})
	end
	local fill = entry[VacuumConstants.PUBLIC_FIELD]
	local clockOutAt = snapshot.clockOutAt
	local overtime = snapshot.stage == "overtime"
	return {
		clockLabel = stageLabel(snapshot, now),
		time = ShiftHudViewModel.clock(left),
		outText = `OUT {ShiftHudViewModel.clock(total)}`,
		overtime = overtime,
		punched = math.clamp(
			math.floor(elapsed / total * ShiftHudViewModel.PUNCH_HOLES),
			0,
			ShiftHudViewModel.PUNCH_HOLES
		),
		pressure = math.clamp(snapshot.tier + 1, 1, ShiftHudViewModel.PRESSURE_PIPS),
		cleared = tostring(snapshot.cleared),
		quotaText = `/ {snapshot.quota} cleared`,
		clearedShort = `{snapshot.cleared} / {snapshot.quota}`,
		fill = if snapshot.quota > 0 then math.clamp(snapshot.cleared / snapshot.quota, 0, 1) else 1,
		quotaMet = snapshot.quotaMet,
		fee = `+{snapshot.bonus}`,
		feeBoost = if overtime then `×{ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER} now` else nil,
		hands = handsOf(entry[CarryConstants.PUBLIC_FIELD]),
		pockets = pockets,
		canister = if type(fill) == "number" then fill else 0,
		canisterMax = VacuumConstants.CANISTER_CAPACITY,
		clockOut = if snapshot.sub == "clockout" and clockOutAt ~= nil
			then ShiftHudViewModel.clock(clockOutAt - now)
			else nil,
		truck = snapshot.truck,
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
		table.insert(lines, `Caught by Mr. Harlow: {review.catches}`)
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
