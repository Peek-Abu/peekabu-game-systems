--!strict
--[=[
	OfficeShellVisualSystem: turns the pure shell and lighting plans into Parts. Under the office model it builds a
	`Shell` folder (wall slabs and trim, door casings and lintels, framed glass, ceilings) and a `Lights` folder (one
	subfolder per room, holding its troffer panels and fill lights). Every shell box takes its Material and colour from
	OfficeConstants.SHELL_MATERIALS, with the MaterialVariant only where the place has one by that name.

	A troffer panel is a Part under the ceiling whose visual is the kit's `troffer` template (lit and unlit alike);
	with no template the Part itself is a 4 x 0.2 x 2 greybox panel. A lit one is tagged for Harlow's tells and carries
	a downward SurfaceLight; an unlit one has no light and no glow. A fill is an invisible anchor holding a shadowed
	PointLight. The wall, ceiling and fluorescent art keys are no longer used: the slabs are opaque.

	Floors stay in OfficeBuildSystem, which asks `floorMaterial` and `apply` for the surface.

	Instance shell; the geometry is OfficeShellUtils, the placement OfficeLightingUtils (both specced).

	@class OfficeShellVisualSystem
]=]

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeArtKeyUtils = require(OfficeServer.Utils.OfficeArtKeyUtils)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeLightingUtils = require(OfficeServer.Utils.OfficeLightingUtils)
local OfficeShellUtils = require(OfficeServer.Utils.OfficeShellUtils)

type HasVariant = (name: string) -> boolean

local PANEL_SIZE = Vector3.new(4, 0.2, 2)
local FILL_SIZE = Vector3.one * 0.2
local EPSILON = 1e-4
-- The deepest trim (wainscot, rail or skirt): how far past a slab end a corner's wrap can reach.
local CORNER_TRIM_REACH =
	math.max(OfficeConstants.SHELL.wainscotProud, OfficeConstants.SHELL.railDepth, OfficeConstants.SHELL.skirtProud)

local FLOOR_BY_TYPE: { [string]: OfficeTypes.ShellMaterial } = {
	hallway = "hallcarpet",
	breakout = "lino",
	server = "vinyl",
	storage = "vinyl",
	bay = "vinyl",
}

local OfficeShellVisualSystem = {}

local function inPlace(name: string): boolean
	return MaterialService:FindFirstChild(name) ~= nil
end

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

--[=[
	The floor material for a room type (OfficeArtKeyUtils.roomType): hallway carpet in corridors, lino in the
	breakout room, vinyl in server and storage rooms and in the bay (OfficeBuildSystem passes "bay"), carpet else.
]=]
function OfficeShellVisualSystem.floorMaterial(roomType: string?): OfficeTypes.ShellMaterial
	if roomType == nil then
		return "carpet"
	end
	return FLOOR_BY_TYPE[roomType] or "carpet"
end

--[=[
	Gives `part` the material's Material, colour and transparency, and its MaterialVariant when `hasVariant` (default:
	MaterialService has a variant of that name) says the place has one.
]=]
function OfficeShellVisualSystem.apply(part: BasePart, material: OfficeTypes.ShellMaterial, hasVariant: HasVariant?)
	local look = OfficeConstants.SHELL_MATERIALS[material]
	part.Material = look.material
	part.Color = look.color
	part.Transparency = look.transparency
	local variant = look.variant
	if variant ~= nil and (hasVariant or inPlace)(variant) then
		part.MaterialVariant = variant
	end
end

local function newPart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function build(box: OfficeTypes.ShellBox, origin: CFrame, parent: Instance, hasVariant: HasVariant?)
	local part = newPart(box.name, box.size, origin * box.cframe, parent)
	OfficeShellVisualSystem.apply(part, box.material, hasVariant)
	part.CanCollide = box.collide
	part.CanQuery = box.collide
	-- Grid strips hang under the slab, so their shadow is the slab's own.
	part.CastShadow = box.name ~= "Grid"
	if box.material == "glass" then
		CollectionService:AddTag(part, OccupantConstants.SIGHT_THROUGH_TAG)
	end
end

