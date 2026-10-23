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
-- A nil zone remains valid for authored layouts. floor/kit/roomType are set only on generated (kit) rooms.
export type Room = {
	id: string,
	name: string,
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	zone: string?,
	floor: number?,
	kit: string?,
	roomType: RoomType?,
	-- Generated maps only: how far from the loading bay by foot, in DEPTH_STUDS steps (OfficeLayoutUtils.depths
	-- reports it in place of the door count).
	depth: number?,
}

-- What kind of workplace a kit room is.
export type RoomType = "pods" | "conference" | "breakout" | "storage" | "server" | "reception"

-- How a doorway is filled: open (no leaf), solid door, or glass door.
export type DoorKind = "open" | "solid" | "glass"

-- A doorway centred at (x, z) on the wall rooms `a` and `b` share. A nil kind means open.
export type Door = {
	a: string,
	b: string,
	x: number,
	z: number,
	width: number,
	kind: DoorKind?,
}

-- patrol: a point on Mr. Harlow's route; rest: where he takes his break (M2).
-- shelf/counter/plant/board are visual-only dressing markers for zone kits (ignored by spawn rolls).
-- cabinet/table are art-only furniture with lootable tops (plaque, meeting-table monitors).
-- closet: a tall supply cabinet against a wall, art-only, a secure hiding spot (Hide's "inside" kind).
-- prop: art-only dressing (sofa, vending machine, wall frame...) named by Marker.art; gameplay ignores it.
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
	| "closet"
	| "prop"

-- A place something can spawn (or a player appears): its id is "<room>.<kind>.<n>".
export type Marker = {
	id: string,
	room: string,
	kind: MarkerKind,
	x: number,
	z: number,
	-- Yaw in radians. The marker faces local -Z; absent means zero.
	rotation: number?,
	-- Art template key override for this marker's furniture (a prop marker must name one); absent means the kind's key.
	art: string?,
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

-- A building-front piece on the exterior wall of `room`, centred at (x, z).
export type Facade = {
	room: string,
	x: number,
	z: number,
	width: number,
	kind: "entrance" | "stairwell",
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
	-- Generated maps only: building-front pieces, and glass wall spans.
	facades: { Facade }?,
	panes: { Segment }?,
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

-- A marker in a kit's local frame (before facing and mirroring). Yaw is local; absent means zero.
export type KitMarker = {
	kind: MarkerKind,
	x: number,
	z: number,
	rotation: number?,
	-- Art template key override (see Marker.art); a prop marker must name one.
	art: string?,
}

-- A hand-authored room. Local frame: x along the front wall from the front-left corner (seen from
-- inside), z into the room. door.offset is the door's centre along the front wall; glass is a span of it.
export type Kit = {
	id: string,
	roomType: RoomType,
	name: string,
	size: "S" | "M" | "L",
	width: number,
	depth: number,
	door: { offset: number, width: number, kind: DoorKind },
	glass: { from: number, to: number }?,
	markers: { KitMarker },
}

-- A kit placed in the world: the room, its front door, the glass pane (if any) and its markers.
export type Placement = {
	room: Room,
	doorX: number,
	doorZ: number,
	doorWidth: number,
	doorKind: DoorKind,
	pane: Segment?,
	markers: { Marker },
}

export type RollOptions = {
	-- The run's contract (Gloom): the map is topped up with piles until it can meet it (OfficeLootUtils.shortfall).
	quota: number,
	-- The shift's A/B variant. Kept for analytics; since the loot loop it no longer changes the roll.
	variant: string,
	-- How many rooms are dirty, and how many piles each dirty room holds (OfficeSpawnUtils step 1).
	dirtyRooms: Range,
	pilesPerRoom: Range,
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
