--!strict
--[=[
	ShiftCrewViewModel: the crew roster card (Figma 35:1100-35:1165, 1a-1e): each crew member's status line, the ink it
	is written in, whether their name is struck through (caught), and the phone's two-line form (everyone fine on line
	one, trouble on line two, names sharing a status grouped). Status priority: knocked out (OUT) > caught > clocked out (their card punched,
	`punched`) > (while the truck counts down) still inside > carrying > vacuuming > at the truck > room > on shift. Still
	inside is never struck or red: whoever is inside when the truck leaves is paid like the rest. The tick box (Figma
	35:1100 / 35:1119 / 35:1137): ticked for crew who clocked out or are at the truck, a marker X for a caught member,
	empty otherwise. `rosterFrame` places the open roster card clear of the Gloom meter, its clock and what shares the
	phone's band under it; `phoneFit` narrows the phone's meter and crew list so they never overlap; `detailLine`
	cuts a long name to fit. Pure.

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
	-- Gloom lives left and the most this shift (nil when the member is not in a shift: no pips are drawn).
	lives: number?,
	livesMax: number?,
	-- Knocked out for the shift (their last life spent): struck, tagged OUT, and no way back.
	out: boolean,
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
	return {
		userId = userId,
		name = name,
		status = status,
		short = short,
		tone = tone,
		struck = struck,
		box = box,
		out = false,
	}
end

local function baseStatus(
	userId: number,
	name: string,
	entry: PublicPlayerTypes.PublicPlayer,
	clockingOut: boolean,
	punched: boolean,
	now: number
): MemberView
	if entry[ShiftConstants.PUBLIC_KNOCKED_OUT] == true then
		local out = member(userId, name, "OUT", "OUT", "danger", true, false)
		out.out = true
		return out
	end
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

-- A member's status, with their Gloom lives (the `lives` and `livesMax` public fields) when they have them.
local function statusOf(
	userId: number,
	name: string,
	entry: PublicPlayerTypes.PublicPlayer,
	clockingOut: boolean,
	punched: boolean,
	now: number
): MemberView
	local view = baseStatus(userId, name, entry, clockingOut, punched, now)
	local lives = entry[ShiftConstants.PUBLIC_LIVES]
	local livesMax = entry[ShiftConstants.PUBLIC_LIVES_MAX]
	if type(lives) == "number" and type(livesMax) == "number" then
		view.lives = lives
		view.livesMax = livesMax
	end
	return view
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

-- The crew list card (ShiftCrewList) per layout, in HUD design px: rows of `row` px 2 px apart inside `padding`.
ShiftCrewViewModel.LIST = table.freeze({
	phone = table.freeze({ width = 176, row = 28, padding = 8, livesLine = 12 }),
	desktop = table.freeze({ width = 236, row = 40, padding = 12, livesLine = 16 }),
})

-- The tag's column beyond its box: its 2 px inset from the row's right, its ink outline (3 px, drawn outside its box),
-- up to 2 px of sticker tilt and a 2 px gap.
ShiftCrewViewModel.TAG_CLEARANCE = 9
-- The gap between a row's Gloom-life pips and its tag on the lives line.
ShiftCrewViewModel.PIPS_CLEARANCE = 4

export type RowLayout = {
	-- The name's width (it keeps clear of the tag's column only when the tag shares its line).
	nameWidth: number,
	-- With Gloom lives, the pips and the tag share a second line under the name; `pipsX` is the pips' left edge.
	secondLine: boolean,
	pipsX: number,
}

