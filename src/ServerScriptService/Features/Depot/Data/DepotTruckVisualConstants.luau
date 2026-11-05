--!strict
--[=[
	DepotTruckVisualConstants: the crew truck (v3, look A "Night Shift" at size B "Moving Van",
	characters/truck/build_truck_v3.py; docs/superpowers/specs/2026-11-04-truck-size-design.md) in DECK
	SPACE: studs from the middle of the bed's top face, +Y up, +Z toward the cab, -Z the open back and the ramp. The
	bed (16 x DECK x 24, the queue pad / banking bed) is the floor; everything here sits round it, so the bed's
	whole footprint stays clear inside the box (walls outside x = +-8, the doorway 16 wide and under the roll drum).

	- COLLISION: native parts the art never replaces: box walls, roof, arch posts, the cab and the ramp (a wedge from
	  the ground to the bed's back edge). The cab's (`occludes`) is also the camera's wall there. A collidable part is always queryable, so they are parented to the bed:
	  the load prompt's sight check (a ray to the bed that may hit the bed or its descendants) still sees the bed
	  through the box.
	- SHELL: the camera's walls. The default camera (Popper) only stops at opaque parts (older clients: also
	  collidable ones), and every hit
	  part it cannot stop at is ignored WITH its descendants for the rest of that ray: the meshes never collide and
	  the collision is invisible, so the camera used to pass straight through the box. Each shell part is an opaque
	  core inside its art piece (`inside`, a GRAYBOX name; the mesh pieces share its outline) with its inner face
	  just behind the visible lining, so the camera stops in front of the lining; and
	  the floor's core over the deck so a ray meets it before the invisible bed. Parented to the bed like COLLISION.
	- CLOCK: the time clock (characters/truck/build_timeclock.py, template CLOCK_TEMPLATE_PATH) hangs on the inside
	  of the front wall at CLOCK_MOUNT (its back centre, facing the open back); PAPERWORK frames the office's
	  interactable parts there: the clock's hit box round the art, and the overtime sheet on the other side.
	- GRAYBOX: the fallback look when the approved template (TEMPLATE_PATH, RuntimeApproved) is missing.
	- LIVERY: the side line on the band's outer faces (BAND_PIECE on the art, BandLeft/BandRight on the graybox).
	- SOCKETS / INTERIOR_SLOTS: the attachments the template carries for truck parts (crew hosting batch 6; unused
	  until then). Interior slots are on the walls and ceiling only: the box's floor is the bed, always clear.

	Static data (checked by DepotTruckVisualConstants.spec).

	@class DepotTruckVisualConstants
]=]

export type Shape = "Block" | "Cylinder" | "Wedge"

export type Piece = {
	name: string,
	centre: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Shape,
}

export type Solid = {
	name: string,
	centre: Vector3,
	size: Vector3,
	shape: Shape,
	-- The camera treats this invisible proxy as solid (CameraOccluderConstants): for a piece with no SHELL core in it.
	occludes: boolean?,
}

export type LiveryFace = { piece: string, face: Enum.NormalId }

local TEAL = Color3.fromRGB(31, 110, 102)
local IVORY = Color3.fromRGB(229, 221, 197)
local FLOOR = Color3.fromRGB(216, 193, 137)
local GRAPHITE = Color3.fromRGB(46, 53, 54)
local GLASS = Color3.fromRGB(62, 94, 102)
local RAMP_GREY = Color3.fromRGB(126, 138, 140)
local SCANNER_IDLE = Color3.fromRGB(36, 112, 76)
local BAND = Color3.fromRGB(123, 63, 242)

local function piece(
	name: string,
	centre: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Shape?
): Piece
	return {
		name = name,
		centre = centre,
		size = size,
		color = color,
		material = material or Enum.Material.SmoothPlastic,
		shape = shape or "Block",
	}
end

