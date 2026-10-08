--!strict
-- Cmdr custom argument type `surfaceChannel`.
--
-- Registered ONCE, on the server, via `Cmdr:RegisterTypesIn(this folder)`; Cmdr replicates it and
-- CmdrClient auto-registers it, so both peers get it with no client-side code (hence a shared folder).
--
-- The value list derives from CustomizationCosmeticRegistry, so adding a surface channel updates autocomplete on
-- both peers with zero changes here. The `registry` argument is Cmdr-internal and
-- deliberately left unannotated — the real logic (the channel list) is type-checked in
-- CustomizationCosmeticRegistry.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)

return function(registry)
	registry:RegisterType(
		"surfaceChannel",
		registry.Cmdr.Util.MakeEnumType("SurfaceChannel", CustomizationCosmeticRegistry.surfaceChannelKeys())
	)
end
