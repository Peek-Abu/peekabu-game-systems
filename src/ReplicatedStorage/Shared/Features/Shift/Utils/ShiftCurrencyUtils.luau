--!strict
--[=[
	ShiftCurrencyUtils: how an amount of company scrip reads (docs/cleanup-crew-lore.md: Morrow & Morrow pays its
	Clearance Associates in company scrip for the Recoverable Assets they bank). Every price tag, load floater, fee plate,
	review and board row writes its amounts through here, so the currency is renamed by changing
	ShiftConstants.CURRENCY_NAME alone. Display only: the amount is the shift's `bonus` counter, not a saved balance. Pure.

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

local ShiftCurrencyUtils = {}

--[=[
	"45 Scrip": `value` rounded to a whole amount, never below zero.
]=]
function ShiftCurrencyUtils.amount(value: number): string
	return `{whole(value)} {ShiftConstants.CURRENCY_NAME}`
end

--[=[
	"+40 Scrip": an amount just earned.
]=]
function ShiftCurrencyUtils.gain(value: number): string
	return `+{ShiftCurrencyUtils.amount(value)}`
end

--[=[
	"SCRIP EARNED": the label over the crew's running total (the fee plate, the review, the depot boards).
]=]
function ShiftCurrencyUtils.earnedLabel(): string
	return `{string.upper(ShiftConstants.CURRENCY_NAME)} EARNED`
end

--[=[
	"+40 SCRIP": an already-formatted gain (`text`, e.g. "+40") as a rubber stamp reads it.
]=]
function ShiftCurrencyUtils.stamp(text: string): string
	return `{text} {string.upper(ShiftConstants.CURRENCY_NAME)}`
end

return ShiftCurrencyUtils
