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
local MEET = 1e-4

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

-- A stretch of one face's trim to leave out: `side` is the face (+1 toward +Z / +X of the wall line, -1 the other),
-- `from` / `to` the along-range in layout coordinates.
export type TrimGap = { side: number, from: number, to: number }

-- Optional extras for `wall`. `outerFirst` / `outerLast`: the face (+1 / -1) that is the OUTSIDE of an L corner at that
-- end (nil at a door, a pane, a T-junction or a free end). `gaps`: stretches of trim to leave out (facades).
export type WallTrim = { outerFirst: number?, outerLast: number?, gaps: { TrimGap }? }

-- The along-ranges of `range` that are not covered by any of `gaps` on `side`.
local function cutGaps(range: { number }, gaps: { TrimGap }?, side: number): { { number } }
	local pieces: { { number } } = { range }
	local list: { TrimGap } = gaps or {}
	for _, gap in list do
		if gap.side == side then
			local remaining: { { number } } = {}
			for _, piece in pieces do
				if gap.to <= piece[1] + EPSILON or gap.from >= piece[2] - EPSILON then
					table.insert(remaining, piece)
				else
					if gap.from - piece[1] > EPSILON then
						table.insert(remaining, { piece[1], gap.from })
					end
					if piece[2] - gap.to > EPSILON then
						table.insert(remaining, { gap.to, piece[2] })
					end
				end
			end
			pieces = remaining
		end
	end
	return pieces
end

--[=[
	A wall run: two plaster slabs plus, on both faces, wainscot, rail and skirt. `first` / `last` are how far the run
	extends past each end (half the wall thickness at a corner, 0 at a door or pane). Trim at a corner end reaches
	past it by its own depth so two runs meeting at an inside corner close; at a door end it stops flush. `trim` (see
	WallTrim) closes the OUTER face of an L corner once: the run along X reaches the slab end plus its depth and wraps
	the corner, the run along Z reaches only the slab end and butts against it (no coplanar overlap to flicker, no
	gap); it also breaks a face's trim at a facade.
]=]
function OfficeShellUtils.wall(segment: Segment, first: number, last: number, extra: WallTrim?): { ShellBox }
	local shell = OfficeConstants.SHELL
	local where, from, to = lineOf(segment)
	local boxes: { ShellBox } = {}
	local slabRange = { from - first, to + last }
	local slabY = { -shell.slabOverhang, OfficeConstants.WALL_HEIGHT + shell.slabOverhang }
	local outerFirst = if extra ~= nil then extra.outerFirst else nil
	local outerLast = if extra ~= nil then extra.outerLast else nil
	local gaps = if extra ~= nil then extra.gaps else nil
	for _, side in { -1, 1 } do
		table.insert(boxes, box("Plaster", "plaster", true, where, slabRange, slabY, between(0, side * shell.slab)))
		local face = side * shell.slab
		local function trim(name: string, material: ShellMaterial, proud: number, y0: number, y1: number)
			-- How far this face's trim reaches past an end that extends `past` (0: stops flush at a door or pane).
			local function reach(past: number, outer: number?): number
				if past <= 0 then
					return 0
				elseif outer ~= side then
					return proud
				end
				-- An L's outer face: the run along X wraps the corner (slab end plus its depth), the run along Z stops
				-- at the slab end, flush against the X run's back, so the two never overlap and leave no gap.
				return if where.horizontal then past + proud else past
			end
			local lo = from - reach(first, outerFirst)
			local hi = to + reach(last, outerLast)
			for _, piece in cutGaps({ lo, hi }, gaps, side) do
				table.insert(
					boxes,
					box(name, material, false, where, piece, { y0, y1 }, between(face, face + side * proud))
				)
			end
		end
		trim("Wainscot", "oak", shell.wainscotProud, 0, shell.wainscotHeight)
		trim("Rail", "rail", shell.railDepth, shell.wainscotHeight, shell.wainscotHeight + shell.railHeight)
		trim("Skirt", "skirt", shell.skirtProud, 0, shell.skirtHeight)
	end
	return boxes
end

