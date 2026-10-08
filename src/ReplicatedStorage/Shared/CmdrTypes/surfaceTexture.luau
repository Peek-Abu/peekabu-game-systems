--!strict
-- Cmdr custom argument type `surfaceTexture`.
--
-- Registered ONCE, on the server, via `Cmdr:RegisterTypesIn(this folder)`; Cmdr replicates it and
-- CmdrClient auto-registers it, so both peers get it with no client-side code (hence a shared folder).
--
-- Textures are a SINGLE catalog shared by every surface channel, so a static enum is accurate here —
-- unlike patterns, whose valid ids depend on which channel you are setting, so those stay a plain
-- string validated server-side. The `registry` argument is Cmdr-internal and deliberately left unannotated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)

-- The two sentinels are part of the ENUM, not just the help text: MakeEnumType REJECTS any value
-- outside the list, so a bare catalog would make `customizationsetsurface ... none` fail at the Cmdr boundary
-- before the command ever ran. They lead the list so both autocomplete first.
local KEEP = "-"
local CLEAR = "none"

return function(registry)
	local values = { KEEP, CLEAR }
	for _, id in CustomizationCosmeticRegistry.surfaceIds("texture") do
		table.insert(values, id)
	end
	registry:RegisterType("surfaceTexture", registry.Cmdr.Util.MakeEnumType("SurfaceTexture", values))
end
