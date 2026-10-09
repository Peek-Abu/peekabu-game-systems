--!strict
--[=[
	StateSyncWorldStore: named world entries that EVERY client syncs — state about the match or the
	server rather than about one player (the round, a night clock, the power level of a facility).

	One Charm atom holds a frozen map `{ [name]: value }`; every client's charm-sync key
	(`StateSyncConstants.worldKey`) reads it through `getter()`. Each owner publishes under its own name
	(`RoundServiceServer` uses "round") and its client reads the entry back through a decoder, because a
	value arriving over the wire is untyped.

	Values must be plain data charm-sync can ship (WorldTypes: booleans, numbers, strings, and tables of
	those with string or array keys). Build a fresh table for every publish and never mutate one after
	handing it over: the map is diffed by identity, so an edit in place would never sync.

	@class StateSyncWorldStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type WorldMap = { [string]: unknown }

local initial: WorldMap = {}
local world = Charm.atom(table.freeze(initial))

local StateSyncWorldStore = {}

--[=[
	Publishes `value` under `name`, replacing any previous value (a fresh table each time; see the header).
	@param name string
	@param value unknown -- plain data (see the header)
]=]
function StateSyncWorldStore.set(name: string, value: unknown)
	local nextWorld = table.clone(world())
	nextWorld[name] = value
	world(table.freeze(nextWorld))
end

--[=[
	Removes `name`. A no-op when it is absent.
	@param name string
]=]
function StateSyncWorldStore.clear(name: string)
	local current = world()
	if current[name] == nil then
		return
	end
	local nextWorld = table.clone(current)
	nextWorld[name] = nil
	world(table.freeze(nextWorld))
end

function StateSyncWorldStore.get(name: string): unknown
	return world()[name]
end

--[=[
	The charm-sync getter every client's world key reads.
	@return () -> WorldMap
]=]
function StateSyncWorldStore.getter(): () -> WorldMap
	return function(): WorldMap
		return world()
	end
end

return StateSyncWorldStore
