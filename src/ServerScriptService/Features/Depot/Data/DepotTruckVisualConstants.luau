--!strict
--[=[
	DepotTruckVisualConstants: the Mobile Recovery Unit (truck design A, characters/truck/build_truck.py) in DECK
	SPACE: studs from the middle of the bed's top face, +Y up, +Z toward the cab, -Z the open back and the ramp. The
	bed (12 x DECK x 16, the queue pad / banking bed) is the floor; everything here sits round it, so the bed's
	whole footprint stays clear inside the box (walls outside x = +-6, the doorway 12 wide and under the roll drum).

	- COLLISION: native parts the art never replaces: box walls, roof, arch posts, the cab and the ramp (a wedge from
	  the ground to the bed's back edge). A collidable part is always queryable, so they are parented to the bed:
	  the load prompt's sight check (a ray to the bed that may hit the bed or its descendants) still sees the bed
	  through the box.
	- GRAYBOX: the fallback look when the approved template (TEMPLATE_PATH, RuntimeApproved) is missing.

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
}

export type LiveryFace = { piece: string, face: Enum.NormalId }

local TEAL = Color3.fromRGB(31, 110, 102)
local IVORY = Color3.fromRGB(229, 221, 197)
local FLOOR = Color3.fromRGB(216, 193, 137)
local GRAPHITE = Color3.fromRGB(46, 53, 54)
local GLASS = Color3.fromRGB(62, 94, 102)
local RAMP_GREY = Color3.fromRGB(126, 138, 140)
local SCANNER_IDLE = Color3.fromRGB(36, 112, 76)

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
	piece("BoxSideLeft", Vector3.new(-6.25, 3.65, 0.3), Vector3.new(0.5, 7.9, 16.4), IVORY),
	piece("BoxSideRight", Vector3.new(6.25, 3.65, 0.3), Vector3.new(0.5, 7.9, 16.4), IVORY),
	piece("BoxFront", Vector3.new(0, 3.65, 8.25), Vector3.new(13, 7.9, 0.5), IVORY),
	piece("BoxRoof", Vector3.new(0, 7.35, 0.3), Vector3.new(13.4, 0.75, 16.9), TEAL),
	piece("BoxFloor", Vector3.new(0, 0.03, 0), Vector3.new(11.9, 0.06, 15.9), FLOOR),
	piece("ScannerPostLeft", Vector3.new(-6.6, 3.2, -8.3), Vector3.new(1.2, 7.6, 1.3), TEAL),
	piece("ScannerPostRight", Vector3.new(6.6, 3.2, -8.3), Vector3.new(1.2, 7.6, 1.3), TEAL),
	piece("ScannerBeam", Vector3.new(0, 7.85, -8.3), Vector3.new(14.4, 1.7, 1.5), TEAL),
	piece("ScannerLight", Vector3.new(0, 8, -9.1), Vector3.new(9, 0.55, 0.14), SCANNER_IDLE, Enum.Material.Neon),
	piece("CabBody", Vector3.new(0, 2.65, 11.55), Vector3.new(10.4, 8.1, 5.9), TEAL),
	piece("CabWindows", Vector3.new(0, 4.4, 14.52), Vector3.new(8.4, 2.6, 0.1), GLASS, Enum.Material.Glass),
	piece("Chassis", Vector3.new(0, -1, 1.6), Vector3.new(9, 1.2, 19.6), GRAPHITE),
	piece("Ramp", Vector3.new(0, -1.5, -10), Vector3.new(7, 3, 4), RAMP_GREY, nil, "Wedge"),
}
for _, z in { -4, 11.2 } do
	for _, side in { -1, 1 } do
		table.insert(
			GRAYBOX,
			piece("Tire", Vector3.new(side * 5.6, -1.55, z), Vector3.new(1.3, 2.9, 2.9), GRAPHITE, nil, "Cylinder")
		)
	end
end

local function solid(name: string, centre: Vector3, size: Vector3, shape: Shape): Solid
	return { name = name, centre = centre, size = size, shape = shape }
end

local COLLISION: { Solid } = {
	solid("TruckWallLeft", Vector3.new(-6.25, 3.8, 0.3), Vector3.new(0.5, 7.6, 16.4), "Block"),
	solid("TruckWallRight", Vector3.new(6.25, 3.8, 0.3), Vector3.new(0.5, 7.6, 16.4), "Block"),
	solid("TruckWallFront", Vector3.new(0, 3.8, 8.25), Vector3.new(13, 7.6, 0.5), "Block"),
	solid("TruckRoof", Vector3.new(0, 7.35, 0.3), Vector3.new(13.4, 0.75, 16.9), "Block"),
	solid("TruckArchPostLeft", Vector3.new(-6.6, 3.5, -8.3), Vector3.new(1.2, 7, 1.3), "Block"),
	solid("TruckArchPostRight", Vector3.new(6.6, 3.5, -8.3), Vector3.new(1.2, 7, 1.3), "Block"),
	solid("TruckCab", Vector3.new(0, 2.4, 11.7), Vector3.new(10.6, 8.6, 6.4), "Block"),
	-- A wedge rises toward +Z: its tall face meets the bed's back edge, its foot is on the ground RAMP_LENGTH out.
	solid("TruckRamp", Vector3.new(0, -1.5, -10), Vector3.new(7, 3, 4), "Wedge"),
}

local LIVERY_FACES: { LiveryFace } = {
	{ piece = "BoxShell", face = Enum.NormalId.Left },
	{ piece = "BoxShell", face = Enum.NormalId.Right },
	{ piece = "BoxSideLeft", face = Enum.NormalId.Left },
	{ piece = "BoxSideRight", face = Enum.NormalId.Right },
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
	BED_SIZE = Vector3.new(12, 3, 16),
	RAMP_LENGTH = 4,
	-- Deck-space extents of the whole truck (arch, ramp foot, bumper): what a layout must keep clear.
	HALF_WIDTH = 7.4,
	BACK = 12,
	FRONT = 14.9,
	TOP = 8.7,
	-- The doorway under the roll drum and the arch's light strip.
	DOOR_HEIGHT = 6.1,
	GRAYBOX = table.freeze(GRAYBOX),
	COLLISION = table.freeze(COLLISION),
	-- The box-side livery (characters/truck/truck_livery.png; Icey Labs decal 116426639844539 -> this image).
	LIVERY_IMAGE = "rbxassetid://133126605608436",
	LIVERY_FACES = table.freeze(LIVERY_FACES),
	LIVERY_PIXELS_PER_STUD = 40,
	-- The warm lamp under the roof.
	ROOF_PIECE = "BoxRoof",
	LAMP_COLOR = Color3.fromRGB(255, 226, 170),
	LAMP_BRIGHTNESS = 0.4,
	LAMP_RANGE = 10,
	-- The scanner arch's light (the client flashes it on each bank, DepotTruckScannerSystem).
	SCANNER_PIECE = "ScannerLight",
	SCANNER_IDLE = SCANNER_IDLE,
	SCANNER_GLOW_NAME = "ScanGlow",
	SCANNER_GLOW_RANGE = 14,
	-- The sweep runs down the doorway, just inside the arch, from under the roll drum to the deck.
	SWEEP_TOP = Vector3.new(0, 5.9, -8.3),
	SWEEP_BOTTOM = Vector3.new(0, 0.15, -8.3),
	SWEEP_WIDTH = 11.8,
	-- The truck's own parts are invisible (the art draws them); the bed is hidden behind the art's floor.
	BED_TRANSPARENCY = 1,
	TEAL = TEAL,
	IVORY = IVORY,
	GRAPHITE = GRAPHITE,
})
