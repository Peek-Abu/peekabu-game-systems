--!strict
--[=[
	EquipmentEvents: the ByteNet packet contract for equipping and unequipping gear.

	The framework's FIRST gameplay write from the client — everything before it was either read-only
	(charm-sync down to `StateSyncClientStore`) or admin-gated (the debugger). It follows `DebuggerEvents`, which
	is the pattern for a packet set: one shared namespace module both realms require.

	Two packets, both client → server:

	- `EquipItem` (`string`): the UID of the item to equip. **Deliberately carries no slot.** The server
	  derives the destination from the item's own `equipSlot`, so a client cannot ask for a helmet in a
	  weapon slot — the request is not expressible, rather than being expressible and rejected. That is
	  also why drag-and-drop cannot "drop into any slot": the drop target is a hint the UI validates for
	  feel, never an instruction.
	- `UnequipItem` (`string`): the slot id to empty. A slot, not a UID, because emptying a slot is
	  idempotent and cannot act on the wrong item if the two ever disagree.

	Neither packet answers. The result arrives the way every other state change does — the server mutates
	the equipment slice and charm-sync replicates it into `StateSyncClientStore.equipment`, which the paperdoll
	already reads reactively. A request/response round trip would create a second source of truth for
	the same state, and the UI would then have to decide which one to believe.

	Boot-timing note (the same trap `DebuggerEvents` documents): ByteNet's client-side namespace lookup
	uses `FindFirstChild`, so the per-namespace value must exist before the client defines it. The server
	creates it on require; the client `WaitForChild`s below.

	@class EquipmentEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "EquipmentEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local EquipmentEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- client -> server: the UID of the item to equip. The server derives the slot.
			EquipItem = ByteNet.definePacket({
				value = ByteNet.string,
				reliabilityType = "reliable",
			}),
			-- client -> server: the slot id to empty.
			UnequipItem = ByteNet.definePacket({
				value = ByteNet.string,
				reliabilityType = "reliable",
			}),
		},
		-- Empty but present: `defineNamespace` types the closure return as the full `namespaceData`
		-- shape, and the runtime fills `structs` itself and defaults `queries`. This contract declares
		-- neither — notably no QUERIES, because neither packet answers (see the header).
		queries = {},
		structs = {},
	}
end)

return EquipmentEvents