--[=[
	Which face of a wall run ending at (x, z) is the OUTSIDE of an L corner: +1 (the +Z / +X face) or -1, nil when no
	wall meets the end or walls meet it on both sides (a T-junction or a cross: both faces are inside). `walls` are
	every wall piece (merged segments and glass panes) and every real door's rough opening (`doorOpening`: an opening
	that starts at the end is an arm, as a wall would be); `horizontal` is the run's direction.
]=]
function OfficeShellUtils.outerSide(walls: { Segment }, x: number, z: number, horizontal: boolean): number?
	local alongEnd = if horizontal then x else z
	local across = if horizontal then z else x
	local low, high = false, false
	for _, other in walls do
		local otherHorizontal = other.z1 == other.z2
		if otherHorizontal ~= horizontal then
			local fixed = if otherHorizontal then other.z1 else other.x1
			local from = if otherHorizontal then other.x1 else other.z1
			local to = if otherHorizontal then other.x2 else other.z2
			local lo, hi = math.min(from, to), math.max(from, to)
			-- A perpendicular wall whose centre line passes through this end and reaches the run's own line.
			if math.abs(fixed - alongEnd) < MEET and lo <= across + MEET and hi >= across - MEET then
				low = low or lo < across - MEET
				high = high or hi > across + MEET
			end
		end
	end
	if high and not low then
		return -1
	elseif low and not high then
		return 1
	end
	return nil
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
			table.insert(boxes, box("Pilaster", "plaster", true, where, { lo, lo + shell.pilaster }, y, across))
			table.insert(boxes, box("Pilaster", "plaster", true, where, { hi - shell.pilaster, hi }, y, across))
		end
		return boxes
	end
	local reach = OfficeConstants.WALL_THICKNESS / 2 + shell.casing
	local across = { -reach, reach }
	local top = OfficeConstants.DOOR_HEIGHT
	table.insert(boxes, box("Jamb", "oak", true, where, { lo, lo + shell.casing }, { 0, top }, across))
	table.insert(boxes, box("Jamb", "oak", true, where, { hi - shell.casing, hi }, { 0, top }, across))
	table.insert(boxes, box("Head", "oak", true, where, { lo, hi }, { top - shell.casing, top }, across))
	return boxes
end

-- The face (+1 toward +Z / +X, -1 the other) a facade on `edge` of its room stands on: the room side, so +1 on a min
-- edge and -1 on a max edge (OfficeDoorUtils.facadeFrame puts its leaf there).
local function facadeSide(edge: Edge): number
	return if edge == "minZ" or edge == "minX" then 1 else -1
end

local function facadeLine(facade: OfficeTypes.Facade, edge: Edge): (Line, number, number)
	local horizontal = edge == "minZ" or edge == "maxZ"
	local centre = if horizontal then facade.x else facade.z
	return { horizontal = horizontal, line = if horizontal then facade.z else facade.x },
		centre - facade.width / 2,
		centre + facade.width / 2
end

--[=[
	The oak casing of a facade on `edge` of its room: two jambs and a head around the facade's width and DOOR_HEIGHT,
	like a real door's but only on the face the facade is on (the other face is the outside). Trim only, so nothing
	collides.
]=]
function OfficeShellUtils.facadeCasing(facade: OfficeTypes.Facade, edge: Edge): { ShellBox }
	local shell = OfficeConstants.SHELL
	local where, lo, hi = facadeLine(facade, edge)
	local side = facadeSide(edge)
	local across = between(0, side * (OfficeConstants.WALL_THICKNESS / 2 + shell.casing))
	local top = OfficeConstants.DOOR_HEIGHT
	return {
		box("Jamb", "oak", false, where, { lo, lo + shell.casing }, { 0, top }, across),
		box("Jamb", "oak", false, where, { hi - shell.casing, hi }, { 0, top }, across),
		box("Head", "oak", false, where, { lo, hi }, { top - shell.casing, top }, across),
	}
end

--[=[
	The stretch of wall trim a facade on `edge` interrupts: its width, on the face it stands on.
]=]
function OfficeShellUtils.facadeGap(facade: OfficeTypes.Facade, edge: Edge): TrimGap
	local _, lo, hi = facadeLine(facade, edge)
	return { side = facadeSide(edge), from = lo, to = hi }
end

--[=[
	A doorway's rough opening on `edge` of its room, as a wall-line segment (its width along the wall). Handed to
	`outerSide` with the walls, an opening that starts at a junction counts as an arm there, so no corner wrap crosses
	it. OfficeShellVisualSystem hands in real doors only (their casing covers the slab end); an archway's mouth
	corner is left an L, so its trim wraps round the wall end.
]=]
function OfficeShellUtils.doorOpening(door: Door, edge: Edge): Segment
	if edge == "minZ" or edge == "maxZ" then
		return { x1 = door.x - door.width / 2, z1 = door.z, x2 = door.x + door.width / 2, z2 = door.z }
	end
	return { x1 = door.x, z1 = door.z - door.width / 2, x2 = door.x, z2 = door.z + door.width / 2 }
end

--[=[
	The stretches of trim a doorway on `edge` leaves out of a run on its own wall line: its rough opening less `inset`
	(default 0) at each end, on both faces. A run normally stops at a door's edge; this guarantees no trim lies inside
	an opening. An archway passes an inset so a run that ends at its edge as a corner (another wall meets it there)
	keeps the trim it extends and wraps by.
]=]
function OfficeShellUtils.doorGaps(door: Door, edge: Edge, inset: number?): { TrimGap }
	local horizontal = edge == "minZ" or edge == "maxZ"
	local centre = if horizontal then door.x else door.z
	local margin = inset or 0
	local lo, hi = centre - door.width / 2 + margin, centre + door.width / 2 - margin
	return { { side = -1, from = lo, to = hi }, { side = 1, from = lo, to = hi } }
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
			collide = true,
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