--[=[
	How a crew row of `rowWidth` px lays out (ShiftCrewList): the face then the name on the first line. A row without
	Gloom lives (`livesMax` nil) keeps its tag at the right of the name's line. A row with lives puts the pips under the
	name (left-aligned with it when the tag still fits beside them, else from the row's left edge) and the tag at the
	right of that second line, so the name always has the whole line less the face. `tagWidth` is the tag pill's width
	(0 for none).
]=]
function ShiftCrewViewModel.rowLayout(phone: boolean, rowWidth: number, tagWidth: number, livesMax: number?): RowLayout
	local list = if phone then ShiftCrewViewModel.LIST.phone else ShiftCrewViewModel.LIST.desktop
	local lineX = list.row
	local tagColumn = if tagWidth > 0 then tagWidth + ShiftCrewViewModel.TAG_CLEARANCE else 0
	if livesMax == nil then
		return { nameWidth = rowWidth - lineX - tagColumn, secondLine = false, pipsX = 0 }
	end
	local lives = if phone then ShiftHudViewModel.LIVES.phone else ShiftHudViewModel.LIVES.desktop
	local box = lives.pip + 2 * lives.stroke
	local pipsWidth = livesMax * box + math.max(0, livesMax - 1) * lives.gap
	local fits = lineX + pipsWidth + ShiftCrewViewModel.PIPS_CLEARANCE + tagColumn <= rowWidth
	return { nameWidth = rowWidth - lineX, secondLine = true, pipsX = if fits then lineX else 0 }
end

-- The open roster card (ShiftCompactHudPanel): its widest width, its line pitch (the phone's shrinks to `minLine` on a
-- short screen), the gap it keeps from its neighbours, its text's side padding and (phone) its inset from the left.
ShiftCrewViewModel.DETAIL = table.freeze({
	phone = table.freeze({ width = 220, line = 20, minLine = 16, gap = 8, padding = 8, inset = 10 }),
	desktop = table.freeze({ width = 300, line = 28, minLine = 28, gap = 12, padding = 14, inset = 24 }),
})

-- What else shares the phone's band under the Gloom meter (HUD design px), which the open roster keeps left of:
-- ShiftClockOutBoard's phone board (330 wide, centred under the Gloom-life pips, during the clock-out; its 62 px time-clock render, set 40% over
-- its left edge and tilted -8 degrees, reaches 29 px left of it: 0.6 * 62 / 2 - 31 * (cos 8 + sin 8)). And
-- Roblox's dynamic thumbstick: its ring rests in the bottom 150 px of the screen's left 40% (the card is not Active,
-- so a touch on it still reaches the thumbstick; it is only kept out of the ring's way).
ShiftCrewViewModel.PHONE_BAND = table.freeze({
	boardWidth = 330,
	boardReach = 29,
	thumbTop = 150,
})

export type DetailFrame = {
	-- The card's top-left corner and size in HUD design px (the HUD layer's own frame), its line pitch and its text's
	-- side padding.
	position: Vector2,
	size: Vector2,
	line: number,
	padding: number,
}

-- Whether any of the roster's members carries Gloom lives (then every row has the second line).
function ShiftCrewViewModel.anyLives(members: { MemberView }): boolean
	for _, item in members do
		if item.lives ~= nil then
			return true
		end
	end
	return false
end

-- The height of one crew row: with Gloom lives (`lives`) it carries a second line for the pips and the tag.
function ShiftCrewViewModel.rowHeight(phone: boolean, lives: boolean?): number
	local list = if phone then ShiftCrewViewModel.LIST.phone else ShiftCrewViewModel.LIST.desktop
	return list.row + (if lives == true then list.livesLine else 0)
end

-- The crew list's size for `count` members (with Gloom lives: `lives`, taller rows); `width` (phone:
-- ShiftCrewViewModel.phoneFit) overrides the design width.
function ShiftCrewViewModel.listSize(phone: boolean, count: number, width: number?, lives: boolean?): Vector2
	local list = if phone then ShiftCrewViewModel.LIST.phone else ShiftCrewViewModel.LIST.desktop
	return Vector2.new(width or list.width, 2 * list.padding + count * (ShiftCrewViewModel.rowHeight(phone, lives) + 2))
end

-- Phone: the Gloom meter (centred) and the top-right crew list share the top band. Beside the list, the meter's
-- stopwatch render breaks its right edge by 16 px and keeps `gap` more; so meter + 2 * list <= viewport - 64 (each side
-- of the centred meter loses the list's 10 px inset and 16 + 6 for the stopwatch). The list gives up width first (never
-- under LIST_MIN), then the meter (never under METER_MIN, which then overlaps only below ~650 px wide).
ShiftCrewViewModel.PHONE_FIT = table.freeze({ listMin = 140, meterMin = 300, edge = 2 * (10 + 16 + 6) })

export type PhoneFit = { meter: number, list: number }