-- Whether a wall perpendicular to a run along `horizontal` passes through or ends at (x, z): a corner there.
local function meetsWall(walls: { OfficeTypes.Segment }, x: number, z: number, horizontal: boolean): boolean
	for _, wall in walls do
		if (wall.z1 == wall.z2) ~= horizontal then
			local fixed = if horizontal then wall.x1 else wall.z1
			local lo = if horizontal then math.min(wall.z1, wall.z2) else math.min(wall.x1, wall.x2)
			local hi = if horizontal then math.max(wall.z1, wall.z2) else math.max(wall.x1, wall.x2)
			local along, across = if horizontal then x else z, if horizontal then z else x
			if math.abs(fixed - along) < EPSILON and lo <= across + EPSILON and hi >= across - EPSILON then
				return true
			end
		end
	end
	return false
end

-- How far a wall ending at (x, z) extends past that point: nothing at a door aperture or a glass pane, half a wall
-- thickness at a corner (also at an archway's edge where another of `walls` meets the end).
local function endcap(
	layout: OfficeTypes.Layout,
	walls: { OfficeTypes.Segment },
	x: number,
	z: number,
	horizontal: boolean
): number
	for _, door in layout.doors do
		local room = OfficeLayoutUtils.room(layout, door.a)
		local edge: OfficeTypes.Edge? = if room ~= nil then OfficeLayoutUtils.doorEdge(room, door) else nil
		if edge ~= nil then
			local across = edge == "minZ" or edge == "maxZ"
			local sameLine = if horizontal then math.abs(z - door.z) < EPSILON else math.abs(x - door.x) < EPSILON
			local offset = if horizontal then x - door.x else z - door.z
			local real = door.kind == "solid" or door.kind == "glass"
			if across == horizontal and sameLine and math.abs(math.abs(offset) - door.width / 2) < EPSILON then
				-- A door end, flush. At an archway's edge where another wall meets it is a corner (its slab and trim
				-- run on to that wall); at a real door the casing covers the end, so it stays flush.
				if real or not meetsWall(walls, x, z, horizontal) then
					return 0
				end
			end
		end
	end
	for _, pane in OfficeLayoutUtils.panes(layout) do
		if (pane.z1 == pane.z2) == horizontal then
			local sameLine = if horizontal then math.abs(z - pane.z1) < EPSILON else math.abs(x - pane.x1) < EPSILON
			local at = if horizontal then x else z
			local from = if horizontal then pane.x1 else pane.z1
			local to = if horizontal then pane.x2 else pane.z2
			if sameLine and (math.abs(at - from) < EPSILON or math.abs(at - to) < EPSILON) then
				return 0
			end
		end
	end
	return OfficeConstants.WALL_THICKNESS / 2
end

-- The plaster lintel over a solid or glass door (the casing stops at DOOR_HEIGHT), as wide as the door and as thick
-- as the wall, up to the slab top.
local function lintel(door: OfficeTypes.Door, horizontal: boolean): OfficeTypes.ShellBox
	local bottom = OfficeConstants.DOOR_HEIGHT
	local height = OfficeConstants.WALL_HEIGHT + OfficeConstants.SHELL.slabOverhang - bottom
	local thickness = OfficeConstants.WALL_THICKNESS
	return {
		name = "DoorHeader",
		size = if horizontal
			then Vector3.new(door.width, height, thickness)
			else Vector3.new(thickness, height, door.width),
		cframe = CFrame.new(door.x, bottom + height / 2, door.z),
		material = "plaster",
		collide = true,
	}
end

local function facadesOf(layout: OfficeTypes.Layout): { OfficeTypes.Facade }
	local facades: { OfficeTypes.Facade } = layout.facades or {}
	return facades
end

