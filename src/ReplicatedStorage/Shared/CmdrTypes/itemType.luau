-- Cmdr custom argument type `itemType`. Registered once on the server via `Cmdr:RegisterTypesIn`
-- and auto-replicated to the client (see currencyType.luau for the full explanation).
--
-- The value list derives from the live ItemDefinitions registry. ServerHandler/ClientHandler both
-- run GameItems.init() before Cmdr is set up, so every registered item is present when this enum is
-- built on each peer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDefinitions = require(ReplicatedStorage.Shared.Modules.ItemDefinitions)

return function(registry)
	registry:RegisterType("itemType", registry.Cmdr.Util.MakeEnumType("Item", ItemDefinitions.getValidItemTypes()))
end
