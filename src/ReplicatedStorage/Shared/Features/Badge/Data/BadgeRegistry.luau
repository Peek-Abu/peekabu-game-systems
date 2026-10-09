--!strict
--[=[
	BadgeRegistry: Roblox badges by game key (the ItemRegistry contract: validated, loud at boot), so
	code says `award(player, "first-night")`, never a numeric id.

	@class BadgeRegistry
]=]

export type BadgeDef = { badgeId: number }

local defs: { [string]: BadgeDef } = {}
local keysById: { [number]: string } = {}

local BadgeRegistry = {}

function BadgeRegistry.register(key: string, def: BadgeDef)
	assert(key ~= "", "a badge needs a key")
	assert(def.badgeId >= 1 and def.badgeId == math.floor(def.badgeId), `badge "{key}": bad badgeId`)
	assert(defs[key] == nil, `badge "{key}" is already registered`)
	assert(keysById[def.badgeId] == nil, `badge id {def.badgeId} is already registered`)
	defs[key] = table.freeze(table.clone(def))
	keysById[def.badgeId] = key
end

function BadgeRegistry.get(key: string): BadgeDef?
	return defs[key]
end

function BadgeRegistry.keyFor(badgeId: number): string?
	return keysById[badgeId]
end

function BadgeRegistry.keys(): { string }
	local keys: { string } = {}
	for key in defs do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

return BadgeRegistry
