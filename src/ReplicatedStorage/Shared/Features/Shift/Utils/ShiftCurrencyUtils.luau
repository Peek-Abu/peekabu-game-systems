--!strict
--[=[
	ShiftCurrencyUtils: how an amount of pay reads (docs/cleanup-crew-lore.md: Morrow & Morrow pays its Clearance
	Associates a hazard-pay bonus in dollars, "Recovery pay", on the assessed value of the Recoverable Assets they
	bank). Every price tag, load floater, fee plate, review and board row writes its amounts through here, so this is
	the one place the currency's look lives. Display only: the amount is the shift's `bonus` counter, not a saved
	balance. Pure.

	@class ShiftCurrencyUtils
]=]

-- A whole, non-negative amount (NaN reads 0).
local function whole(value: number): number
	if value ~= value then
		return 0
	end
	return math.max(0, math.floor(value + 0.5))
end

local ShiftCurrencyUtils = {
	-- The currency's sign, written before the number.
	SYMBOL = "$",
}

--[=[
	"$45": `value` rounded to a whole amount, never below zero.
]=]
function ShiftCurrencyUtils.amount(value: number): string
	return `{ShiftCurrencyUtils.SYMBOL}{whole(value)}`
end

--[=[
	"+$40": an amount just earned.
]=]
function ShiftCurrencyUtils.gain(value: number): string
	return `+{ShiftCurrencyUtils.amount(value)}`
end

--[=[
	"+$40": an already-formatted number (`text`, e.g. "+40") with the sign kept in front of the "$".
]=]
function ShiftCurrencyUtils.signed(text: string): string
	local sign = string.sub(text, 1, 1)
	if sign == "+" or sign == "-" then
		return `{sign}{ShiftCurrencyUtils.SYMBOL}{string.sub(text, 2)}`
	end
	return `{ShiftCurrencyUtils.SYMBOL}{text}`
end

--[=[
	"EARNED": the label over the crew's running total (the fee plate, the review, the depot boards), which reads
	"EARNED $240" beside the amount.
]=]
function ShiftCurrencyUtils.earnedLabel(): string
	return "EARNED"
end

return ShiftCurrencyUtils
