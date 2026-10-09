--!strict
--[=[
	MarketplaceConstants: receipt history size, the premium currency's cap, the public field prefix for
	owned passes, and the pass-check retry policy.

	@class MarketplaceConstants
]=]

local MarketplaceConstants = {
	-- Purchase ids remembered per account (oldest dropped first) — the ProfileStore recommendation.
	RECEIPT_HISTORY = 100,
	-- The premium balance's ceiling, enforced by the data layer.
	MAX_PREMIUM = 1_000_000_000,
	-- Owned passes are published as the public field `pass:<key> = true`.
	PASS_FIELD_PREFIX = "pass:",
	-- UserOwnsGamePassAsync attempts on join, and the wait between them (seconds).
	PASS_CHECK_ATTEMPTS = 3,
	PASS_CHECK_RETRY_SECONDS = 2,
}

--[=[
	The public field naming an owned pass.
]=]
function MarketplaceConstants.passField(key: string): string
	return `{MarketplaceConstants.PASS_FIELD_PREFIX}{key}`
end

return MarketplaceConstants