-- The facades of `layout` that lie on `segment`'s wall line and overlap it: each breaks the trim on its face. So do
-- its doorways' rough openings, on both faces (OfficeShellUtils.doorGaps): a real door's whole opening, an archway's
-- less the reach a corner at its edge extends and wraps by (half a wall plus the deepest trim).
local function facadeGaps(layout: OfficeTypes.Layout, segment: OfficeTypes.Segment): { OfficeShellUtils.TrimGap }
	local gaps: { OfficeShellUtils.TrimGap } = {}
	local horizontal = segment.z1 == segment.z2
	local fixed = if horizontal then segment.z1 else segment.x1
	for _, door in layout.doors do
		local room = OfficeLayoutUtils.room(layout, door.a)
		local edge: OfficeTypes.Edge? = if room ~= nil then OfficeLayoutUtils.doorEdge(room, door) else nil
		local line = if horizontal then door.z else door.x
		if edge ~= nil and (edge == "minZ" or edge == "maxZ") == horizontal and math.abs(line - fixed) < EPSILON then
			local real = door.kind == "solid" or door.kind == "glass"
			local inset = if real then 0 else OfficeConstants.WALL_THICKNESS / 2 + CORNER_TRIM_REACH
			table.move(OfficeShellUtils.doorGaps(door, edge, inset), 1, 2, #gaps + 1, gaps)
		end
	end
	for _, facade in facadesOf(layout) do
		local room = OfficeLayoutUtils.room(layout, facade.room)
		local edge: OfficeTypes.Edge? = if room ~= nil then OfficeLayoutUtils.facadeEdge(room, facade) else nil
		if edge ~= nil and (edge == "minZ" or edge == "maxZ") == horizontal then
			local gap = OfficeShellUtils.facadeGap(facade, edge)
			local line = if horizontal then facade.z else facade.x
			if math.abs(line - fixed) < EPSILON then
				table.insert(gaps, gap)
			end
		end
	end
	return gaps
end

local function buildWalls(layout: OfficeTypes.Layout, origin: CFrame, shell: Folder, hasVariant: HasVariant?)
	local segments = OfficeLayoutUtils.mergedWallSegments(layout)
	-- Everything a run's end can meet: the merged walls, the glass panes and the real doors' rough openings. A real
	-- door starting at a junction is an arm there (a T): the oak casing covers the slab end, so the trim stops instead
	-- of wrapping into the casing. An archway (open doorway) is not: its mouth corner is an L whose open side is the
	-- outer face, so the trim wraps round the wall end that bounds the archway (no bare plaster strip).
	local meeting: { OfficeTypes.Segment } = table.clone(segments)
	for _, pane in OfficeLayoutUtils.panes(layout) do
		table.insert(meeting, pane)
	end
	for _, door in layout.doors do
		local room = OfficeLayoutUtils.room(layout, door.a)
		local edge: OfficeTypes.Edge? = if room ~= nil then OfficeLayoutUtils.doorEdge(room, door) else nil
		if edge ~= nil and (door.kind == "solid" or door.kind == "glass") then
			table.insert(meeting, OfficeShellUtils.doorOpening(door, edge))
		end
	end
	for _, segment in segments do
		local horizontal = segment.z1 == segment.z2
		local first = endcap(layout, segments, segment.x1, segment.z1, horizontal)
		local last = endcap(layout, segments, segment.x2, segment.z2, horizontal)
		local extra: OfficeShellUtils.WallTrim = {
			outerFirst = if first > 0
				then OfficeShellUtils.outerSide(meeting, segment.x1, segment.z1, horizontal)
				else nil,
			outerLast = if last > 0
				then OfficeShellUtils.outerSide(meeting, segment.x2, segment.z2, horizontal)
				else nil,
			gaps = facadeGaps(layout, segment),
		}
		for _, box in OfficeShellUtils.wall(segment, first, last, extra) do
			build(box, origin, shell, hasVariant)
		end
	end
	for _, pane in OfficeLayoutUtils.panes(layout) do
		for _, box in OfficeShellUtils.glassPane(pane) do
			build(box, origin, shell, hasVariant)
		end
	end
	for _, door in layout.doors do
		local room = OfficeLayoutUtils.room(layout, door.a)
		local edge: OfficeTypes.Edge? = if room ~= nil then OfficeLayoutUtils.doorEdge(room, door) else nil
		if edge ~= nil then
			for _, box in OfficeShellUtils.doorCasing(door, edge) do
				build(box, origin, shell, hasVariant)
			end
			if door.kind == "solid" or door.kind == "glass" then
				build(lintel(door, edge == "minZ" or edge == "maxZ"), origin, shell, hasVariant)
			end
		end
	end
	for _, facade in facadesOf(layout) do
		local room = OfficeLayoutUtils.room(layout, facade.room)
		local edge: OfficeTypes.Edge? = if room ~= nil then OfficeLayoutUtils.facadeEdge(room, facade) else nil
		-- An elevator has no casing: its front fills the span (OfficeDecorSystem).
		if edge ~= nil and facade.kind ~= "elevator" then
			for _, box in OfficeShellUtils.facadeCasing(facade, edge) do
				build(box, origin, shell, hasVariant)
			end
		end
	end
end

local function buildPanel(
	panel: OfficeTypes.LightPanel,
	range: number,
	roomType: string?,
	origin: CFrame,
	parent: Instance,
	art: ArtVisualSystem.Controller
)
	local turn = if panel.rotated then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity
	local root = newPart(
		"Panel",
		PANEL_SIZE,
		origin * CFrame.new(panel.x, OfficeConstants.WALL_HEIGHT - PANEL_SIZE.Y / 2, panel.z) * turn,
		parent
	)
	root.Color = OfficeConstants.PANEL_COLOR
	root.CanCollide, root.CanQuery = false, false
	-- Flush under the ceiling, its shadow falls inside the ceiling's: casting it is shadow-pass cost for nothing.
	root.CastShadow = false
	local visual =
		OfficeArtKeyUtils.attachFirst(art, root, "building", OfficeArtKeyUtils.candidates("troffer", nil, roomType))
	if not panel.lit then
		root.Material = Enum.Material.SmoothPlastic
		if visual ~= nil then
			for _, part in visual:GetDescendants() do
				if part:IsA("BasePart") and part.Material == Enum.Material.Neon then
					part.Material = Enum.Material.SmoothPlastic
				end
			end
		end
		return
	end
	root.Material = Enum.Material.Neon
	root:SetAttribute("OfficeLightEmitter", true)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Brightness = panel.brightness
	light.Range = range
	light.Color = OfficeConstants.PANEL_COLOR
	light.Shadows = false
	light.Parent = root
	CollectionService:AddTag(root, OccupantConstants.LIGHT_TAG)
end

local function buildFill(fill: OfficeTypes.FillLight, origin: CFrame, parent: Instance)
	local anchor = newPart("Fill", FILL_SIZE, origin * CFrame.new(fill.position), parent)
	anchor.Transparency = 1
	anchor.CanCollide, anchor.CanQuery = false, false
	anchor.CastShadow = false
	-- Not a tube: the atmosphere's broken-light blink skips fills (Harlow's tells still flicker them).
	anchor:SetAttribute("OfficeLightFill", true)
	local light = Instance.new("PointLight")
	light.Brightness = fill.brightness
	light.Range = fill.range
	light.Color = fill.color
	light.Shadows = fill.shadows
	light.Parent = anchor
	CollectionService:AddTag(anchor, OccupantConstants.LIGHT_TAG)