local GRAYBOX: { Piece } = {
	piece("BoxSideLeft", Vector3.new(-8.215, 5.185, 0.3), Vector3.new(0.57, 10.97, 24.4), IVORY),
	piece("BoxSideRight", Vector3.new(8.215, 5.185, 0.3), Vector3.new(0.57, 10.97, 24.4), IVORY),
	piece("BoxFront", Vector3.new(0, 5.185, 12.22), Vector3.new(17, 10.97, 0.56), IVORY),
	piece("BoxRoof", Vector3.new(0, 10.3975, 0.3), Vector3.new(17.4, 0.795, 24.9), TEAL),
	piece("BoxFloor", Vector3.new(0, 0.03, 0), Vector3.new(15.9, 0.06, 23.9), FLOOR),
	piece("RollDrum", Vector3.new(0, 9.62, -11.45), Vector3.new(15.8, 0.9, 0.9), GRAPHITE, nil, "Cylinder"),
	piece("ScannerPostLeft", Vector3.new(-8.6, 4.735, -12.3), Vector3.new(1.2, 10.67, 1.3), TEAL),
	piece("ScannerPostRight", Vector3.new(8.6, 4.735, -12.3), Vector3.new(1.2, 10.67, 1.3), TEAL),
	piece("ScannerBeam", Vector3.new(0, 10.92, -12.3), Vector3.new(18.4, 1.7, 1.5), TEAL),
	piece("ScannerLight", Vector3.new(0, 10.94, -13.1), Vector3.new(9.6, 0.55, 0.14), SCANNER_IDLE, Enum.Material.Neon),
	piece("CabBody", Vector3.new(0, 3.78, 16.14), Vector3.new(12.48, 9.72, 7.08), TEAL),
	piece("CabWindows", Vector3.new(0, 5.88, 19.7), Vector3.new(10.08, 3.12, 0.1), GLASS, Enum.Material.Glass),
	piece("Chassis", Vector3.new(0, -1, 3.53), Vector3.new(10.4, 1.2, 30.86), GRAPHITE),
	piece("Ramp", Vector3.new(0, -1.5, -14), Vector3.new(9.4, 3, 4), RAMP_GREY, nil, "Wedge"),
	piece("BandLeft", Vector3.new(-8.525, 5.2, 0.15), Vector3.new(0.07, 2.6, 23.8), BAND),
	piece("BandRight", Vector3.new(8.525, 5.2, 0.15), Vector3.new(0.07, 2.6, 23.8), BAND),
}
-- The tandem rear axles under the box and the front axle under the cab (x: the wheel's centre).
for _, axle in { { z = -6, x = 7.7 }, { z = -9.3, x = 7.7 }, { z = 15.72, x = 6.9 } } do
	for _, side in { -1, 1 } do
		table.insert(
			GRAYBOX,
			piece("Tire", Vector3.new(side * axle.x, -1.5, axle.z), Vector3.new(1.6, 3, 3), GRAPHITE, nil, "Cylinder")
		)
	end
end

local function solid(name: string, centre: Vector3, size: Vector3, shape: Shape, occludes: boolean?): Solid
	return { name = name, centre = centre, size = size, shape = shape, occludes = occludes }
end

local COLLISION: { Solid } = {
	solid("TruckWallLeft", Vector3.new(-8.25, 5.3, 0.3), Vector3.new(0.5, 10.6, 24.4), "Block"),
	solid("TruckWallRight", Vector3.new(8.25, 5.3, 0.3), Vector3.new(0.5, 10.6, 24.4), "Block"),
	solid("TruckWallFront", Vector3.new(0, 5.3, 12.25), Vector3.new(17, 10.6, 0.5), "Block"),
	solid("TruckRoof", Vector3.new(0, 10.42, 0.3), Vector3.new(17.4, 0.75, 24.9), "Block"),
	solid("TruckArchPostLeft", Vector3.new(-8.6, 5.035, -12.3), Vector3.new(1.2, 10.07, 1.3), "Block"),
	solid("TruckArchPostRight", Vector3.new(8.6, 5.035, -12.3), Vector3.new(1.2, 10.07, 1.3), "Block"),
	-- The cab has no shell core (its art is not a plain box), so its proxy is the camera's wall: without it the camera
	-- went through the cab, and stood inside or behind it, whenever a player had the truck's front behind them.
	solid("TruckCab", Vector3.new(0, 3.4, 16.35), Vector3.new(12.8, 10.6, 7.7), "Block", true),
	-- The Luton (the box running on over the cab roof) sits on the cab: the camera's wall up there too.
	solid("TruckLuton", Vector3.new(0, 9.75, 14.925), Vector3.new(17, 2.1, 4.85), "Block", true),
	-- A wedge rises toward +Z: its tall face meets the bed's back edge, its foot is on the ground RAMP_LENGTH out.
	solid("TruckRamp", Vector3.new(0, -1.5, -14), Vector3.new(9.4, 3, 4), "Wedge"),
}

-- A camera shell core: always a block, inside the GRAYBOX (or, for the clock, CLOCK_GRAYBOX) piece named `inside`.
-- The clock's back centre on the front wall's lining (z 7.94), facing the open back (deck space, unrotated).
local CLOCK_MOUNT = Vector3.new(-3, 3.6, 11.94)

export type ShellCore = { name: string, centre: Vector3, size: Vector3, inside: string }

-- Each core's inner face sits just behind the visible inner surface (the mesh's lining: x +-7.93, z 11.94, y 10), so
-- the camera stops in front of the lining, not inside the wall; the walls reach below the deck so no ray slips
-- through the seam with the floor; the rest stays clear of the outer faces' bevels.
local SHELL: { ShellCore } = {
	{
		name = "TruckShellLeft",
		centre = Vector3.new(-8.165, 5.175, 0.25),
		size = Vector3.new(0.43, 10.75, 24.26),
		inside = "BoxSideLeft",
	},
	{
		name = "TruckShellRight",
		centre = Vector3.new(8.165, 5.175, 0.25),
		size = Vector3.new(0.43, 10.75, 24.26),
		inside = "BoxSideRight",
	},
	{
		name = "TruckShellFront",
		centre = Vector3.new(0, 5.175, 12.165),
		size = Vector3.new(16.76, 10.75, 0.43),
		inside = "BoxFront",
	},
	{
		name = "TruckShellRoof",
		centre = Vector3.new(0, 10.2575, 0.3),
		size = Vector3.new(16.8, 0.475, 24.3),
		inside = "BoxRoof",
	},
	-- The scanner arch's posts at the open back's corners: without them the camera peeks round the walls' ends.
	{
		name = "TruckShellPostLeft",
		centre = Vector3.new(-8.6, 4.735, -12.3),
		size = Vector3.new(0.48, 9.95, 0.58),
		inside = "ScannerPostLeft",
	},
	{
		name = "TruckShellPostRight",
		centre = Vector3.new(8.6, 4.735, -12.3),
		size = Vector3.new(0.48, 9.95, 0.58),
		inside = "ScannerPostRight",
	},
	-- The roll-up door's drum over the doorway: a block inscribed in it, so the camera cannot slip out above the door.
	{
		name = "TruckShellDrum",
		centre = Vector3.new(0, 9.62, -11.45),
		size = Vector3.new(15.6, 0.6, 0.6),
		inside = "RollDrum",
	},
	-- The time clock's housing stands 0.6 off the wall: a core inside it (CLOCK_GRAYBOX's ClockBody, clock space).
	{
		name = "TruckShellClock",
		centre = CLOCK_MOUNT + Vector3.new(0, 0, -0.3),
		size = Vector3.new(1.1, 1.5, 0.45),
		inside = "ClockBody",
	},
	{
		name = "TruckShellFloor",
		centre = Vector3.new(0, 0.03, 0),
		size = Vector3.new(15.8, 0.03, 23.8),
		inside = "BoxFloor",
	},
}

