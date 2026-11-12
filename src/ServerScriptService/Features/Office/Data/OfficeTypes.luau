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

-- What kind of workplace a kit room is: the Office's types, then the School's (SchoolKitRegistry). The lounge is the
-- School's breakout (Harlow's rest), the fronthall its start room.
export type RoomType =
	"pods"
	| "conference"
	| "breakout"
	| "storage"
	| "server"
	| "reception"
	| "classroom"
	| "gym"
	| "cafeteria"
	| "library"
	| "nurse"
	| "principal"
	| "lounge"
	| "bathroom"
	| "janitor"
	| "fronthall"

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
	-- Radians about +Y (CFrame.Angles(0, yaw, 0)). nil or 0: cab toward +Z, ramp toward -Z; math.pi: cab toward -Z.
	yaw: number?,
}

-- Which way into the building: the loading dock's roller door, or the lobby's glass rotunda.
export type EntranceId = "dock" | "lobby"

-- A teleport entrance between the outside and a room. `outside` is the outside door's centre on the floor; its yaw
-- faces away from the building, where a player arriving outside looks. `exit` is the inside doorway on room
-- `exit.a`'s outer wall, with `exit.b` the entrance id.
export type Entrance = {
	id: EntranceId,
	ground: string,
	outside: { x: number, z: number, yaw: number },
	exit: Door,
}

-- A building-front piece on the exterior wall of `room`, centred at (x, z).
export type Facade = {
	room: string,
	x: number,
	z: number,
	width: number,
	kind: "entrance" | "stairwell" | "elevator",
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
	-- Generated maps only: the outdoor boxes (ids "yard" and "carpark"; never built as rooms) and the teleport entrances.
	grounds: { Room }?,
	entrances: { Entrance }?,
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

--[=[
	An authored site that stands in for the generated office for a run (OfficeServiceServer:useSite; the Training map).
	Its model holds a "Truck" folder with the "TruckBed" (Cargo finds the bed beside the shift folder). Office asks it
	for everything the generated layout would give, and `spawn` places the run's spawns in the shift folder (already
	Cargo's container) and returns what it placed. A site has no grounds, entrances, doors or overtime.
]=]
export type Site = {
	model: Model,
	spawnCFrame: (index: number) -> CFrame,
	route: () -> { Vector3 },
	restPoint: () -> Vector3,
	safeZone: () -> (Vector3, Vector3),
	loadingBay: () -> (Vector3, Vector3),
	whereIs: (position: Vector3) -> (string?, number?, number?),
	truckBed: () -> BasePart?,
	spawn: (folder: Folder) -> SpawnPlan,
}

export type ShellMaterial =
	"plaster"
	| "oak"
	| "rail"
	| "skirt"
	| "frame"
	| "glass"
	| "ceiling"
	| "grid"
	| "carpet"
	| "hallcarpet"
	| "lino"
	| "vinyl"
	-- The School kit's (OfficeConstants.SHELL_THEMES): its halls, its rooms and its floors.
	| "schoolHallFloor"
	| "schoolHallBlock"
	| "schoolHallBand"
	| "schoolHallStripe"
	| "schoolRoomPaint"
	| "schoolRoomBand"
	| "schoolRoomRail"
	| "schoolCarpet"
	| "schoolMaple"
	| "schoolChecker"
	| "schoolTile"
-- `side`: a wall box's face (-1 / +1, its offset from the wall line; OfficeShellUtils.wall), nil for other boxes.
export type ShellBox = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: ShellMaterial,
	collide: boolean,
	side: number?,
}

-- A kit's shell look (OfficeConstants.SHELL_THEMES): the materials a wall face looking into a hallway or into a room
-- trades for its own, and the floor by room type (OfficeArtKeyUtils.roomType).
export type ShellTheme = {
	hallway: { [ShellMaterial]: ShellMaterial },
	rooms: { [ShellMaterial]: ShellMaterial },
	floors: { [string]: ShellMaterial },
}

-- A ceiling troffer panel (layout x/z); lit ones glow and carry a light.
export type LightPanel = { x: number, z: number, lit: boolean, rotated: boolean, brightness: number }

-- A shadow-casting fill light.
export type FillLight = { position: Vector3, brightness: number, range: number, color: Color3, shadows: boolean }

return {}
