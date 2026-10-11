--!strict
--[=[
	ShiftHudViewModel: what the approved Shift HUD (Figma 1a-1c: the time card, the clearance folder and finder's fee
	plate, the carry panel and the clock-out slip) shows, as display-ready fields per piece, from the shift snapshot and
	the local player's public entry; the phone's action-button arc (Figma 1d/1e: which buttons show, which are lit);
	and the results panel's strings (its final screen is Task 15). Pure (specced); the
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
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
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
	-- The phone's compact card has one line beside the clock: OUT until overtime, then OVERTIME (Figma 1d/1e).
	compactSub: string,
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
	-- The phone plate's shorter boost (Figma 1e "+140 ×1.5").
	feeBoostShort: string?,
	-- The carry panel.
	hands: HandsView?,
	pockets: { PocketView },
	canister: number,
	canisterMax: number,
	-- The clock-out slip's countdown, while one runs.
	clockOut: string?,
	truck: number?,
}

export type ButtonsView = {
	primary: "VACUUM" | "LOAD",
	primaryReady: boolean,
	drop: boolean,
	throw: boolean,
	pocket: boolean,
	pocketReady: boolean,
}

-- A round button (or the Jump button's square) as its top-left corner's offset from the screen's bottom-right corner
-- and its diameter, in px.
export type ArcSpot = {
	x: number,
	y: number,
	size: number,
}

export type ArcView = {
	primary: ArcSpot,
	drop: ArcSpot,
	throw: ArcSpot,
	pocket: ArcSpot,
	-- The engine's Jump button the arc keeps clear of.
	jump: ArcSpot,
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
		compactSub = if overtime then "OVERTIME" else `OUT {ShiftHudViewModel.clock(total)}`,
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
		feeBoostShort = if overtime then `×{ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER}` else nil,
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
	The phone's action buttons (Figma 1d/1e): one big button that is VACUUM with empty hands and LOAD while holding
	something (lit green when the truck's Load prompt is up, `loadReady`); DROP / THROW only with something in hand
	(THROW only for a throwable item); POCKET usable with a tiny item or something pocketed, lit when a tiny item can
	go in a free pocket.
]=]
function ShiftHudViewModel.buttons(me: PublicPlayerTypes.PublicPlayer?, loadReady: boolean): ButtonsView
	local entry: PublicPlayerTypes.PublicPlayer = me or {}
	local kind = entry[CarryConstants.PUBLIC_FIELD]
	local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
	local holding = type(kind) == "string"
	local filled, free = 0, 0
	for _, field in CargoConstants.PUBLIC_POCKET_FIELDS do
		if type(entry[field]) == "string" then
			filled += 1
		else
			free += 1
		end
	end
	local tiny = def ~= nil and def.size == "tiny"
	local primary: "VACUUM" | "LOAD" = if holding then "LOAD" else "VACUUM"
	return {
		primary = primary,
		primaryReady = holding and loadReady,
		drop = holding,
		throw = def ~= nil and def.throwable,
		pocket = tiny or filled > 0,
		pocketReady = tiny and free > 0,
	}
end

-- The engine's TouchGui switches to the large Jump button above this short side (px).
ShiftHudViewModel.SMALL_JUMP_SHORT_SIDE = 500

local function spot(x: number, y: number, size: number): ArcSpot
	return table.freeze({ x = x, y = y, size = size })
end

-- Figma 1d (844x390): the Jump button is 70 px at (1,-95,1,-90); LOAD/VACUUM 104 px at (608, 266), DROP (512, 282),
-- THROW (555, 194), POCKET (651, 173), 72 px each, as offsets from the bottom-right corner.
local PHONE_ARC: ArcView = table.freeze({
	primary = spot(-236, -124, 104),
	drop = spot(-332, -108, 72),
	throw = spot(-289, -196, 72),
	pocket = spot(-193, -217, 72),
	jump = spot(-95, -90, 70),
})

-- A larger touch screen: the Jump button is 120 px at (1,-170,1,-210). The big button sits left of it, DROP and THROW
-- stack above the big button, POCKET sits above the Jump button; every gap is >= 16 px, and the arc's left edge
-- (292 px in) stays right of the bottom-left 40% on any screen past 500 px, and right of the desktop carry panel on
-- a 1024 px wide tablet.
local TABLET_ARC: ArcView = table.freeze({
	primary = spot(-292, -132, 104),
	drop = spot(-262, -224, 72),
	throw = spot(-262, -316, 72),
	pocket = spot(-146, -302, 72),
	jump = spot(-170, -210, 120),
})

--[=[
	Where the action buttons sit for a touch screen whose shorter side is `shortSide` px: around the engine's small
	Jump button at 500 px or less (phones), clear of its large Jump button above that.
]=]
function ShiftHudViewModel.arcFor(shortSide: number): ArcView
	return if shortSide <= ShiftHudViewModel.SMALL_JUMP_SHORT_SIDE then PHONE_ARC else TABLET_ARC
end

--[=[
	Whether the shift HUD and the action arc are hidden: during the scare beat (`scaring`), and while the local player
	(`me`) is caught, when the CCTV takes the screen.
]=]
function ShiftHudViewModel.hidden(me: PublicPlayerTypes.PublicPlayer?, scaring: boolean): boolean
	return scaring or (me ~= nil and me[DeathConstants.PUBLIC_FIELD] == true)
end

--[=[
	The phone's action-button arc, or nil when it is not drawn: only on a touch device (`touch`), while a shift runs,
	and not while the HUD is `hidden` (the scare beat, or the local player is caught). See `buttons` for the buttons.
]=]
function ShiftHudViewModel.mobileButtons(
	snapshot: ShiftSnapshot?,
	me: PublicPlayerTypes.PublicPlayer?,
	touch: boolean,
	hidden: boolean,
	loadReady: boolean
): ButtonsView?
	if not touch or hidden or snapshot == nil or snapshot.phase ~= "running" then
		return nil
	end
	return ShiftHudViewModel.buttons(me, loadReady)
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
