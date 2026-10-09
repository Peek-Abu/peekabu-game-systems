--!strict
-- Cmdr custom argument type `titleId`.
--
-- Registered ONCE, on the server, via `Cmdr:RegisterTypesIn(this folder)` (AdminServiceServer);
-- Cmdr replicates the module and CmdrClient auto-registers replicated types on startup — so the
-- client gets this type with NO client-side registration code (why it lives in a shared folder).
--
-- The value list derives from TitleRegistry (the 5b cosmetics precedent), so adding a title
-- updates autocomplete on both peers with zero changes here. The `registry` argument is
-- Cmdr-internal and deliberately left unannotated — the only real logic (the title-id list) is
-- type-checked in TitleRegistry.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitleRegistry = require(ReplicatedStorage.Shared.Features.Title.Data.TitleRegistry)

return function(registry)
	registry:RegisterType("titleId", registry.Cmdr.Util.MakeEnumType("Title", TitleRegistry.getAllIds()))
end
