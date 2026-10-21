--!strict
--[=[
	CargoInventoryTracker: each player's hotbar inventory (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md):
	four item slots (the hotbar's 2-5), which slot's item is in the hands now, and the hotbar slot chosen with empty
	hands. A slot holds an entry (kind, value, visual and appraisal): a pocketed item is no longer an Instance, and the
	hands slot's entry is the snapshot taken when it went into the hands (the hands item itself is Carry's). Entries are
	handed out as copies.

	@class CargoInventoryTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type CargoEntry = CargoTypes.CargoEntry

export type CargoInventoryTracker = {
	put: (self: CargoInventoryTracker, userId: number, index: number, entry: CargoEntry) -> boolean,
	replace: (self: CargoInventoryTracker, userId: number, index: number, entry: CargoEntry) -> (),
	take: (self: CargoInventoryTracker, userId: number, index: number) -> CargoEntry?,
	get: (self: CargoInventoryTracker, userId: number, index: number) -> CargoEntry?,
	slots: (self: CargoInventoryTracker, userId: number) -> { [number]: CargoEntry },
	firstFree: (self: CargoInventoryTracker, userId: number) -> number?,
	count: (self: CargoInventoryTracker, userId: number) -> number,
	hands: (self: CargoInventoryTracker, userId: number) -> number?,
	setHands: (self: CargoInventoryTracker, userId: number, index: number?) -> (),
	selected: (self: CargoInventoryTracker, userId: number) -> number,
	setSelected: (self: CargoInventoryTracker, userId: number, slot: number) -> (),
	pocketed: (self: CargoInventoryTracker, userId: number) -> { CargoEntry },
	takePocketed: (self: CargoInventoryTracker, userId: number) -> { CargoEntry },
	forget: (self: CargoInventoryTracker, userId: number) -> (),
	clear: (self: CargoInventoryTracker) -> (),
}

type Inventory = { slots: { [number]: CargoEntry }, hands: number?, selected: number }

local CargoInventoryTracker = {}

-- A detached copy of one entry, its visual and appraisal included (a pocketed valuable keeps its grime).
local function clone(entry: CargoEntry): CargoEntry
	return {
		kind = entry.kind,
		value = entry.value,
		visual = if entry.visual ~= nil then table.clone(entry.visual) else nil,
		appraisal = if entry.appraisal ~= nil then table.clone(entry.appraisal) else nil,
		overtime = entry.overtime,
	}
end

local function inSlots(index: number): boolean
	return index == math.floor(index) and index >= 1 and index <= CargoConstants.ITEM_SLOTS
end

function CargoInventoryTracker.new(): CargoInventoryTracker
	local inventories: { [number]: Inventory } = {}

	local function of(userId: number): Inventory
		local inventory = inventories[userId]
		if inventory == nil then
			inventory = { slots = {}, hands = nil, selected = 0 }
			inventories[userId] = inventory
		end
		return inventory
	end

	local tracker: CargoInventoryTracker = {
		-- False when the slot is taken or does not exist.
		put = function(_self, userId, index, entry)
			local inventory = of(userId)
			if not inSlots(index) or inventory.slots[index] ~= nil then
				return false
			end
			inventory.slots[index] = clone(entry)
			return true
		end,

		replace = function(_self, userId, index, entry)
			if inSlots(index) then
				of(userId).slots[index] = clone(entry)
			end
		end,

		-- Empties slot `index` and returns what was in it (nil when empty). The hands mark goes with it.
		take = function(_self, userId, index)
			local inventory = inventories[userId]
			local entry = if inventory ~= nil then inventory.slots[index] else nil
			if inventory == nil or entry == nil then
				return nil
			end
			inventory.slots[index] = nil
			if inventory.hands == index then
				inventory.hands = nil
			end
			return clone(entry)
		end,

		get = function(_self, userId, index)
			local inventory = inventories[userId]
			local entry = if inventory ~= nil then inventory.slots[index] else nil
			return if entry ~= nil then clone(entry) else nil
		end,

		slots = function(_self, userId)
			local result: { [number]: CargoEntry } = {}
			local inventory = inventories[userId]
			if inventory ~= nil then
				for index, entry in inventory.slots do
					result[index] = clone(entry)
				end
			end
			return result
		end,

		firstFree = function(_self, userId)
			local inventory = inventories[userId]
			for index = 1, CargoConstants.ITEM_SLOTS do
				if inventory == nil or inventory.slots[index] == nil then
					return index
				end
			end
			return nil
		end,

		count = function(_self, userId)
			local count = 0
			local inventory = inventories[userId]
			if inventory ~= nil then
				for _ in inventory.slots do
					count += 1
				end
			end
			return count
		end,

		hands = function(_self, userId)
			local inventory = inventories[userId]
			return if inventory ~= nil then inventory.hands else nil
		end,

		setHands = function(_self, userId, index)
			of(userId).hands = index
		end,

		selected = function(_self, userId)
			local inventory = inventories[userId]
			return if inventory ~= nil then inventory.selected else 0
		end,

		setSelected = function(_self, userId, slot)
			of(userId).selected = slot
		end,

		-- The entries not in the hands, in slot order.
		pocketed = function(_self, userId)
			local result: { CargoEntry } = {}
			local inventory = inventories[userId]
			if inventory ~= nil then
				for index = 1, CargoConstants.ITEM_SLOTS do
					local entry = inventory.slots[index]
					if entry ~= nil and inventory.hands ~= index then
						table.insert(result, clone(entry))
					end
				end
			end
			return result
		end,

		-- Empties every slot (the hands item is Carry's to deal with) and returns the pocketed entries.
		takePocketed = function(self, userId)
			local result = self:pocketed(userId)
			local inventory = inventories[userId]
			if inventory ~= nil then
				table.clear(inventory.slots)
				inventory.hands = nil
			end
			return result
		end,

		forget = function(_self, userId)
			inventories[userId] = nil
		end,

		clear = function(_self)
			table.clear(inventories)
		end,
	}
	return tracker
end

return CargoInventoryTracker
