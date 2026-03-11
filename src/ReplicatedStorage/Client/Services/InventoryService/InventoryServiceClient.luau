--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local ClientStore = require(ReplicatedStorage.Client.State.ClientStore)

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	A thin read-facade over `ClientStore.inventory`, the one client source of truth (populated by
	charm-sync). Reactive UI reads the atom directly via `useAtom`; imperative callers use this
	point-in-time accessor. There is no listener, cache, or signal here — those retired when the
	reactive store became the single client store.
]=]
export type InventoryServiceClient = {
	dependencies: { string },

	getInventory: (self: InventoryServiceClient) -> { PlayerDataTypes.InventoryItem },
	getState: (self: InventoryServiceClient) -> { [string]: any },
}

local InventoryServiceClient: InventoryServiceClient = {
	dependencies = {},

	--[=[
		Gets the local player's inventory from the reactive store.
		@return {PlayerDataTypes.InventoryItem} -- Array of inventory items (empty until the first sync)
	]=]
	getInventory = function(_self)
		return ClientStore.inventory()
	end,

	--[=[
		Returns the current state of the service for debugging.
		@return { [string]: any } -- Service state
	]=]
	getState = function(self)
		local inventory = self:getInventory()
		return {
			itemCount = #inventory,
			items = inventory,
		}
	end,
}

return InventoryServiceClient