export type Paperwork = "clock" | "sheet"
export type Frame = { centre: Vector3, size: Vector3 }

local PAPERWORK: { [Paperwork]: Frame } = {
	-- The clock's hit box round the housing and its card rack (clock space x -0.65..1.55, y -0.85..1.2).
	clock = { centre = CLOCK_MOUNT + Vector3.new(0.45, 0.15, -0.45), size = Vector3.new(2.4, 2.1, 0.8) },
	-- The overtime sheet: a clipboard on the wall across the doorway's middle from the clock.
	sheet = { centre = Vector3.new(3.2, 3.8, 11.88), size = Vector3.new(1.2, 1.6, 0.12) },
}

local CLOCK_GRAYBOX: { Piece } = {
	piece("ClockBody", Vector3.new(0, 0, -0.3), Vector3.new(1.3, 1.7, 0.6), TEAL),
	piece("ClockFace", Vector3.new(0, 0.3, -0.625), Vector3.new(0.9, 0.9, 0.05), IVORY),
	piece("ClockCards", Vector3.new(1.2, -0.15, -0.15), Vector3.new(0.7, 1.2, 0.3), TEAL),
}

-- The art's band strip: one mesh across both sides, so its Left/Right faces are the band's outer faces.
local BAND_PIECE = "BoxBand"

