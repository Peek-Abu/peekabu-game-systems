--!strict
-- Cmdr custom argument type `itemType`. Registered once on the server via `Cmdr:RegisterTypesIn`
-- and auto-replicated to the client (see currencyType.luau for the full explanation).
--
-- The value list derives from the live ItemRegistry registry. ServerHandler/ClientHandler both
-- run ItemContentRegistry.init() before Cmdr is set up, so every registered item is present when this enum is
-- built on each peer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)

return function(registry)
	registry:RegisterType("itemType", registry.Cmdr.Util.MakeEnumType("Item", ItemRegistry.getValidItemTypes()))
end
