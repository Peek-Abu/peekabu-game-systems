--!strict
--[=[
	ShiftCurrencyUtils: how pay and the contract read (docs/superpowers/specs/
	2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §5). Morrow & Morrow pays its Clearance Associates in Gleam,
	refined Gloom: the one currency players see, written as the word after the number ("45 Gleam"; no sign, no emoji).
	The contract is Gloom removed ("Gloom 340 / 500", "Remove 500 Gloom"). Every price tag, load floater, fee plate,
	review and board row writes its amounts through here, so this is the one place the look lives; the words are
	ShiftConstants.CURRENCY_NAME and CONTRACT_UNIT. Display only: no saved balance yet. Pure.

	@class ShiftCurrencyUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

-- A whole, non-negative amount (NaN reads 0).
local function whole(value: number): number
	if value ~= value then
		return 0
	end
	return math.max(0, math.floor(value + 0.5))
end

local ShiftCurrencyUtils = {
	-- The currency's name, written after the number.
	NAME = ShiftConstants.CURRENCY_NAME,
}

--[=[
	"45 Gleam": `value` rounded to a whole amount, never below zero.
]=]
function ShiftCurrencyUtils.amount(value: number): string
	return `{whole(value)} {ShiftCurrencyUtils.NAME}`
end

--[=[
	"??? Gleam": a value not appraised yet.
]=]
function ShiftCurrencyUtils.unknown(): string
	return `??? {ShiftCurrencyUtils.NAME}`
end

--[=[
	"+40 Gleam": an amount just earned.
]=]
function ShiftCurrencyUtils.gain(value: number): string
	return `+{ShiftCurrencyUtils.amount(value)}`
end

--[=[
	"+40 Gleam": an already-formatted number (`text`, e.g. "+40") with the currency named after it.
]=]
function ShiftCurrencyUtils.signed(text: string): string
	return `{text} {ShiftCurrencyUtils.NAME}`
end

--[=[
	"Gloom 340 / 500": the contract's progress, as the canister gauge and the HUD read it.
]=]
function ShiftCurrencyUtils.gloom(removed: number, contract: number): string
	return `{ShiftConstants.CONTRACT_UNIT} {whole(removed)} / {whole(contract)}`
end

--[=[
	"Remove 500 Gloom": the contract as the depot board and the work order post it.
]=]
function ShiftCurrencyUtils.contract(contract: number): string
	return `Remove {whole(contract)} {ShiftConstants.CONTRACT_UNIT}`
end

--[=[
	"EARNED": the label over the crew's running total (the fee plate, the review, the depot boards), which reads
	"EARNED 240 Gleam" beside the amount.
]=]
function ShiftCurrencyUtils.earnedLabel(): string
	return "EARNED"
end

return ShiftCurrencyUtils
