--!strict
--[=[
	DepotBoardViewModel: the depot's contract board (Figma 2a/2b): tonight's work order (numbered from the contract id,
	the same everywhere), its rows (desktop six, phone four; the HAZARD row marked; the QUOTA row for the crew in the
	reader's truck, `crewOf`, else the range by crew size), the night guard's sticky, the
	returning player's last-shift card (none for a player who has not played) and the dispatch slip; and `fit`, the
	scale that keeps the board on a smaller screen. Pure.

	@class DepotBoardViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local QueueSnapshotUtils = require(ReplicatedStorage.Shared.Features.Queue.Utils.QueueSnapshotUtils)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftCurrencyUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftCurrencyUtils)
local ShiftQuotaFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftQuotaFormulas)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local PaperHudScaleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudScaleViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

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
-- V1: one building card on the Jobs menu. Only tonight's office is open; the planned buildings show as coming soon
-- (their concept photos are stand-ins until the maps exist).
export type BuildingView = {
	name: string,
	site: string,
	photo: "office" | "hospital" | "motel" | "mall",
	open: boolean,
	tag: string,
}

export type BoardView = {
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
	local stamp = if last.quotaMet then "CONTRACT MET" else "CONTRACT MISSED"
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
			{ label = "Times rehired", value = tostring(last.catches) },
			{ label = "Assets recovered", value = `{last.salvage} of {last.offered}` },
		},
		stamp = stamp,
		met = last.quotaMet,
		lines = {
			`Gloom {last.cleared}/{last.quota}  ·  {ShiftCurrencyUtils.gain(earned)}`,
			`Rehired {last.catches}  ·  Assets {last.salvage} of {last.offered}`,
		},
	}
end

-- The size of the crew `userId` is queued with (their truck's pad in the queue snapshot); nil when not in a truck.
function DepotBoardViewModel.crewOf(snapshot: QueueTypes.QueueSnapshot?, userId: number): number?
	local _, pad = QueueSnapshotUtils.padOf(snapshot, userId)
	return if pad ~= nil then #pad.members else nil
end

-- The CONTRACT row: the contract for a crew of `crew`, or the range by crew size when there is no crew yet.
local function quotaText(crew: number?, phone: boolean): string
	local copy = DepotConstants.BOARD_COPY
	if crew == nil then
		local low = ShiftQuotaFormulas.quota(1)
		local high = ShiftQuotaFormulas.quota(#ShiftConstants.QUOTA_BY_CREW)
		return string.format(if phone then copy.quotaPhoneRange else copy.quotaRange, low, high)
	end
	local quota = ShiftQuotaFormulas.quota(crew)
	if phone then
		return string.format(copy.quotaPhoneCrew, quota)
	end
	return if crew <= 1 then string.format(copy.quotaSolo, quota) else string.format(copy.quotaCrew, quota, crew)
end

local BUILDINGS: { BuildingView } = {
	{ name = "ST. AGNES HOSPITAL", site = "West wing night ward", photo = "hospital", open = false, tag = "SOON" },
	{ name = "LANTERN LANE MOTEL", site = "Rooms 1–24", photo = "motel", open = false, tag = "SOON" },
	{ name = "GLIMMER MALL", site = "After hours", photo = "mall", open = false, tag = "SOON" },
}

-- The QUOTA chip: the crew's contract, or the range by crew size.
local function quotaChip(crew: number?): string
	if crew == nil then
		local low = ShiftQuotaFormulas.quota(1)
		local high = ShiftQuotaFormulas.quota(#ShiftConstants.QUOTA_BY_CREW)
		return `{low}–{high} Gloom`
	end
	return `{ShiftQuotaFormulas.quota(crew)} Gloom`
end

-- `crew`: the size of the reader's truck crew (crewOf); nil when they are not in a truck.
function DepotBoardViewModel.board(id: string?, last: DepotTypes.LastShift?, phone: boolean, crew: number?): BoardView
	local contract = contractOf(id)
	local copy = DepotConstants.BOARD_COPY
	local quota = quotaText(crew, phone)
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
	local client = string.upper(contract.client)
	local buildings: { BuildingView } = {
		{
			name = (string.gsub(client, "%s+LTD%.?$", "")),
			site = DepotConstants.SITE,
			photo = "office",
			open = true,
			tag = "TONIGHT!",
		},
	}
	for _, building in BUILDINGS do
		table.insert(buildings, building)
	end
	local lastView = if last ~= nil then lastOf(last, phone) else nil
	return {
		client = client,
		chips = {
			{ label = "QUOTA", value = quotaChip(crew), icon = "gloom" },
			{ label = "SHIFT", value = shift, icon = "stopwatch" },
			{ label = "PAY", value = "1 per Gloom", icon = "credits" },
			{ label = "CREW", value = "1–4 employees", icon = "pippaHappy" },
		},
		buildings = buildings,
		tip = copy.hazard,
		lastLine = if last ~= nil then `Last shift: {lastOf(last, true).lines[1]}` else nil,
		title = copy.title,
		workOrder = if phone then `WORK ORDER {number} · {string.upper(contract.client)}` else `WORK ORDER {number}`,
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
