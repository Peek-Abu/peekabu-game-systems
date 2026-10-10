--!strict
--[=[
	DepotTypes: the Depot feature's shapes (Cleanup Crew spec §3 steps 1-3, §6.2 "Depot"). Layout
	coordinates are depot-local studs on the floor plane, x across, z deep, with DepotLayoutConstants.ORIGIN
	placing 0, 0 in the world. Types only (spec-exempt).

	@class DepotTypes
]=]

-- One night's job, shown on the contract board and on the arrival card. Its id rides the teleport.
export type Contract = {
	id: string,
	client: string,
	job: string,
	note: string,
}

export type CardKind = "drive" | "arrival"

-- A travel card on the wire (DepotEvents.Card). `kind` is checked on the client (DepotStore.show).
export type CardMessage = {
	kind: string,
	title: string,
	body: string,
}

-- The card on screen; `expiresAt` is os.clock() on the client.
export type ShownCard = {
	kind: CardKind,
	title: string,
	body: string,
	expiresAt: number,
}

export type Rect = {
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
}

export type Point = {
	x: number,
	z: number,
}

-- A truck: its bed (the queue pad) centred at (x, z), its cab behind it (+z). Capacity and countdown go
-- onto the pad's Queue attributes.
export type Truck = {
	id: string,
	x: number,
	z: number,
	capacity: number,
	countdown: number,
}

export type Layout = {
	floor: Rect,
	trucks: { Truck },
	contractBoard: Point,
	resultBoard: Point,
	spawns: { Point },
}

return {}
