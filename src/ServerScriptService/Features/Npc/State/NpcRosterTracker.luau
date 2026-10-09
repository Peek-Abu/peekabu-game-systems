--!strict
--[=[
	NpcRosterTracker: the live NPCs — an id per model, its kind, lookups both ways and counts per kind.

	@class NpcRosterTracker
]=]

export type Entry = { model: Model, kind: string }

export type NpcRosterTracker = {
	add: (self: NpcRosterTracker, model: Model, kind: string) -> number,
	remove: (self: NpcRosterTracker, id: number) -> boolean,
	get: (self: NpcRosterTracker, id: number) -> Entry?,
	idOf: (self: NpcRosterTracker, model: Model) -> number?,
	ids: (self: NpcRosterTracker) -> { number },
	count: (self: NpcRosterTracker) -> number,
	countOf: (self: NpcRosterTracker, kind: string) -> number,
}

local NpcRosterTracker = {}

function NpcRosterTracker.new(): NpcRosterTracker
	local entries: { [number]: Entry } = {}
	local byModel: { [Model]: number } = {}
	local nextId = 0

	local tracker: NpcRosterTracker = {
		add = function(_self, model, kind)
			local existing = byModel[model]
			if existing ~= nil then
				return existing
			end
			nextId += 1
			entries[nextId] = { model = model, kind = kind }
			byModel[model] = nextId
			return nextId
		end,

		remove = function(_self, id)
			local entry = entries[id]
			if entry == nil then
				return false
			end
			entries[id] = nil
			byModel[entry.model] = nil
			return true
		end,

		get = function(_self, id)
			return entries[id]
		end,

		idOf = function(_self, model)
			return byModel[model]
		end,

		ids = function(_self)
			local list: { number } = {}
			for id in entries do
				table.insert(list, id)
			end
			table.sort(list)
			return list
		end,

		count = function(_self)
			local total = 0
			for _ in entries do
				total += 1
			end
			return total
		end,

		countOf = function(_self, kind)
			local total = 0
			for _, entry in entries do
				if entry.kind == kind then
					total += 1
				end
			end
			return total
		end,
	}
	return tracker
end

return NpcRosterTracker
