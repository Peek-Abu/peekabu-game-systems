--!strict
--[=[
	OfficeTypes: the Office feature's shapes. Layout coordinates are office-local studs on the floor plane:
	x across, z deep, the loading bay's corner at 0, 0 (OfficeConstants.ORIGIN places it in the world).
	Types only (spec-exempt).

	@class OfficeTypes
]=]

-- An axis-aligned rectangular room.
export type Room = {
	id: string,
	name: string,
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
}

-- A doorway centred at (x, z) on the wall rooms `a` and `b` share.
export type Door = {
	a: string,
	b: string,
	x: number,
	z: number,
	width: number,
}

-- patrol: a point on Mr. Harlow's route; rest: where he takes his break (M2).
export type MarkerKind = "pile" | "item" | "desk" | "locker" | "spawn" | "patrol" | "rest"

-- A place something can spawn (or a player appears): its id is "<room>.<kind>.<n>".
export type Marker = {
	id: string,
	room: string,
	kind: MarkerKind,
	x: number,
	z: number,
}

-- The truck bed's footprint (the banking zone) and the time clock beside it, inside the start room.
export type Truck = {
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	clockX: number,
	clockZ: number,
}

export type Layout = {
	startRoom: string,
	rooms: { Room },
	doors: { Door },
	markers: { Marker },
	truck: Truck,
	-- Mr. Harlow's patrol route: patrol marker ids in walking order (a loop), and his rest marker (M2).
	route: { string },
	rest: string,
}

export type Edge = "minX" | "maxX" | "minZ" | "maxZ"

-- One straight piece of wall, from (x1, z1) to (x2, z2), along a room edge.
export type Segment = {
	x1: number,
	z1: number,
	x2: number,
	z2: number,
}

export type Range = {
	min: number,
	max: number,
}

export type RollOptions = {
	quota: number,
	-- "B" hides some salvage under piles; "A" exposes it all.
	variant: string,
	piles: Range,
	salvage: Range,
}

-- A pile on a marker, possibly with a cargo item hidden under it.
export type PilePlan = {
	marker: string,
	kind: string,
	hides: string?,
}

export type ItemPlan = {
	marker: string,
	kind: string,
}

-- A desk or locker and what it holds (nil = empty).
export type SearchPlan = {
	marker: string,
	kind: string?,
}

-- One shift's spawns. `greed` records where the guaranteed greed target went (an item, pile or desk
-- marker); `trashValue` is the open-floor trash plus the dust bags the piles make.
export type SpawnPlan = {
	piles: { PilePlan },
	items: { ItemPlan },
	searchables: { SearchPlan },
	greed: ItemPlan?,
	trashValue: number,
}

return {}
