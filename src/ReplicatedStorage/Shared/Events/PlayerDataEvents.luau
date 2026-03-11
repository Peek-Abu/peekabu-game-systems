--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

--[=[
	Network events for player data synchronization between client and server.
	@class PlayerDataEvents
]=]
return ByteNet.defineNamespace("PlayerData", function()
	return {
		packets = {
			--[=[
				Event for full player profile updates.
				Sent from server to client when profile data changes.
				@prop PlayerProfileUpdate ByteNetPacket -- Player profile update packet
			]=]
			PlayerProfileUpdate = ByteNet.definePacket({
				name = "PlayerProfileUpdate",
				value = ByteNet.struct({
					userId = ByteNet.uint32,
					currency = ByteNet.struct(PlayerDataTypes.CurrencyStruct),
					inventory = ByteNet.array(ByteNet.struct(PlayerDataTypes.InventoryItemStruct)),
					-- extend with more fields if needed!
				}),
			}),
		},
		queries = {},
		structs = {},
	}
end)
