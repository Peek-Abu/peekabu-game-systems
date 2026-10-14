--!strict
--[=[
	DepotBoardViewModel: the depot's contract board (Figma 2a/2b): tonight's work order (numbered from the contract id,
	the same everywhere), its rows (desktop six, phone four; the HAZARD row marked), the night guard's sticky, the
	returning player's last-shift card (none for a player who has not played) and the dispatch slip; and `fit`, the
	scale that keeps the board on a smaller screen. Pure.

	@class DepotBoardViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftCurrencyUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftCurrencyUtils)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type RowView = { label: string, text: string, hazard: boolean }

export type LastView = {
	title: string,
	rows: { { label: string, value: string } },
	stamp: string,
	met: boolean,
	lines: { string },
}

export type BoardView = {
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

-- The scale the board is drawn at on a `viewport`-sized screen: 1 when it fits, else the tighter side's ratio.
function DepotBoardViewModel.fit(viewport: Vector2, phone: boolean): number
	local board = if phone then BOARD.phone else BOARD.desktop
	local across = (viewport.X - board.marginX) / board.width
	local down = (viewport.Y - board.marginY) / board.height
	return math.clamp(math.min(across, down), DepotBoardViewModel.MIN_SCALE, 1)
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
	local stamp = if last.quotaMet then "QUOTA MET" else "QUOTA MISSED"
	local title = if phone
		then "LAST SHIFT"
		elseif last.truck > 0 then `YOUR LAST SHIFT — TRUCK {last.truck}`
		else "YOUR LAST SHIFT"
	return {
		title = title,
		rows = {
			{ label = "Cleared", value = `{last.cleared} / {last.quota}` },
			{ label = "Earned", value = ShiftCurrencyUtils.amount(last.bonus) },
			{ label = "Times rehired", value = tostring(last.catches) },
			{ label = "Assets recovered", value = `{last.salvage} of {last.offered}` },
		},
		stamp = stamp,
		met = last.quotaMet,
		lines = {
			`Cleared {last.cleared}/{last.quota}  ·  {ShiftCurrencyUtils.gain(last.bonus)}`,
			`Rehired {last.catches}  ·  Assets {last.salvage} of {last.offered}`,
		},
	}
end

function DepotBoardViewModel.board(id: string?, last: DepotTypes.LastShift?, phone: boolean): BoardView
	local contract = contractOf(id)
	local copy = DepotConstants.BOARD_COPY
	local quota = ShiftConstants.QUOTA
	local shift = ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)
	local rows: { RowView }
	if phone then
		rows = {
			{ label = "QUOTA", text = `{quota} {copy.quotaPhone}`, hazard = false },
			{ label = "SHIFT", text = `{shift} · {copy.shiftPhone}`, hazard = false },
			{ label = "PAY", text = `Assets → {ShiftCurrencyUtils.SYMBOL}`, hazard = false },
			{ label = "HAZARD", text = copy.hazardPhone, hazard = true },
		}
	else
		rows = {
			{ label = "QUOTA", text = `{quota} {copy.quota}`, hazard = false },
			{ label = "SHIFT", text = `{shift} {copy.shift}`, hazard = false },
			{
				label = "PAY",
				text = "Every Recoverable Asset you bank pays the crew its assessed value in dollars.",
				hazard = false,
			},
			{ label = "CREW", text = copy.crew, hazard = false },
			{ label = "HAZARD", text = copy.hazard, hazard = true },
			{ label = "NOTES", text = contract.note, hazard = false },
		}
	end
	local number = DepotBoardViewModel.workOrder(contract.id)
	return {
		title = copy.title,
		workOrder = if phone then `WORK ORDER {number} · {string.upper(contract.client)}` else `WORK ORDER {number}`,
		headline = `{string.upper(contract.client)} — {string.upper(DepotConstants.SITE)}`,
		subline = contract.job,
		rows = rows,
		sticky = copy.sticky,
		approved = copy.approved,
		last = if last ~= nil then lastOf(last, phone) else nil,
		dispatchLabel = if phone then "DISPATCH" else copy.dispatchLabel,
		dispatchTitle = copy.dispatchTitle,
		dispatchSteps = if phone then copy.dispatchPhone else copy.dispatchSteps,
		close = if phone then "CLOSE" else copy.close,
	}
end

return DepotBoardViewModel
