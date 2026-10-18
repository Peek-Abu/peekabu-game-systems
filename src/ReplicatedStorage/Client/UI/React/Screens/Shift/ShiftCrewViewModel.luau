--!strict
--[=[
	ShiftCrewViewModel: the crew roster card (Figma 35:1100-35:1165, 1a-1e): each crew member's status line, the ink it
	is written in, whether their name is struck through (caught), and the phone's two-line form (everyone fine on line
	one, trouble on line two, names sharing a status grouped). Status priority: caught > clocked out (their card punched,
	`punched`) > (while the truck counts down) still inside > carrying > vacuuming > at the truck > room > on shift. Still
	inside is never struck or red: whoever is inside when the truck leaves is paid like the rest. The tick box (Figma
	35:1100 / 35:1119 / 35:1137): ticked for crew who clocked out or are at the truck, a marker X for a caught member,
	empty otherwise. Pure.

	@class ShiftCrewViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type Tone = "ok" | "busy" | "danger" | "muted"

-- The roster's tick box: empty, a green tick (at or in the truck) or a red marker X (struck).
export type Box = "empty" | "tick" | "x"

export type MemberView = {
	userId: number,
	name: string,
	status: string,
	short: string,
	tone: Tone,
	struck: boolean,
	box: Box,
	-- While caught: the server-clock time they are back, which the status counts down to (a live line ticks on it).
	caughtUntil: number?,
}

export type RosterView = {
	title: string,
	members: { MemberView },
	compact: { string },
	-- Parallel to `compact`: whether that line is the trouble line (written in red ink on the phone).
	compactDanger: { boolean },
}

local ShiftCrewViewModel = {}

local function member(
	userId: number,
	name: string,
	status: string,
	short: string,
	tone: Tone,
	struck: boolean,
	aboard: boolean
): MemberView
	local box: Box = if struck then "x" elseif aboard then "tick" else "empty"
	return { userId = userId, name = name, status = status, short = short, tone = tone, struck = struck, box = box }
end

local function statusOf(
	userId: number,
	name: string,
	entry: PublicPlayerTypes.PublicPlayer,
	clockingOut: boolean,
	punched: boolean,
	now: number
): MemberView
	local caughtUntil = entry[OccupantConstants.PUBLIC_CAUGHT_UNTIL]
	if type(caughtUntil) == "number" then
		local text = `CAUGHT · back {ShiftHudViewModel.clock(caughtUntil - now)}`
		local caught = member(userId, name, text, text, "danger", true, false)
		caught.caughtUntil = caughtUntil
		return caught
	end
	if entry[DeathConstants.PUBLIC_FIELD] == true then
		return member(userId, name, "CAUGHT", "CAUGHT", "danger", true, false)
	end
	if punched then
		return member(userId, name, "clocked out", "clocked out", "ok", false, true)
	end
	if clockingOut then
		return member(userId, name, "still inside", "still inside", "busy", false, false)
	end
	local inTruck = entry[ShiftConstants.PUBLIC_IN_TRUCK] == true
	local carrying = entry[CarryConstants.PUBLIC_FIELD]
	if type(carrying) == "string" then
		local def = CargoRegistry.get(carrying)
		return member(
			userId,
			name,
			`carrying {if def ~= nil then def.name else carrying}`,
			"carrying",
			"busy",
			false,
			false
		)
	end
	if entry[ShiftConstants.PUBLIC_VACUUMING] == true then
		return member(userId, name, "vacuuming", "vacuuming", "ok", false, false)
	end
	if inTruck then
		return member(userId, name, "at the truck", "at the truck", "ok", false, true)
	end
	local room = entry[ShiftConstants.PUBLIC_ROOM]
	if type(room) == "string" then
		return member(userId, name, room, room, "muted", false, false)
	end
	return member(userId, name, "on shift", "on shift", "muted", false, false)
end

-- "Sam, Alex: in the truck bed · Jo: vacuuming": names that share a short status, grouped, in roster order.
local function line(members: { MemberView }): string?
	local order: { string } = {}
	local names: { [string]: { string } } = {}
	for _, item in members do
		local group = names[item.short]
		if group == nil then
			group = {}
			names[item.short] = group
			table.insert(order, item.short)
		end
		table.insert(group, item.name)
	end
	if #order == 0 then
		return nil
	end
	local parts: { string } = {}
	for _, short in order do
		table.insert(parts, `{table.concat(names[short], ", ")}: {short}`)
	end
	return table.concat(parts, " · ")
end

function ShiftCrewViewModel.roster(
	crew: { number },
	players: PublicPlayerTypes.PublicPlayerMap,
	names: { [number]: string },
	truck: number?,
	clockingOut: boolean,
	now: number,
	punched: { number }?
): RosterView?
	if #crew == 0 then
		return nil
	end
	local members: { MemberView } = {}
	local fine: { MemberView } = {}
	local trouble: { MemberView } = {}
	for _, userId in crew do
		local entry = players[StateSyncConstants.publicEntryKey(userId)] or {}
		local out = punched ~= nil and table.find(punched, userId) ~= nil
		local view = statusOf(userId, names[userId] or "Crew", entry, clockingOut, out, now)
		table.insert(members, view)
		table.insert(if view.tone == "danger" then trouble else fine, view)
	end
	local compact: { string } = {}
	local compactDanger: { boolean } = {}
	local first, second = line(fine), line(trouble)
	if first ~= nil then
		table.insert(compact, first)
		table.insert(compactDanger, false)
	end
	if second ~= nil then
		table.insert(compact, second)
		table.insert(compactDanger, true)
	end
	return {
		title = if truck ~= nil then `CREW ROSTER · TRUCK {truck}` else "CREW ROSTER",
		members = members,
		compact = compact,
		compactDanger = compactDanger,
	}
end

return ShiftCrewViewModel
