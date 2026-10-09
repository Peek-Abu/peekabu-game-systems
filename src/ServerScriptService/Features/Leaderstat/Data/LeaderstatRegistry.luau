--!strict
--[=[
	LeaderstatRegistry: the columns of Roblox's player list (design:
	docs/superpowers/specs/2026-10-09-small-services-design.md). A column has a display name, an order
	(lower first) and a reader returning the player's current value (a number or a short string) from
	wherever the game keeps it.

	@class LeaderstatRegistry
]=]

export type LeaderstatValue = number | string

export type LeaderstatDef = {
	order: number,
	read: (player: Player) -> LeaderstatValue?,
}

local defs: { [string]: LeaderstatDef } = {}

local LeaderstatRegistry = {}

function LeaderstatRegistry.register(name: string, def: LeaderstatDef)
	assert(name ~= "", "a leaderstat needs a name")
	assert(defs[name] == nil, `leaderstat "{name}" is already registered`)
	defs[name] = table.freeze(table.clone(def))
end

function LeaderstatRegistry.get(name: string): LeaderstatDef?
	return defs[name]
end

--[=[
	Every column name, by order then name (the order the player list shows them).
]=]
function LeaderstatRegistry.names(): { string }
	local names: { string } = {}
	for name in defs do
		table.insert(names, name)
	end
	table.sort(names, function(a, b)
		local orderA, orderB = defs[a].order, defs[b].order
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a < b
	end)
	return names
end

return LeaderstatRegistry
