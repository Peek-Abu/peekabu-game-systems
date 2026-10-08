--!strict
-- Cmdr custom argument type `soulHue`.
--
-- Registered ONCE, on the server, via `Cmdr:RegisterTypesIn(this folder)`; Cmdr replicates it and
-- CmdrClient auto-registers it, so both peers get it with no client-side code (hence a shared folder).
--
-- Deliberately enumerates single HUES, not whole soul-colour ids: a multi-hue soul ("blue-green") is
-- COMPOSED from hues rather than drawn from a fixed set, so the command takes up to MAX_HUES of these
-- and joins them. That keeps autocomplete accurate instead of offering a combinatorial list.
-- The `registry` argument is Cmdr-internal and deliberately left unannotated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationSoulColorRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationSoulColorRegistry)

-- The sentinel is part of the ENUM, not just the command's Default: MakeEnumType rejects any value
-- outside the list, so a bare hue catalog would refuse "-" the moment it is typed — which is how the
-- clear path (`customizationsetsoulcolor <player> - - -`) is spelled. Same reasoning as surfaceTexture's sentinels.
local UNSET = "-"

return function(registry)
	local values = { UNSET }
	for _, hue in CustomizationSoulColorRegistry.hueNames() do
		table.insert(values, hue)
	end
	registry:RegisterType("soulHue", registry.Cmdr.Util.MakeEnumType("SoulHue", values))
end
