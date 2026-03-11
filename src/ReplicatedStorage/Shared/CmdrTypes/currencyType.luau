-- Cmdr custom argument type `currencyType`.
--
-- Registered ONCE, on the server, via `Cmdr:RegisterTypesIn(this folder)`. Cmdr replicates the
-- module into its ReplicatedRoot.Types, and CmdrClient auto-registers replicated types on startup —
-- so the client gets this type with NO client-side registration code (this is why it must live in a
-- shared folder rather than being registered inline on each peer).
--
-- The value list derives from CurrencyConstants, so adding a currency updates autocomplete on both
-- peers with zero changes here. `--!nocheck`: the `registry` argument is Cmdr-internal and untyped;
-- the only real logic (the currency list) stays type-checked in CurrencyConstants.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)

return function(registry)
	registry:RegisterType(
		"currencyType",
		registry.Cmdr.Util.MakeEnumType("Currency", CurrencyConstants.getValidCurrencies())
	)
end
