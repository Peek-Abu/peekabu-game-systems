--!strict
--[=[
	WorldTypes: the shape of a StateSync world entry as a client receives it.

	The server publishes plain data (StateSyncWorldStore); charm-sync can only ship booleans, numbers,
	strings and tables of those, so that is exactly what a client can receive. Typing the received value
	as this union (rather than `unknown`) is what lets an owner's decoder narrow it field by field with
	`type(...)` checks and no casts (e.g. RoundSnapshotUtils).

	@class WorldTypes
]=]

export type WorldKey = string | number

export type WorldValue = boolean | number | string | WorldTable

export type WorldTable = { [WorldKey]: WorldValue }

export type WorldMap = { [string]: WorldValue }

return {}
