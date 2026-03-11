--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

--[=[
	Network events for currency system communication between client and server.
	@class CurrencyEvents
]=]
return ByteNet.defineNamespace("Currency", function()
	return {
		packets = {
			--[=[
				Event for currency changes.
				Sent from server to client to sync currency state.
				@prop CurrencyUpdate ByteNetPacket -- Currency update packet
			]=]
			CurrencyUpdate = ByteNet.definePacket({
				name = "CurrencyUpdate",
				value = ByteNet.struct({
					currencyType = ByteNet.string,
					newAmount = ByteNet.uint32,
					delta = ByteNet.int32,
				}),
			}),
		},
		queries = {},
		structs = {},
	}
end)