end

--[=[
	Builds the shell and the lights of `layout` (placed at `origin`) under `model`. `art` supplies the troffer art;
	`hasVariant` says whether the place has a MaterialVariant by a name (default: MaterialService does).
]=]
function OfficeShellVisualSystem.build(
	layout: OfficeTypes.Layout,
	origin: CFrame,
	model: Model,
	art: ArtVisualSystem.Controller,
	hasVariant: HasVariant?
)
	local shell = folder("Shell", model)
	local lights = folder("Lights", model)
	buildWalls(layout, origin, shell, hasVariant)
	for _, room in layout.rooms do
		for _, box in OfficeShellUtils.ceiling(room) do
			build(box, origin, shell, hasVariant)
		end
		local roomType = OfficeArtKeyUtils.roomType(room)
		local recipe = OfficeConstants.LIGHTING[roomType or "pods"] or OfficeConstants.LIGHTING.pods
		local plan = OfficeLightingUtils.roomLights(room, roomType)
		local roomFolder = folder(room.name, lights)
		for _, panel in plan.panels do
			buildPanel(panel, recipe.panelRange, roomType, origin, roomFolder, art)
		end
		for _, fill in plan.fills do
			buildFill(fill, origin, roomFolder)
		end
	end
end

return OfficeShellVisualSystem