function ShiftCrewViewModel.phoneFit(viewportX: number): PhoneFit
	local fit = ShiftCrewViewModel.PHONE_FIT
	local listMax = ShiftCrewViewModel.LIST.phone.width
	local meterMax = ShiftHudViewModel.METER.phone.size.X
	local list = math.clamp(math.floor((viewportX - fit.edge - fit.meterMin) / 2), fit.listMin, listMax)
	return { meter = math.clamp(viewportX - fit.edge - 2 * list, fit.meterMin, meterMax), list = list }
end

--[=[
	Where the open roster card goes on a `viewport` (HUD design px) for `count` members, the crew list's top-left corner
	being `listAt` (its rows taller with Gloom `lives`). It is a title line plus one line per member, 20 px of padding, and it never sits on the Gloom meter
	(ShiftHudViewModel.METER) or its shift clock:
	- desktop: beside the crew list when it ends clear of the meter's Gloom render (wide windows), else under the list;
	- phone (the list is top-right, next to the clock): on the left, `inset` in, `gap` under the meter, ending `gap`
	  before the clock-out board's render (PHONE_BAND); its line pitch shrinks (never under `minLine`) so it ends `gap`
	  above the thumbstick's ring.
]=]
function ShiftCrewViewModel.rosterFrame(
	phone: boolean,
	viewport: Vector2,
	count: number,
	listAt: Vector2,
	lives: boolean?
): DetailFrame
	local detail = if phone then ShiftCrewViewModel.DETAIL.phone else ShiftCrewViewModel.DETAIL.desktop
	local meter = if phone then ShiftHudViewModel.METER.phone else ShiftHudViewModel.METER.desktop
	local meterLeft = viewport.X / 2 - meter.size.X / 2
	if not phone then
		local list = ShiftCrewViewModel.listSize(phone, count, nil, lives)
		local beside = listAt.X + list.X + detail.gap
		local meterEdge = meterLeft - meter.icon * ShiftHudViewModel.METER_ICON_OVERHANG
		local position = if beside + detail.width + detail.gap <= meterEdge
			then Vector2.new(beside, listAt.Y)
			else Vector2.new(listAt.X, listAt.Y + list.Y + detail.gap)
		local height = 20 + (count + 1) * detail.line
		return {
			position = position,
			size = Vector2.new(detail.width, height),
			line = detail.line,
			padding = detail.padding,
		}
	end
	local band = ShiftCrewViewModel.PHONE_BAND
	local board = viewport.X / 2 - band.boardWidth / 2 - band.boardReach
	local width = math.floor(math.min(detail.width, board - detail.gap - detail.inset))
	local top = meter.top + meter.size.Y + detail.gap
	local bottom = viewport.Y - band.thumbTop - detail.gap
	local pitch = math.clamp(math.floor((bottom - top - 20) / (count + 1)), detail.minLine, detail.line)
	return {
		position = Vector2.new(detail.inset, top),
		size = Vector2.new(width, 20 + (count + 1) * pitch),
		line = pitch,
		padding = detail.padding,
	}
end

-- The first `count` characters of `text` (UTF-8 safe: a display name may hold any script).
local function prefix(text: string, count: number): string
	local cut = utf8.offset(text, count + 1)
	return if cut == nil then text else string.sub(text, 1, cut - 1)
end

--[=[
	A member's roster line ("Sam: CAUGHT · back 0:12") for `room` px, `widthOf` measuring a line at the smallest size it
	may be drawn at: the whole line when it fits, else the name cut short with an ellipsis ("Alexandr…: vacuuming") as
	far as it must be, down to its initial ("A: CAUGHT · back 0:12"). The status is never cut: it is what the line is for.
]=]
function ShiftCrewViewModel.detailLine(
	name: string,
	status: string,
	room: number,
	widthOf: (text: string) -> number
): string
	local full = `{name}: {status}`
	if widthOf(full) <= room then
		return full
	end
	local length = utf8.len(name) or #name
	for keep = length - 1, 1, -1 do
		local text = `{prefix(name, keep)}…: {status}`
		if widthOf(text) <= room then
			return text
		end
	end
	return `{prefix(name, 1)}: {status}`
end

return ShiftCrewViewModel
