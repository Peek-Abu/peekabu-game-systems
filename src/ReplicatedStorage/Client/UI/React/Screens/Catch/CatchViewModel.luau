--!strict
--[=[
	CatchViewModel: the catch's screens (Figma 4b/4d CCTV, 4c/4e Rehired card). `cctv`: while the local player is down
	in a running shift, the feed of the teammate Death is spectating (camera number, room, what they carry, rooms from
	the truck), a fictional night clock, the respawn countdown (never below 0:00), the spectate key legends and the
	incident report. Only a real catch shows it: the local player is `dead` AND has a numeric `caughtUntil` (a plain
	death, e.g. a reset, shows nothing), and a report left over from an earlier catch (its `backAt` before this
	catch's deadline) is ignored. `spectateKeys`: the key-cap legends for the spectate actions. `rehired`: the HR notice from REHIRED_LEAD seconds before the respawn until REHIRED_HOLD seconds
	after it (`shown`; the player is held still meanwhile), then REHIRED_FADE more while it fades out. Pure; the components only lay the fields out.

	@class CatchViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

type PublicPlayer = PublicPlayerTypes.PublicPlayer

export type CctvInput = {
	snapshot: ShiftTypes.ShiftSnapshot?,
	me: PublicPlayer?,
	report: OccupantTypes.CatchReport?,
	targetName: string?,
	target: PublicPlayer?,
	now: number,
	prevKey: string,
	nextKey: string,
	phone: boolean,
}

export type CctvView = {
	rec: string,
	watching: string,
	details: string,
	stamp: string,
	back: string,
	incidentTitle: string,
	incident: { string },
	prevKey: string,
	nextKey: string,
	-- Someone is on the feed, so previous / next can switch it (false solo: the controls are hidden).
	canSwitch: boolean,
}

export type RehiredInput = {
	report: OccupantTypes.CatchReport?,
	me: PublicPlayer?,
	name: string,
	rehiredAt: number?,
	nowServer: number,
	nowClock: number,
	phone: boolean,
}

export type RehiredView = {
	-- False while it fades out (the hold is over: the player can move again).
	shown: boolean,
	header: string,
	notice: string,
	title: string,
	rows: { string },
	stamp: string,
	footer: string,
}

-- The approved headline (Figma 4c/4e).
local REHIRED_TITLE = "Rehired."
-- A report whose `backAt` is more than this before the current deadline belongs to an earlier catch (the server sends
-- the same number for both; the slack only absorbs serialisation rounding).
local STALE_SLACK = 1
-- The spectate keys' legends when an action has no keyboard binding (DeathServiceClient's defaults).
local PREV_FALLBACK = "←"
local NEXT_FALLBACK = "→"
local DAY_SECONDS = 86400

local CatchViewModel = {}

-- "the archive", "the manager's office": every room name is a common noun, so it takes "the".
function CatchViewModel.roomPhrase(room: string): string
	return `the {string.lower(room)}`
end

-- "03:02:48": NIGHT_CLOCK_START plus `elapsed` seconds, on a 24-hour clock.
function CatchViewModel.nightClock(elapsed: number): string
	local total = (ShiftConstants.NIGHT_CLOCK_START + math.max(0, math.floor(elapsed))) % DAY_SECONDS
	return string.format("%02d:%02d:%02d", total // 3600, (total // 60) % 60, total % 60)
end

-- The report of the catch whose deadline is `caughtUntil`, or nil when there is none or it is an earlier catch's.
local function currentReport(report: OccupantTypes.CatchReport?, caughtUntil: number): OccupantTypes.CatchReport?
	if report == nil or report.backAt + STALE_SLACK < caughtUntil then
		return nil
	end
	return report
end

local function firstKey(bindings: ShiftHudViewModel.KeyBindings, action: string, fallback: string): string
	local list = bindings[action]
	local first = if list ~= nil then list[1] else nil
	return if first ~= nil then ShiftHudViewModel.keyName(first) else fallback
end

--[=[
	The previous / next teammate key legends: each spectate action's first keyboard binding (DeathConstants.SPECTATE_PREV
	/ SPECTATE_NEXT), the arrow keys when it has none.
]=]
function CatchViewModel.spectateKeys(bindings: ShiftHudViewModel.KeyBindings): (string, string)
	return firstKey(bindings, DeathConstants.SPECTATE_PREV, PREV_FALLBACK),
		firstKey(bindings, DeathConstants.SPECTATE_NEXT, NEXT_FALLBACK)
end

local function depthText(depth: PublicPlayerTypes.PublicValue?): string?
	if type(depth) ~= "number" then
		return nil
	elseif depth <= 0 then
		return "at the truck"
	elseif depth == 1 then
		return "1 room from the truck"
	end
	return `{depth} rooms from the truck`
end

local function feedOf(target: PublicPlayer, name: string, phone: boolean): (string, string, string)
	local cam, room = target[ShiftConstants.PUBLIC_CAM], target[ShiftConstants.PUBLIC_ROOM]
	local camText = if type(cam) == "number" then string.format("%02d", cam) else "--"
	local roomText = if type(room) == "string" then string.upper(room) else "UNKNOWN"
	local kind = target[CarryConstants.PUBLIC_FIELD]
	local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
	local carried = if def ~= nil then `carrying: {def.name}` else "hands empty"
	local depth = depthText(target[ShiftConstants.PUBLIC_ROOM_DEPTH])
	local details = if phone or depth == nil then carried else `{carried} · {depth}`
	return `REC   CAM {camText} · {roomText}`, `WATCHING  {string.upper(name)}`, details
end

local function incidentOf(report: OccupantTypes.CatchReport?, phone: boolean): { string }
	if report == nil then
		return {}
	end
	local lost = #report.dropped > 0
	local where = CatchViewModel.roomPhrase(report.room)
	if phone then
		return { "Caught by the Manager.", if lost then `Cargo dropped in {where}.` else "Nothing dropped." }
	end
	return {
		`Caught by the Manager at {ShiftHudViewModel.clock(report.clock)}.`,
		if lost then `Your cargo dropped in {where}.` else "You were carrying nothing.",
	}
end

function CatchViewModel.cctv(input: CctvInput): CctvView?
	local snapshot = input.snapshot
	local me = input.me
	if snapshot == nil or snapshot.phase ~= "running" or me == nil or me[DeathConstants.PUBLIC_FIELD] ~= true then
		return nil
	end
	local caughtUntil = me[OccupantConstants.PUBLIC_CAUGHT_UNTIL]
	if type(caughtUntil) ~= "number" then
		return nil
	end
	local rec, watching, details = "REC   CAM -- · NO SIGNAL", "NO SIGNAL", "Nobody to watch."
	local target, name = input.target, input.targetName
	local canSwitch = target ~= nil and name ~= nil
	if target ~= nil and name ~= nil then
		rec, watching, details = feedOf(target, name, input.phone)
	end
	local endsAt = snapshot.endsAt
	local elapsed = ShiftConstants.SHIFT_SECONDS - (if endsAt ~= nil then endsAt - input.now else 0)
	local report = currentReport(input.report, caughtUntil)
	return {
		rec = rec,
		watching = watching,
		details = details,
		stamp = `{ShiftConstants.NIGHT_DAY} {CatchViewModel.nightClock(elapsed)}`,
		-- ShiftHudViewModel.clock clamps at 0:00.
		back = `BACK ON THE CLOCK IN {ShiftHudViewModel.clock(caughtUntil - input.now)}`,
		incidentTitle = if input.phone then "INCIDENT REPORT" else "INCIDENT REPORT · YOU",
		incident = incidentOf(report, input.phone),
		prevKey = input.prevKey,
		nextKey = input.nextKey,
		canSwitch = canSwitch,
	}
end

--[=[
	Whether the CCTV overlay follows the clock: only while the local player (`me`) is down with a deadline (the only
	time it shows, and its stamp and "back on the clock" count).
]=]
function CatchViewModel.cctvTicks(me: PublicPlayerTypes.PublicPlayer?): boolean
	return me ~= nil
		and me[DeathConstants.PUBLIC_FIELD] == true
		and type(me[OccupantConstants.PUBLIC_CAUGHT_UNTIL]) == "number"
end

--[=[
	Whether the HR notice follows the clock: with a report, while a catch counts down to the respawn, or until
	REHIRED_HOLD after it, and through the REHIRED_FADE after that (a tick past the hold starts the fade, one past the fade
	removes the notice; after that nothing changes with time).
]=]
function CatchViewModel.rehiredTicks(
	report: OccupantTypes.CatchReport?,
	me: PublicPlayerTypes.PublicPlayer?,
	rehiredAt: number?,
	nowClock: number
): boolean
	if report == nil then
		return false
	end
	local caughtUntil = if me ~= nil then me[OccupantConstants.PUBLIC_CAUGHT_UNTIL] else nil
	return type(caughtUntil) == "number"
		or (
			rehiredAt ~= nil
			and nowClock - rehiredAt <= OccupantConstants.REHIRED_HOLD + OccupantConstants.REHIRED_FADE
		)
end

function CatchViewModel.rehired(input: RehiredInput): RehiredView?
	local report = input.report
	if report == nil then
		return nil
	end
	local caughtUntil = if input.me ~= nil then input.me[OccupantConstants.PUBLIC_CAUGHT_UNTIL] else nil
	local rehiredAt = input.rehiredAt
	-- Before the respawn: this catch's deadline is near and the report is this catch's.
	local before: boolean = type(caughtUntil) == "number"
		and currentReport(report, caughtUntil) ~= nil
		and caughtUntil - input.nowServer <= OccupantConstants.REHIRED_LEAD
	local since = if rehiredAt ~= nil then input.nowClock - rehiredAt else nil
	local holding: boolean = since ~= nil and since <= OccupantConstants.REHIRED_HOLD
	local fading: boolean = since ~= nil
		and since > OccupantConstants.REHIRED_HOLD
		and since <= OccupantConstants.REHIRED_HOLD + OccupantConstants.REHIRED_FADE
	if not before and not holding and not fading then
		return nil
	end
	local ended = ShiftHudViewModel.clock(report.clock)
	local back = ShiftHudViewModel.clock(report.clock - OccupantConstants.SPECTATE_SECONDS)
	local dropped = if #report.dropped > 0
		then `Dropped: {table.concat(report.dropped, ", ")}. Go back for them!`
		else "Dropped: nothing."
	local rows: { string } = if input.phone
		then { `Caught at {ended} by the Manager`, dropped }
		else {
			`Name: {input.name}`,
			`Employment ended: {ended} (caught by the Manager)`,
			`Re-hired: {back}, no questions asked`,
			dropped,
		}
	local shown: boolean = before or holding
	return {
		shown = shown,
		header = `{ShiftConstants.EMPLOYER_BAND} — HUMAN RESOURCES`,
		notice = "NOTICE OF RE-EMPLOYMENT",
		title = REHIRED_TITLE,
		rows = rows,
		stamp = "REHIRED",
		footer = "Respawning at the loading bay…",
	}
end

return CatchViewModel
