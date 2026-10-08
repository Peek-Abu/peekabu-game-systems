--!strict
--[=[
	BankConstants: tuning for the per-slot bank container.

	`CAPACITY` is a FLAT total-entry cap over `bank.items` — a stack entry and a unique entry each count
	once, summed across all kinds (unlike Inventory's per-kind `KIND_CAPS`). A stash is one storage
	pool, not kind-partitioned bag space (see the bank design spec, Decision 3). Provisional; retuning is
	an edit here, never a schema change. Bank currency has no bank-specific cap — it reuses
	`CurrencyConstants.MAX_CURRENCY`, the same ceiling a slot's currency already enforces.

	@class BankConstants
]=]

local BankConstants = {
	-- Total entries a slot's bank can hold. Provisional (from the design spec).
	CAPACITY = 90,
}

return BankConstants
