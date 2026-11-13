--!strict
--[=[
	DepotBoardViewModel: the depot's places menu (the contract board, Figma 2a/2b; p1-places-menu). One photo card per
	place: the Office and the School (`places`: open, or locked with its Credits BUY that takes two taps; its DANGER
	level; the focused place ringed, the truck's pick tagged TONIGHT!; only the host's tap picks, DepotPlaceRules decides
	what is owned) and the planned buildings coming soon. The detail follows the focused place: its client, its contract
	for the crew in the reader's truck (`crewOf`, else the range by crew size), its tip and its monster. Also tonight's
	work order (numbered from the contract id, the same everywhere), its rows (desktop six, phone four; the HAZARD row
	marked), the night guard's sticky, the returning player's last-shift card (none for a player who has not played)
	and the dispatch slip; and `fit`, the scale that keeps the board on a smaller screen. Pure.

	@class DepotBoardViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotPlaceConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotPlaceConstants)
local DepotMapRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotMapRules)
local DepotPlaceRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotPlaceRules)
local HostConstants = require(ReplicatedStorage.Shared.Features.Host.Data.HostConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local QueueSnapshotUtils = require(ReplicatedStorage.Shared.Features.Queue.Utils.QueueSnapshotUtils)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftCurrencyUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftCurrencyUtils)
local ShiftQuotaFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftQuotaFormulas)
local ShopTopUpRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopTopUpRules)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local PaperHudScaleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudScaleViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

type MapId = ShiftTypes.MapId

export type RowView = { label: string, text: string, hazard: boolean }

export type LastView = {
	title: string,
	rows: { { label: string, value: string } },
	stamp: string,
	met: boolean,
	lines: { string },
}

-- V1: one contract chip (QUOTA, SHIFT, PAY, CREW) with its render.
export type ChipView = { label: string, value: string, icon: UIAssets.ToonIcon }

-- A locked place's BUY button: its price, whether the reader can pay it, and whether the first tap waits on SURE?
-- (two taps buy, so a kid never spends by mistake). Short of Credits, Gleam pays the rest (ShopTopUpRules, the
-- Shop's rate): the button offers `gleam` Gleam (0: Credits only), and `note` says how many Credits are missing.
export type BuyView = {
	text: string,
	price: string,
	enabled: boolean,
	confirming: boolean,
	gleam: number,
	note: string?,
}

export type Photo = "office" | "school" | "hospital" | "motel" | "mall"

-- One card on the places menu: a playable place (`map`; open when owned, else locked with its BUY) with its DANGER
-- level, or a planned building coming soon (no `map`; its concept photo is a stand-in until the map exists).
-- `focused` is the ringed card the detail shows; `picked` the truck's pick; `canPick` lets the reader's tap pick it
-- for their truck (the host only).
export type BuildingView = {
	name: string,
	site: string,
	photo: Photo,
	open: boolean,
	tag: string,
	map: MapId?,
	danger: number?,
	focused: boolean,
	picked: boolean,
	canPick: boolean,
	buy: BuyView?,
}

-- Where the reader stands: the host of a hosted truck, crew aboard one, or not on a hosted truck.
export type Role = "host" | "crew" | "none"

-- What the places menu knows about the reader.
export type PlacesInput = {
	-- Their bought places (the `places` slice; nil before it syncs).
	owned: PlayerDataTypes.Places?,
	-- The truck's pick when aboard a hosted truck (the server's, DepotMapRules.mapOf), else nil.
	picked: MapId?,
	-- The card they last tapped off a truck (nil: the Office).
	viewing: MapId?,
	role: Role,
	credits: number,
	-- Their Gleam (pays the rest when Credits are short).
	gleam: number,
	-- The place whose BUY was tapped once and waits on SURE?.
	confirming: MapId?,
}

