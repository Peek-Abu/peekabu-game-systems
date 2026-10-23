--!strict
--[=[
	OfficeShellUtils: the office shell's geometry from the approved spike, as plain boxes. A wall is two plaster
	slabs with oak wainscot, a darker rail and a skirt on both faces; a door gets an oak casing (or plaster pilasters
	on a wide archway); a glass pane is framed with mullions and a base rail; a ceiling is a slab with a thin grid.
	Layout space, Y 0 is the floor top. Pure and deterministic; OfficeBuildSystem turns the boxes into parts.

	@class OfficeShellUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

type ShellBox = OfficeTypes.ShellBox
type ShellMaterial = OfficeTypes.ShellMaterial
type Segment = OfficeTypes.Segment
type Door = OfficeTypes.Door
type Room = OfficeTypes.Room
type Edge = OfficeTypes.Edge

-- A line of wall: `horizontal` runs along x at z = `line`; otherwise along z at x = `line`.
type Line = { horizontal: boolean, line: number }

local WIDE_ARCHWAY = 8
local EPSILON = 1e-6

local OfficeShellUtils = {}

-- A box spanning along-range [a0, a1], across-range [n0, n1] (offsets from the wall line) and Y [y0, y1].
local function box(
	name: string,
	material: ShellMaterial,
	collide: boolean,
	where: Line,
	range: { number },
	y: { number },
	across: { number }
): ShellBox
	local length = range[2] - range[1]
	local depth = across[2] - across[1]
	local alongMid = (range[1] + range[2]) / 2
	local acrossMid = where.line + (across[1] + across[2]) / 2
	local yMid = (y[1] + y[2]) / 2
	if where.horizontal then
		return {
			name = name,
			size = Vector3.new(length, y[2] - y[1], depth),
			cframe = CFrame.new(alongMid, yMid, acrossMid),
			material = material,
			collide = collide,
		}
	end
	return {
		name = name,
		size = Vector3.new(depth, y[2] - y[1], length),
		cframe = CFrame.new(acrossMid, yMid, alongMid),
		material = material,
		collide = collide,
	}
end

local function lineOf(segment: Segment): (Line, number, number)
	local horizontal = segment.z1 == segment.z2
	if horizontal then
		return { horizontal = true, line = segment.z1 },
			math.min(segment.x1, segment.x2),
			math.max(segment.x1, segment.x2)
	end
	return { horizontal = false, line = segment.x1 }, math.min(segment.z1, segment.z2), math.max(segment.z1, segment.z2)
end

-- The across range between offsets a and b from the line, in order.
local function between(a: number, b: number): { number }
	return { math.min(a, b), math.max(a, b) }
end

--[=[
	A wall run: two plaster slabs plus, on both faces, wainscot, rail and skirt. `first` / `last` are how far the run
	extends past each end (half the wall thickness at a corner, 0 at a door or pane). Trim at a corner end reaches
	past it by its own depth so two runs meeting at an inside corner close; at a door end it stops flush.
]=]
function OfficeShellUtils.wall(segment: Segment, first: number, last: number): { ShellBox }
	local shell = OfficeConstants.SHELL
	local where, from, to = lineOf(segment)
	local boxes: { ShellBox } = {}
	local slabRange = { from - first, to + last }
	local slabY = { -shell.slabOverhang, OfficeConstants.WALL_HEIGHT + shell.slabOverhang }
	for _, side in { -1, 1 } do
		table.insert(boxes, box("Plaster", "plaster", true, where, slabRange, slabY, between(0, side * shell.slab)))
		local face = side * shell.slab
		local function trim(name: string, material: ShellMaterial, proud: number, y0: number, y1: number)
			local reach = { from - (if first > 0 then proud else 0), to + (if last > 0 then proud else 0) }
			table.insert(
				boxes,
				box(name, material, false, where, reach, { y0, y1 }, between(face, face + side * proud))
			)
		end
		trim("Wainscot", "oak", shell.wainscotProud, 0, shell.wainscotHeight)
		trim("Rail", "rail", shell.railDepth, shell.wainscotHeight, shell.wainscotHeight + shell.railHeight)
		trim("Skirt", "skirt", shell.skirtProud, 0, shell.skirtHeight)
	end
	return boxes
end

--[=[
	The trim around a doorway on `edge` of its room. A solid or glass door gets an oak casing (two jambs and a head)
	inside the rough opening, proud on both faces; an open doorway wider than 8 gets plaster pilasters at both jambs;
	a narrow open one gets nothing.
]=]
function OfficeShellUtils.doorCasing(door: Door, edge: Edge): { ShellBox }
	local shell = OfficeConstants.SHELL
	local horizontal = edge == "minZ" or edge == "maxZ"
	local where: Line = { horizontal = horizontal, line = if horizontal then door.z else door.x }
	local centre = if horizontal then door.x else door.z
	local lo, hi = centre - door.width / 2, centre + door.width / 2
	local boxes: { ShellBox } = {}
	local kind = door.kind or "open"
	if kind == "open" then
		if door.width > WIDE_ARCHWAY then
			local reach = OfficeConstants.WALL_THICKNESS / 2 + shell.wainscotProud
			local across = { -reach, reach }
			local y = { 0, OfficeConstants.WALL_HEIGHT }
			table.insert(boxes, box("Pilaster", "plaster", false, where, { lo, lo + shell.pilaster }, y, across))
			table.insert(boxes, box("Pilaster", "plaster", false, where, { hi - shell.pilaster, hi }, y, across))
		end
		return boxes
	end
	local reach = OfficeConstants.WALL_THICKNESS / 2 + shell.casing
	local across = { -reach, reach }
	local top = OfficeConstants.DOOR_HEIGHT
	table.insert(boxes, box("Jamb", "oak", false, where, { lo, lo + shell.casing }, { 0, top }, across))
	table.insert(boxes, box("Jamb", "oak", false, where, { hi - shell.casing, hi }, { 0, top }, across))
	table.insert(boxes, box("Head", "oak", false, where, { lo, hi }, { top - shell.casing, top }, across))
	return boxes
end

--[=[
	A framed glass pane: frame ends, mullions spaced so no gap is wider than mullionSpacing, a base rail, a head rail
	and one collidable glass sheet from the base rail up to half a stud under the wall top.
]=]
function OfficeShellUtils.glassPane(pane: Segment): { ShellBox }
	local shell = OfficeConstants.SHELL
	local where, from, to = lineOf(pane)
	local height = OfficeConstants.WALL_HEIGHT
	local boxes: { ShellBox } = {}
	local frameReach = OfficeConstants.WALL_THICKNESS / 2 + shell.casing
	local inner = { from + shell.glassFrame, to - shell.glassFrame }
	local full = { 0, height }
	table.insert(boxes, box("FrameEnd", "frame", false, where, { from, inner[1] }, full, { -frameReach, frameReach }))
	table.insert(boxes, box("FrameEnd", "frame", false, where, { inner[2], to }, full, { -frameReach, frameReach }))

	local span = inner[2] - inner[1]
	local mullions = 0
	while (span - mullions * shell.mullion) / (mullions + 1) > shell.mullionSpacing + EPSILON do
		mullions += 1
	end
	local gap = (span - mullions * shell.mullion) / (mullions + 1)
	for i = 1, mullions do
		local start = inner[1] + i * gap + (i - 1) * shell.mullion
		table.insert(
			boxes,
			box("Mullion", "frame", false, where, { start, start + shell.mullion }, full, { -0.2, 0.2 })
		)
	end

	local sheetTop = height - 0.5
	local railAcross = { -0.25, 0.25 }
	table.insert(boxes, box("BaseRail", "frame", false, where, inner, { 0, shell.baseRail }, railAcross))
	table.insert(boxes, box("HeadRail", "frame", false, where, inner, { sheetTop, height }, railAcross))
	table.insert(boxes, box("Glass", "glass", true, where, inner, { shell.baseRail, sheetTop }, { -0.1, 0.1 }))
	return boxes
end

--[=[
	A room's ceiling: one slab on top of the walls plus thin grid strips every gridSpacing studs, both directions,
	hung just under it.
]=]
function OfficeShellUtils.ceiling(room: Room): { ShellBox }
	local shell = OfficeConstants.SHELL
	local height = OfficeConstants.WALL_HEIGHT
	local width = room.maxX - room.minX
	local depth = room.maxZ - room.minZ
	local centreX = (room.minX + room.maxX) / 2
	local centreZ = (room.minZ + room.maxZ) / 2
	local boxes: { ShellBox } = {
		{
			name = "Ceiling",
			size = Vector3.new(width, shell.slabOverhang, depth),
			cframe = CFrame.new(centreX, height + shell.slabOverhang / 2, centreZ),
			material = "ceiling",
			collide = false,
		},
	}
	local stripY = height - shell.gridThickness / 2
	local x = room.minX + shell.gridSpacing
	while x < room.maxX - 0.5 do
		table.insert(boxes, {
			name = "Grid",
			size = Vector3.new(shell.gridWidth, shell.gridThickness, depth),
			cframe = CFrame.new(x, stripY, centreZ),
			material = "grid",
			collide = false,
		})
		x += shell.gridSpacing
	end
	local z = room.minZ + shell.gridSpacing
	while z < room.maxZ - 0.5 do
		table.insert(boxes, {
			name = "Grid",
			size = Vector3.new(width, shell.gridThickness, shell.gridWidth),
			cframe = CFrame.new(centreX, stripY, z),
			material = "grid",
			collide = false,
		})
		z += shell.gridSpacing
	end
	return boxes
end

return OfficeShellUtils
