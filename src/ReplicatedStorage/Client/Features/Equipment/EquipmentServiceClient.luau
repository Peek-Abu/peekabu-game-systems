--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local EquipmentBonusFormulas = require(ReplicatedStorage.Shared.Features.Equipment.Utils.EquipmentBonusFormulas)
local EquipmentEvents = require(ReplicatedStorage.Shared.Features.Equipment.Net.EquipmentEvents)

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	Reads are a thin facade over `StateSyncClientStore.equipment`, the one client source of truth (populated by
	charm-sync). Reactive UI reads the atom directly via `useAtom`; imperative callers use this
	point-in-time accessor. There is no listener, cache, or signal here — those retired when the
	reactive store became the single client store.
]=]
export type EquipmentServiceClient = {
	dependencies: { string },

	getEquipment: (self: EquipmentServiceClient) -> PlayerDataTypes.Equipment,
	getEquippedInSlot: (self: EquipmentServiceClient, slotId: string) -> PlayerDataTypes.UniqueEntry?,
	getState: (self: EquipmentServiceClient) -> { [string]: any },

	equip: (self: EquipmentServiceClient, uid: string) -> (),
	unequip: (self: EquipmentServiceClient, slotId: string) -> (),
}

local EquipmentServiceClient: EquipmentServiceClient = {
	dependencies = {},

	--[=[
		Gets the local player's equipped gear from the reactive store.
		@return PlayerDataTypes.Equipment -- The equipment wrapper (empty slots until the first sync)
	]=]
	getEquipment = function(_self)
		return StateSyncClientStore.equipment()
	end,

	--[=[
		The UniqueEntry occupying `slotId`, or nil if the slot is empty.
		@param slotId string
		@return PlayerDataTypes.UniqueEntry? -- nil if the slot is empty or before the first sync
	]=]
	getEquippedInSlot = function(self, slotId)
		return self:getEquipment().slots[slotId]
	end,

	--[=[
		Returns DERIVED debugger state: which itemType occupies each slot (the State tab's raw
		"equipment" slice view shows uid/itemType per slot already, but not the summed stat impact) and
		the aggregated equipment bonuses.
		@return { [string]: any } -- Service state
	]=]
	--[=[
		Asks the server to equip an item. **Fire and forget, on purpose.** Nothing is written locally and
		nothing is awaited: the server mutates the equipment slice and charm-sync replicates it into
		`StateSyncClientStore.equipment`, which the paperdoll already reads reactively. Predicting the result here
		would create a second source of truth for the same state.

		Carries no slot — the server derives the destination from the item's own `equipSlot`, so asking
		for the wrong slot is not expressible.
		@param uid string -- The UID of the item to equip
	]=]
	equip = function(_self, uid)
		EquipmentEvents.packets.EquipItem.send(uid)
	end,

	--[=[
		Asks the server to empty an equip slot. Fire and forget, for the same reason as `equip`.
		@param slotId string -- The slot to empty
	]=]
	unequip = function(_self, slotId)
		EquipmentEvents.packets.UnequipItem.send(slotId)
	end,

	getState = function(self)
		local equipment = self:getEquipment()
		local equipped: { [string]: string } = {}
		for slotId, entry in equipment.slots do
			equipped[slotId] = entry.itemType
		end
		return {
			equipped = equipped,
			aggregatedBonuses = EquipmentBonusFormulas.aggregate(equipment),
		}
	end,
}

return EquipmentServiceClient
