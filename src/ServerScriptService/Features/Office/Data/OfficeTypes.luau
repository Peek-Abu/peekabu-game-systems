--!strict
--[=[
	OfficeTypes: the Office feature's shapes. Layout coordinates are office-local studs on the floor plane:
	x across, z deep (OfficeConstants.ORIGIN places it in the world). Generated maps may have negative
	coordinates; the loading bay attaches to any exterior side rather than anchoring the map at 0, 0.
	Types only (spec-exempt).

	@class OfficeTypes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

-- An axis-aligned nonoverlapping floor rectangle. Functional workplaces use archetype zones;
-- hallway rectangles are physical corridor links and are excluded from semantic work-room counts.
-- A nil zone remains valid for authored layouts.
export type Room = {
	id: string,
	name: string,
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	zone: string?,
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
-- shelf/counter/plant/board are visual-only dressing markers for zone kits (ignored by spawn rolls).
-- cabinet/table are art-only furniture with lootable tops (plaque, meeting-table monitors).
export type MarkerKind =
	"pile"
	| "item"
	| "desk"
	| "locker"
	| "spawn"
	| "patrol"
	| "rest"
	| "shelf"
	| "counter"
	| "plant"
	| "board"
	| "cabinet"
	| "table"

-- A place something can spawn (or a player appears): its id is "<room>.<kind>.<n>".
export type Marker = {
	id: string,
	room: string,
	kind: MarkerKind,
	x: number,
	z: number,
	-- Yaw in radians. The marker faces local -Z; absent means zero.
	rotation: number?,
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
	-- Visual kit selected by this map; absent uses OfficeConstants.ART_KIT_ID.
	artKit: string?,
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
	-- The run's quota: the map is topped up until it can meet it (OfficeLootUtils.shortfall).
	quota: number,
	-- The shift's A/B variant. Kept for analytics; since the loot loop it no longer changes the roll.
	variant: string,
	piles: Range,
	valuables: Range,
}

-- A pile on a marker, possibly with a cargo item buried under it (and that valuable's rolled appraisal).
export type PilePlan = {
	marker: string,
	kind: string,
	hides: string?,
	appraisal: CargoTypes.AppraisalRoll?,
}

-- An item on a marker; a valuable carries its rolled appraisal.
export type ItemPlan = {
	marker: string,
	kind: string,
	appraisal: CargoTypes.AppraisalRoll?,
}

-- A desk or locker and what it holds (nil = empty), a valuable with its rolled appraisal.
export type SearchPlan = {
	marker: string,
	kind: string?,
	appraisal: CargoTypes.AppraisalRoll?,
}

-- One shift's spawns. `greed` records where the guaranteed greed target went (an item, pile or desk
-- marker); `value` is everything at full cleanliness, valuables at their plain base (OfficeLootUtils.valueOf).
export type SpawnPlan = {
	piles: { PilePlan },
	items: { ItemPlan },
	searchables: { SearchPlan },
	greed: ItemPlan?,
	value: number,
}

return {}
