--!strict
--[=[
	InputActionTracker: which actions are held, and by which physical keys. Pure bookkeeping that tells
	the shell when an action TRANSITIONS: `press` is true only when an action goes from released to held,
	`release` only when its last holding key lets go. Two keys bound to one action (keyboard and gamepad)
	therefore produce one begin and one end.

	Keys are identified by a string (the shell passes the EnumItem's Name), so this module never touches
	Enums or Instances.

	@class InputActionTracker
]=]

export type InputActionTracker = {
	press: (self: InputActionTracker, actionId: string, key: string) -> boolean,
	release: (self: InputActionTracker, actionId: string, key: string) -> boolean,
	isHeld: (self: InputActionTracker, actionId: string) -> boolean,
	held: (self: InputActionTracker) -> { string },
	-- Ends every held action whose context is not in `reachable`; returns the ids it ended.
	dropUnreachable: (
		self: InputActionTracker,
		contextOf: (actionId: string) -> string?,
		reachable: { [string]: boolean }
	) -> { string },
	-- Ends everything (focus lost, service stopping); returns the ids it ended.
	clear: (self: InputActionTracker) -> { string },
}

local InputActionTracker = {}

function InputActionTracker.new(): InputActionTracker
	-- actionId -> the set of keys currently holding it. An action is held iff it has an entry.
	local holders: { [string]: { [string]: boolean } } = {}

	local function sortedIds(): { string }
		local ids: { string } = {}
		for id in holders do
			table.insert(ids, id)
		end
		table.sort(ids)
		return ids
	end

	local tracker: InputActionTracker = {
		press = function(_self, actionId, key)
			local keys = holders[actionId]
			if keys == nil then
				holders[actionId] = { [key] = true }
				return true
			end
			keys[key] = true
			return false
		end,

		release = function(_self, actionId, key)
			local keys = holders[actionId]
			if keys == nil or keys[key] == nil then
				return false
			end
			keys[key] = nil
			if next(keys) == nil then
				holders[actionId] = nil
				return true
			end
			return false
		end,

		isHeld = function(_self, actionId)
			return holders[actionId] ~= nil
		end,

		held = function(_self)
			return sortedIds()
		end,

		dropUnreachable = function(_self, contextOf, reachable)
			local ended: { string } = {}
			for _, id in sortedIds() do
				local context = contextOf(id)
				if context == nil or not reachable[context] then
					holders[id] = nil
					table.insert(ended, id)
				end
			end
			return ended
		end,

		clear = function(_self)
			local ended = sortedIds()
			table.clear(holders)
			return ended
		end,
	}
	return tracker
end

return InputActionTracker
