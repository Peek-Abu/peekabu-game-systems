--!strict
-- Cmdr custom argument type `statId`.
--
-- Registered ONCE, on the server, via `Cmdr:RegisterTypesIn(this folder)`. Cmdr replicates the
-- module into its ReplicatedRoot.Types, and CmdrClient auto-registers replicated types on startup —
-- so the client gets this type with NO client-side registration code (this is why it must live in a
-- shared folder rather than being registered inline on each peer).
--
-- The value list derives from StatConstants, so adding a stat updates autocomplete on both peers
-- with zero changes here. The `registry` argument is Cmdr-internal and
-- deliberately left unannotated — the only real logic (the stat list) is type-checked in
-- StatConstants.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatConstants = require(ReplicatedStorage.Shared.Features.Stat.Data.StatConstants)

return function(registry)
	registry:RegisterType("statId", registry.Cmdr.Util.MakeEnumType("Stat", StatConstants.STAT_IDS))
end