export type BoardView = {
	-- The menu's header and the line under the cards (who picks the place).
	header: string,
	pickLine: string,
	dangerLabel: string,
	dangerMax: number,
	-- The focused place (the truck's pick aboard one, else the card last tapped) and its monster's kind.
	focus: MapId,
	monster: string,
	client: string,
	chips: { ChipView },
	buildings: { BuildingView },
	tip: string,
	lastLine: string?,
	title: string,
	workOrder: string,
	headline: string,
	subline: string,
	rows: { RowView },
	sticky: string,
	approved: string,
	last: LastView?,
	dispatchLabel: string,
	dispatchTitle: string,
	dispatchSteps: string,
	close: string,
}

-- The board's drawn size (Figma 2a pinboard 1580x900, 2b 748x308) and the screen margin it keeps: desktop clears the
-- safe sides (60 each) and the top bar plus the bottom inset (68 + 68); phone the notch sides (48 each) and the top
-- bar plus the bottom inset (62 + 20).
local BOARD = table.freeze({
	desktop = table.freeze({ width = 1580, height = 900, marginX = 120, marginY = 136 }),
	phone = table.freeze({ width = 748, height = 308, marginX = 96, marginY = 82 }),
})

local DepotBoardViewModel = {}

-- The smallest scale `fit` returns (a degenerate viewport still draws something readable to close).
DepotBoardViewModel.MIN_SCALE = 0.4

-- "#2802": four digits from the contract id (a stable string hash), so every depot prints the same number.
function DepotBoardViewModel.workOrder(id: string): string
	local hash = 0
	for index = 1, #id do
		hash = (hash * 31 + string.byte(id, index)) % 10000
	end
	return string.format("#%04d", hash)
end

-- The scale the board is drawn at on a `viewport`-sized screen: the game's one UI scale (PaperHudScaleViewModel) when
-- the board fits at it, else the tighter side's ratio.
function DepotBoardViewModel.fit(viewport: Vector2, phone: boolean): number
	local board = if phone then BOARD.phone else BOARD.desktop
	local across = (viewport.X - board.marginX) / board.width
	local down = (viewport.Y - board.marginY) / board.height
	local fit = PaperHudScaleViewModel.cap(math.min(across, down), viewport, if phone then "phone" else "desktop")
	return math.max(fit, DepotBoardViewModel.MIN_SCALE)
end

local function contractOf(id: string?): DepotTypes.Contract
	for _, contract in DepotConstants.CONTRACTS do
		if contract.id == id then
			return contract
		end
	end
	return DepotConstants.CONTRACTS[1]
end

local function lastOf(last: DepotTypes.LastShift, phone: boolean): LastView
	local stamp = if last.quotaMet then "GOAL DONE!" else "GOAL MISSED"
	local title = if phone
		then "LAST SHIFT"
		elseif last.truck > 0 then `YOUR LAST SHIFT — TRUCK {last.truck}`
		else "YOUR LAST SHIFT"
	-- Every Gloom removed paid its Credits at clock-out, on top of the valuables banked.
	local earned = ShiftQuotaFormulas.breakdown(last.cleared, 0, last.bonus).credits
	return {
		title = title,
		rows = {
			{ label = "Gloom removed", value = `{last.cleared} / {last.quota}` },
			{ label = "Earned", value = ShiftCurrencyUtils.amount(earned) },
			{ label = "Crew caught", value = tostring(last.catches) },
			{ label = "Assets recovered", value = `{last.salvage} of {last.offered}` },
		},
		stamp = stamp,
		met = last.quotaMet,
		lines = {
			`Gloom {last.cleared}/{last.quota}  ·  {ShiftCurrencyUtils.gain(earned)}`,
			`Caught {last.catches}  ·  Assets {last.salvage} of {last.offered}`,
		},
	}
end

-- The size of the crew `userId` is queued with (their truck's pad in the queue snapshot); nil when not in a truck.
function DepotBoardViewModel.crewOf(snapshot: QueueTypes.QueueSnapshot?, userId: number): number?
	local _, pad = QueueSnapshotUtils.padOf(snapshot, userId)
	return if pad ~= nil then #pad.members else nil
end

-- The CONTRACT row: the contract on `map` for a crew of `crew`, or the range by crew size when there is no crew yet.
local function quotaText(crew: number?, phone: boolean, map: MapId): string
	local copy = DepotConstants.BOARD_COPY
	if crew == nil then
		-- A regular truck's range (1 to SEATS): a Big Crew's bigger contract is not posted.
		local low = ShiftQuotaFormulas.quota(1, map)
		local high = ShiftQuotaFormulas.quota(HostConstants.SEATS, map)
		return string.format(if phone then copy.quotaPhoneRange else copy.quotaRange, low, high)
	end
	local quota = ShiftQuotaFormulas.quota(crew, map)
	if phone then
		return string.format(copy.quotaPhoneCrew, quota)
	end
	return if crew <= 1 then string.format(copy.quotaSolo, quota) else string.format(copy.quotaCrew, quota, crew)
end

type Soon = { name: string, site: string, photo: Photo }

local SOON: { Soon } = {
	{ name = "ST. AGNES HOSPITAL", site = "West wing night ward", photo = "hospital" },
	{ name = "LANTERN LANE MOTEL", site = "Rooms 1–24", photo = "motel" },
	{ name = "GLIMMER MALL", site = "After hours", photo = "mall" },
}

-- The QUOTA chip: the crew's contract on `map`, or the range by crew size.
local function quotaChip(crew: number?, map: MapId): string
	if crew == nil then
		local low = ShiftQuotaFormulas.quota(1, map)
		local high = ShiftQuotaFormulas.quota(HostConstants.SEATS, map)
		return `{low}–{high} Gloom`
	end
	return `{ShiftQuotaFormulas.quota(crew, map)} Gloom`
end

-- "1,500": a whole number with thousands commas.
function DepotBoardViewModel.commas(value: number): string
	local text = tostring(math.floor(value))
	local out = ""
	while #text > 3 do
		out = "," .. string.sub(text, -3) .. out
		text = string.sub(text, 1, -4)
	end
	return text .. out
end

local NO_PLACES: PlacesInput = {
	owned = nil,
	picked = nil,
	viewing = nil,
	role = "none",
	credits = 0,
	gleam = 0,
	confirming = nil,
}

-- Where `myId` stands: the host of the hosted truck `padId` (hosted by `hostId`), its crew, or "none" (off a truck, or
-- on a truck nobody hosts yet).
function DepotBoardViewModel.roleOf(padId: string?, hostId: number?, myId: number): Role
	if padId == nil or hostId == nil then
		return "none"
	end
	return if hostId == myId then "host" else "crew"
end

-- The place the ring and the detail show: the truck's pick aboard a hosted truck, else the card last tapped.
function DepotBoardViewModel.focusOf(places: PlacesInput): MapId
	local source = if places.role ~= "none" and places.picked ~= nil then places.picked else places.viewing
	if source == "school" then
		return "school"
	end
	return "office"
end

-- The line under the cards: who picks the place.
local function pickLine(role: Role): string
	local text = DepotPlaceConstants.TEXT
	if role == "host" then
		return text.youPick
	elseif role == "crew" then
		return text.hostPicks
	end
	return text.findTruck
end

-- One playable place's card.
local function placeCard(map: MapId, name: string, places: PlacesInput, focus: MapId): BuildingView
	local text = DepotPlaceConstants.TEXT
	local open = DepotPlaceRules.owns(places.owned, map)
	local picked = places.role ~= "none" and places.picked == map
	local tag = if picked then text.picked elseif open then text.open else text.locked
	local buy: BuyView? = nil
	if not open then
		local price = DepotPlaceRules.price(map)
		-- nil when the Credits cover it; else the Gleam that pays the rest.
		local plan = ShopTopUpRules.plan("credits", price, places.credits)
		local enabled = plan == nil or places.gleam >= plan.gleam
		local confirming = enabled and places.confirming == map
		local label = if not enabled
			then text.tooPoor
			elseif confirming then text.sure
			elseif plan ~= nil then string.format(text.useGleam, plan.gleam)
			else text.buy
		buy = {
			text = label,
			price = DepotBoardViewModel.commas(price),
			enabled = enabled,
			confirming = confirming,
			gleam = if plan ~= nil then plan.gleam else 0,
			note = if plan ~= nil and enabled
				then string.format(text.shortBy, price - math.max(0, places.credits))
				else nil,
		}
	end
	return {
		name = name,
		site = DepotMapRules.siteOf(map).site,
		photo = map,
		open = open,
		tag = tag,
		map = map,
		danger = DepotPlaceRules.danger(map),
		focused = focus == map,
		picked = picked,
		canPick = open and places.role == "host",
		buy = buy,
	}
end

-- The client a run on `map` works for (the Office's from tonight's board contract `office`).
local function clientOf(map: MapId, office: DepotTypes.Contract): string
	if map == "school" then
		return string.upper(DepotConstants.SCHOOL_CONTRACTS[1].client)
	end
	return string.upper(office.client)
end

-- `crew`: the size of the reader's truck crew (crewOf); nil when they are not in a truck. `places`: the places
-- menu's state (nil: nothing bought, not on a hosted truck, the Office in focus).
function DepotBoardViewModel.board(
	id: string?,
	last: DepotTypes.LastShift?,
	phone: boolean,
	crew: number?,
	places: PlacesInput?
): BoardView
	local input = places or NO_PLACES
	local focus: MapId = DepotBoardViewModel.focusOf(input)
	local contract = contractOf(id)
	local copy = DepotConstants.BOARD_COPY
	local quota = quotaText(crew, phone, focus)
	local shift = ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)
	local rows: { RowView }
	if phone then
		rows = {
			{ label = "CONTRACT", text = quota, hazard = false },
			{ label = "SHIFT", text = `{shift} · {copy.shiftPhone}`, hazard = false },
			{ label = "PAY", text = copy.payPhone, hazard = false },
			{ label = "HAZARD", text = copy.hazardPhone, hazard = true },
		}
	else
		rows = {
			{ label = "CONTRACT", text = quota, hazard = false },
			{ label = "SHIFT", text = `{shift} {copy.shift}`, hazard = false },
			{ label = "PAY", text = copy.pay, hazard = false },
			{ label = "CREW", text = copy.crew, hazard = false },
			{ label = "HAZARD", text = copy.hazard, hazard = true },
			{ label = "NOTES", text = contract.note, hazard = false },
		}
	end
	local number = DepotBoardViewModel.workOrder(contract.id)
	local client = clientOf(focus, contract)
	local officeName = (string.gsub(string.upper(contract.client), "%s+LTD%.?$", ""))
	local buildings: { BuildingView } = {
		placeCard("office", officeName, input, focus),
		placeCard("school", clientOf("school", contract), input, focus),
	}
	for _, soon in SOON do
		table.insert(buildings, {
			name = soon.name,
			site = soon.site,
			photo = soon.photo,
			open = false,
			tag = "SOON",
			map = nil,
			danger = nil,
			focused = false,
			picked = false,
			canPick = false,
			buy = nil,
		})
	end
	local site = DepotMapRules.siteOf(focus)
	local lastView = if last ~= nil then lastOf(last, phone) else nil
	return {
		header = DepotPlaceConstants.TEXT.title,
		pickLine = pickLine(input.role),
		dangerLabel = DepotPlaceConstants.TEXT.danger,
		dangerMax = DepotPlaceConstants.DANGER_MAX,
		focus = focus,
		monster = site.monster,
		client = client,
		chips = {
			{ label = "QUOTA", value = quotaChip(crew, focus), icon = "gloom" },
			{ label = "SHIFT", value = shift, icon = "stopwatch" },
			{ label = "PAY", value = "1 per Gloom", icon = "credits" },
			{ label = "CREW", value = "1–4 employees", icon = "pippaHappy" },
		},
		buildings = buildings,
		tip = if focus == "office" then copy.hazard else site.tip,
		lastLine = if last ~= nil then `Last shift: {lastOf(last, true).lines[1]}` else nil,
		title = copy.title,
		workOrder = if phone then `JOB {number} · {string.upper(contract.client)}` else `JOB {number}`,
		headline = `{string.upper(contract.client)} — {string.upper(DepotConstants.SITE)}`,
		subline = contract.job,
		rows = rows,
		sticky = copy.sticky,
		approved = copy.approved,
		last = lastView,
		dispatchLabel = if phone then "DISPATCH" else copy.dispatchLabel,
		dispatchTitle = copy.dispatchTitle,
		dispatchSteps = if phone then copy.dispatchPhone else copy.dispatchSteps,
		close = if phone then "CLOSE" else copy.close,
	}
end

return DepotBoardViewModel
