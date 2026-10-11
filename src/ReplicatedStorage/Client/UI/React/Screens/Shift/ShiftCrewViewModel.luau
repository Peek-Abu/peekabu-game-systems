--!strict
--[=[
	ShiftCrewViewModel: the crew roster card (Figma 35:1100-35:1165, 1a-1e): each crew member's status line, the ink it
	is written in, whether their name is struck through (caught, or not aboard while clocking out), and the phone's
	two-line form (everyone fine on line one, trouble on line two, names sharing a status grouped). Status priority:
	caught > (while clocking out) in the truck bed / NOT ABOARD > carrying > vacuuming > at the truck > room > on shift.
	The tick box (Figma 35:1100 / 35:1119 / 35:1137): ticked only for crew at or in the truck ("at the truck", "in the
	truck bed"), a marker X for a struck member (caught, NOT ABOARD), empty otherwise. Pure.

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
}

export type RosterView = {
	title: string,
	members: { MemberView },
	compact: { string },
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
	now: number
): MemberView
	local caughtUntil = entry[OccupantConstants.PUBLIC_CAUGHT_UNTIL]
	if type(caughtUntil) == "number" then
		local text = `CAUGHT · back {ShiftHudViewModel.clock(caughtUntil - now)}`
		return member(userId, name, text, text, "danger", true, false)
	end
	if entry[DeathConstants.PUBLIC_FIELD] == true then
		return member(userId, name, "CAUGHT", "CAUGHT", "danger", true, false)
	end
	local inTruck = entry[ShiftConstants.PUBLIC_IN_TRUCK] == true
	if clockingOut then
		if inTruck then
			return member(userId, name, "in the truck bed", "in the truck bed", "ok", false, true)
		end
		return member(userId, name, "NOT ABOARD", "NOT ABOARD", "danger", true, false)
	end
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
	now: number
): RosterView?
	if #crew == 0 then
		return nil
	end
	local members: { MemberView } = {}
	local fine: { MemberView } = {}
	local trouble: { MemberView } = {}
	for _, userId in crew do
		local entry = players[StateSyncConstants.publicEntryKey(userId)] or {}
		local view = statusOf(userId, names[userId] or "Crew", entry, clockingOut, now)
		table.insert(members, view)
		table.insert(if view.tone == "danger" then trouble else fine, view)
	end
	local compact: { string } = {}
	local first, second = line(fine), line(trouble)
	if first ~= nil then
		table.insert(compact, first)
	end
	if second ~= nil then
		table.insert(compact, second)
	end
	return {
		title = if truck ~= nil then `CREW ROSTER · TRUCK {truck}` else "CREW ROSTER",
		members = members,
		compact = compact,
	}
end

return ShiftCrewViewModel
