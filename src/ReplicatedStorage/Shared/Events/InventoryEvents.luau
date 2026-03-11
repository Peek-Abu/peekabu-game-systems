--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

--[=[
	Network events for inventory system communication between client and server.
	@class InventoryEvents
]=]
return ByteNet.defineNamespace("Inventory", function()
	return {
		packets = {
			--[=[
				Event for inventory changes (add/remove/update items).
				Sent from server to client to sync inventory state.
				@prop InventoryDelta ByteNetPacket -- Inventory delta packet
			]=]
			InventoryDelta = ByteNet.definePacket({
				name = "InventoryDelta",
				value = ByteNet.struct({
					userId = ByteNet.uint32,
					action = ByteNet.string, -- "add", "remove", "update"
					item = ByteNet.struct(PlayerDataTypes.InventoryItemStruct),
				}),
			}),
			--[=[
				Event for batch inventory changes (add/remove multiple items).
				Sent from server to client to sync multiple inventory changes at once.
				@prop InventoryBatchDelta ByteNetPacket -- Inventory batch delta packet
			]=]
			InventoryBatchDelta = ByteNet.definePacket({
				name = "InventoryBatchDelta",
				value = ByteNet.struct({
					userId = ByteNet.uint32,
					added = ByteNet.array(ByteNet.struct(PlayerDataTypes.InventoryItemStruct)),
					removed = ByteNet.array(ByteNet.struct(PlayerDataTypes.InventoryItemStruct)),
					updated = ByteNet.array(ByteNet.struct(PlayerDataTypes.InventoryItemStruct)),
				}),
			}),
		},
		queries = {},
		structs = {},
	}
end)
