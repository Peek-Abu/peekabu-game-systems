--!strict
--[=[
	CargoPocketTracker: what each player has in their pockets (Cleanup Crew spec §4: two slots). A pocketed
	item is no longer an Instance, only its kind and value; it becomes one again when it is scattered. Lists
	are handed out as copies.

	@class CargoPocketTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type CargoEntry = CargoTypes.CargoEntry

export type CargoPocketTracker = {
	add: (self: CargoPocketTracker, userId: number, entry: CargoEntry) -> boolean,
	list: (self: CargoPocketTracker, userId: number) -> { CargoEntry },
	count: (self: CargoPocketTracker, userId: number) -> number,
	take: (self: CargoPocketTracker, userId: number) -> { CargoEntry },
	clear: (self: CargoPocketTracker) -> (),
}

local CargoPocketTracker = {}

local function copy(list: { CargoEntry }): { CargoEntry }
	local result: { CargoEntry } = {}
	for _, entry in list do
		table.insert(result, { kind = entry.kind, value = entry.value })
	end
	return result
end

function CargoPocketTracker.new(): CargoPocketTracker
	local pockets: { [number]: { CargoEntry } } = {}

	local tracker: CargoPocketTracker = {
		-- False when the pockets are full.
		add = function(_self, userId, entry)
			local list = pockets[userId]
			if list == nil then
				list = {}
				pockets[userId] = list
			end
			if #list >= CargoConstants.POCKET_SLOTS then
				return false
			end
			table.insert(list, { kind = entry.kind, value = entry.value })
			return true
		end,

		list = function(_self, userId)
			return copy(pockets[userId] or {})
		end,

		count = function(_self, userId)
			local list = pockets[userId]
			return if list ~= nil then #list else 0
		end,

		-- Empties the player's pockets and returns what was in them.
		take = function(_self, userId)
			local list = pockets[userId] or {}
			pockets[userId] = nil
			return copy(list)
		end,

		clear = function(_self)
			table.clear(pockets)
		end,
	}
	return tracker
end

return CargoPocketTracker
