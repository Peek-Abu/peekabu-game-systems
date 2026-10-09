--!strict
--[=[
	InventoryPlacementUtils: the pure merge-then-spill planner for adding a quantity of a stackable itemType
	to a `{ InventoryEntry }` array, shared by every container that stores the same entry union.

	Extracted from `InventoryServiceServer.planStackPlacement` so a second container (Bank) reuses the
	exact placement math. The ONE thing containers differ on — whether there is room for more entries —
	is injected as a `hasRoom` callback (Inventory checks its per-kind cap; Bank checks a flat total
	cap). The per-itemType `maxStacks` bound stays inside: it is intrinsic to the item definition, not a
	container policy. Does not mutate `items` — it returns a plan the caller applies.

	@class InventoryPlacementUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

local InventoryPlacementUtils = {}

--[=[
	The plan: which existing stacks to top up (index -> new quantity) and which new stacks to open (a
	quantity each), or a refusal `reason` if the add does not fit.
	@interface StackPlacement
]=]
export type StackPlacement = {
	ok: boolean,
	updates: { [number]: number }?,
	newStacks: { number }?,
	reason: string?,
}

--[=[
	A container's room policy: given the current entries, the kind, and how many NEW stack entries the
	add would open, is there room? Returns `(false, reason)` to refuse.
]=]
export type RoomCheck = (
	currentItems: { PlayerDataTypes.InventoryEntry },
	kind: string,
	newEntriesNeeded: number
) -> (boolean, string?)

--[=[
	Plans adding `count` of a stackable `itemType`: merge into existing same-itemType stacks up to
	`stackMax`, then open new stacks (bounded by the itemType's `maxStacks` and the container's
	`hasRoom`). Returns a plan; never mutates `items`.
	@param items { PlayerDataTypes.InventoryEntry }
	@param itemType string
	@param count number
	@param stackMax number
	@param maxStacks number?
	@param kind string
	@param hasRoom RoomCheck -- the container's entry-capacity policy
	@return StackPlacement
]=]
function InventoryPlacementUtils.planStackPlacement(
	items: { PlayerDataTypes.InventoryEntry },
	itemType: string,
	count: number,
	stackMax: number,
	maxStacks: number?,
	kind: string,
	hasRoom: RoomCheck
): StackPlacement
	local updates: { [number]: number } = {}
	local existingStacks = 0
	local remaining = count

	for index, entry in items do
		if entry.itemType ~= itemType then
			continue
		end
		existingStacks += 1
		if remaining <= 0 then
			continue
		end
		-- The caller only reaches here for a stackable itemType, so every matching entry is a StackEntry.
		local stackEntry = entry :: PlayerDataTypes.StackEntry -- caller guarantees stackable, see comment above
		local space = stackMax - stackEntry.quantity
		if space > 0 then
			local take = math.min(space, remaining)
			updates[index] = stackEntry.quantity + take
			remaining -= take
		end
	end

	local newStacks: { number } = {}
	if remaining > 0 then
		local stacksNeeded = math.ceil(remaining / stackMax)
		if maxStacks and existingStacks + stacksNeeded > maxStacks then
			return {
				ok = false,
				reason = `"{itemType}" would need {existingStacks + stacksNeeded} stacks, exceeding maxStacks ({maxStacks})`,
			}
		end

		local roomOk, roomReason = hasRoom(items, kind, stacksNeeded)
		if not roomOk then
			return { ok = false, reason = roomReason }
		end

		local left = remaining
		for _ = 1, stacksNeeded do
			local quantity = math.min(stackMax, left)
			table.insert(newStacks, quantity)
			left -= quantity
		end
	end

	return { ok = true, updates = updates, newStacks = newStacks }
end

return InventoryPlacementUtils
