--!strict
-- Cmdr custom argument type `headType`.
--
-- Registered ONCE, on the server, via `Cmdr:RegisterTypesIn(this folder)`. Cmdr replicates the
-- module into its ReplicatedRoot.Types, and CmdrClient auto-registers replicated types on startup —
-- so the client gets this type with NO client-side registration code (this is why it must live in a
-- shared folder rather than being registered inline on each peer).
--
-- The value list derives from CustomizationCosmeticRegistry, so adding a head mode updates autocomplete on both
-- peers with zero changes here. The `registry` argument is Cmdr-internal and
-- deliberately left unannotated — the only real logic (the head-type list) is type-checked in
-- CustomizationCosmeticRegistry.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)

return function(registry)
	registry:RegisterType(
		"headType",
		registry.Cmdr.Util.MakeEnumType("HeadType", CustomizationCosmeticRegistry.headTypes())
	)
end