local LIVERY_FACES: { LiveryFace } = {
	{ piece = BAND_PIECE, face = Enum.NormalId.Left },
	{ piece = BAND_PIECE, face = Enum.NormalId.Right },
	{ piece = "BandLeft", face = Enum.NormalId.Left },
	{ piece = "BandRight", face = Enum.NormalId.Right },
}

-- Attachment names on the template (characters/truck/v2/Truck_v2.json has where each one sits).
local SOCKETS = {
	roof = "Socket_Roof",
	front = "Socket_Front",
	sideL = "Socket_SideL",
	sideR = "Socket_SideR",
	mirror = "Socket_Mirror",
	horn = "Socket_Horn",
}

local INTERIOR_SLOTS = {
	ceiling = "Interior_Ceiling",
	wallL = "Interior_WallL",
	wallR = "Interior_WallR",
}

return table.freeze({
	-- ReplicatedStorage path of the approved art (Model, attribute RuntimeApproved = true), pivoted at deck space's
	-- origin, facing +Z.
	TEMPLATE_PATH = table.freeze({ "Assets", "CleanupCrew", "Truck" }),
	APPROVED_ATTRIBUTE = "RuntimeApproved",
	ART_NAME = "TruckArt",
	ART_KIND_ATTRIBUTE = "TruckArtKind",
	-- The bed height the art is modelled for (the ground is at y = -DECK). Depot and office beds are this tall.
	DECK = 3,
	BED_SIZE = Vector3.new(16, 3, 24),
	RAMP_LENGTH = 4,
	-- Deck-space extents of the whole truck (arch, ramp foot, bumper): what a layout must keep clear.
	HALF_WIDTH = 9.3,
	BACK = 16.2,
	FRONT = 20.2,
	TOP = 11.8,
	-- The doorway under the roll drum and the arch's light strip.
	DOOR_HEIGHT = 9.1,
	GRAYBOX = table.freeze(GRAYBOX),
	COLLISION = table.freeze(COLLISION),
	SHELL = table.freeze(SHELL),
	-- The time clock's approved art (Model, RuntimeApproved, pivoted at its back centre, facing -Z) and fallback.
	CLOCK_TEMPLATE_PATH = table.freeze({ "Assets", "CleanupCrew", "TimeClock" }),
	CLOCK_NAME = "TimeClockArt",
	CLOCK_MOUNT = CLOCK_MOUNT,
	CLOCK_GRAYBOX = table.freeze(CLOCK_GRAYBOX),
	PAPERWORK = table.freeze(PAPERWORK),
	-- The band's side line (characters/truck/v3/livery_v3.png, "WE CLEAN UP THE NIGHT!"; Icey Labs decal
	-- 76089610185696 -> this image).
	LIVERY_IMAGE = "rbxassetid://86901531935857",
	BAND_PIECE = BAND_PIECE,
	LIVERY_FACES = table.freeze(LIVERY_FACES),
	SOCKETS = table.freeze(SOCKETS),
	INTERIOR_SLOTS = table.freeze(INTERIOR_SLOTS),
	LIVERY_PIXELS_PER_STUD = 100,
	-- The warm lamp under the roof.
	ROOF_PIECE = "BoxRoof",
	LAMP_COLOR = Color3.fromRGB(255, 226, 170),
	LAMP_BRIGHTNESS = 0.4,
	LAMP_RANGE = 15,
	-- The scanner arch's light (the client flashes it on each bank, DepotTruckScannerSystem).
	SCANNER_PIECE = "ScannerLight",
	SCANNER_IDLE = SCANNER_IDLE,
	SCANNER_GLOW_NAME = "ScanGlow",
	SCANNER_GLOW_RANGE = 16,
	-- The sweep runs down the doorway, just inside the arch, from under the roll drum to the deck.
	SWEEP_TOP = Vector3.new(0, 8.97, -12.3),
	SWEEP_BOTTOM = Vector3.new(0, 0.15, -12.3),
	SWEEP_WIDTH = 15.8,
	-- The truck's own parts are invisible (the art draws them); the bed is hidden behind the art's floor.
	BED_TRANSPARENCY = 1,
	TEAL = TEAL,
	IVORY = IVORY,
	GRAPHITE = GRAPHITE,
})
