--!strict
--[=[
	OfficeBuildSystem: builds the office's graybox from the current seeded layout (Cleanup Crew spec §1
	"polished feel on graybox", §5): a floor per room, walls broken around doors (OfficeLayoutUtils.
	wallSegments, merged so a shared wall is built once), the truck (its bed is the banking zone and carries Cargo's Load prompt; a cab at its back, inside the bay),
	the time clock inside the truck's box (Shift's Clock out prompt), the overtime sheet beside it on the box's front
	wall (Shift's Start overtime prompt, off until
	Shift opens it once the quota is met), and a desk or locker on every desk / locker marker (Cargo's
	Search prompt, off until Cargo stocks it; a desk is also a hiding spot, tagged for Hide). M2: ceiling lights (tagged for Harlow's tells) and the truck box's
	PathfindingModifier volume (Harlow walks the loading bay but never paths into the truck's box). Everything is anchored under one Model in Workspace at
	the layout's origin. Glass walls fill the layout's panes (Glass, see-through, solid, tagged SightThrough so Harlow's
	sight passes them; the wall pieces beside them stop flush). Physical per-room ceilings enclose the camera.
	Art keys: every attach goes through OfficeArtKeyUtils (a marker's own `art` key, then the default key's room-type
variant, then the default key), so a kit may restyle one room type (floorTile_server) or one piece (serverRack for a
shelf). Walls are merged across rooms, so they use the default key only.
Doors: every doorway keeps its visual-only frame and trim, and OfficeDoorSystem adds a real leaf to each solid or
	glass door plus a locked flush leaf on every facade (`Built.doors`, destroyed with the office).

	Instance shell; specs cover ceilings, and OfficeLayoutRules validates the layout.

	@class OfficeBuildSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)

local OfficeServer = ServerScriptService.Features.Office
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeArtKeyUtils = require(OfficeServer.Utils.OfficeArtKeyUtils)
local OfficeLoadingBayUtils = require(OfficeServer.Utils.OfficeLoadingBayUtils)
local OfficeDoorSystem = require(script.Parent.OfficeDoorSystem)

export type Built = {
	model: Model,
	bed: BasePart,
	clock: BasePart,
	overtime: BasePart,
	searchables: { [string]: BasePart },
	doors: OfficeDoorSystem.DoorSet,
}

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.Parent = parent
	return part
end

-- Native Zoom ignores transparent collision proxies. Keep an opaque solid core
-- behind the art skin, inset so it cannot cover the authored surface or narrow a door.
-- It must not descend from the transparent root: camera ray exclusions skip its descendants.
local function opaqueBacking(root: BasePart, parent: Instance)
	local size = root.Size - Vector3.one * 0.04
	-- The dado and rail extend beyond the cream wall body; keep the core behind all three.
	if root.Name == "Wall" then
		size = Vector3.new(size.X, size.Y, root.Size.Z * 0.45)
	end
	local backing = block("OpaqueBacking", size, root.CFrame, root.Color, parent)
	backing.CanTouch = false
end

local function interactable(part: BasePart, kind: string, enabled: boolean)
	part:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, kind)
	if not enabled then
		part:SetAttribute(InteractionConstants.ENABLED_ATTRIBUTE, false)
	end
	CollectionService:AddTag(part, InteractionConstants.TAG)
end

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local TruckVisual = require(ServerScriptService.Features.Depot.Systems.DepotTruckVisualSystem)
local DeskVisual = require(script.Parent.OfficeDeskVisualSystem)
local DoorwayVisual = require(script.Parent.OfficeDoorwayVisualSystem)

local OfficeBuildSystem = {}

function OfficeBuildSystem.build(
	layout: OfficeTypes.Layout,
	origin: CFrame,
	visuals: ArtVisualSystem.Controller?
): Built
	local art = visuals or ArtVisualSystem
	local model = Instance.new("Model")
	model.Name = OfficeConstants.MODEL_NAME
	local opaqueStructure = folder("OpaqueStructure", model)
	model:SetAttribute("ArtKitId", layout.artKit or OfficeConstants.ART_KIT_ID)
	local height = OfficeConstants.WALL_HEIGHT
	local thickness = OfficeConstants.WALL_THICKNESS
	local floorThickness = OfficeConstants.FLOOR_THICKNESS
	local colors = OfficeConstants.FLOOR_COLORS

	for index, room in layout.rooms do
		local roomFolder = folder(room.name, model)
		local roomType = OfficeArtKeyUtils.roomType(room)
		local width = room.maxX - room.minX
		local depth = room.maxZ - room.minZ
		local floor = block(
			"Floor",
			Vector3.new(width, floorThickness, depth),
			origin * CFrame.new(room.minX + width / 2, -floorThickness / 2, room.minZ + depth / 2),
			colors[(index - 1) % #colors + 1],
			roomFolder
		)
		if
			OfficeArtKeyUtils.attachFirst(
				art,
				floor,
				"building",
				OfficeArtKeyUtils.candidates("floorTile", nil, roomType)
			) ~= nil
		then
			-- Carpet weave sits above its recessed face; keep backing below both to avoid hiding the carpet.
			local skin =
				block("FloorUnderlay", floor.Size, floor.CFrame * CFrame.new(0, -0.1, 0), floor.Color, roomFolder)
			skin.CanCollide, skin.CanQuery, skin.CanTouch = true, true, false
		end
		local ceiling = block(
			"Ceiling",
			Vector3.new(width + thickness, 1, depth + thickness),
			origin * CFrame.new(room.minX + width / 2, height + 0.5, room.minZ + depth / 2),
			OfficeConstants.WALL_COLOR,
			roomFolder
		)

		if
			OfficeArtKeyUtils.attachFirst(
				art,
				ceiling,
				"building",
				OfficeArtKeyUtils.candidates("ceilingTile", nil, roomType)
			) ~= nil
		then
			opaqueBacking(ceiling, opaqueStructure)
		end

		for _, point in OfficeLayoutUtils.lightPoints(room, OfficeConstants.LIGHT_SPACING) do
			local size = OfficeConstants.LIGHT_SIZE
			local fixture = block(
				"Light",
				size,
				origin * CFrame.new(point[1], height - size.Y / 2, point[2]),
				OfficeConstants.LIGHT_COLOR,
				roomFolder
			)
			fixture.Material = Enum.Material.Neon
			fixture.CanCollide = false
			fixture.CanQuery = false
			fixture.CanTouch = false
			-- Flush under the ceiling, its shadow falls inside the ceiling's: casting it is shadow-pass cost for nothing.
			fixture.CastShadow = false
			local light = Instance.new("PointLight")
			light.Range = OfficeConstants.LIGHT_RANGE
			light.Brightness = OfficeConstants.LIGHT_BRIGHTNESS
			light.Color = OfficeConstants.LIGHT_COLOR
			light.Parent = fixture
			if
				OfficeArtKeyUtils.attachFirst(
					art,
					fixture,
					"building",
					OfficeArtKeyUtils.candidates("fluorescent", nil, roomType)
				) ~= nil
			then
				local panel = block(
					"LightPanel",
					Vector3.new(size.X * 0.82, 0.025, size.Z * 0.65),
					fixture.CFrame * CFrame.new(0, -size.Y / 2 - 0.015, 0),
					OfficeConstants.LIGHT_COLOR,
					fixture
				)
				panel.Material = Enum.Material.Neon
				panel:SetAttribute("OfficeLightEmitter", true)
				panel.CanCollide = false
				panel.CanQuery = false
				panel.CanTouch = false
				panel.CastShadow = false
			end
			CollectionService:AddTag(fixture, OccupantConstants.LIGHT_TAG)
		end
	end

	local wallFolder = folder("Walls", model)
	local panes = OfficeLayoutUtils.panes(layout)
	local function endcap(x: number, z: number, horizontal: boolean): number
		for _, door in layout.doors do
			local room = OfficeLayoutUtils.room(layout, door.a)
			if room ~= nil then
				local edge = OfficeLayoutUtils.doorEdge(room, door)
				local across = edge == "minZ" or edge == "maxZ"
				local sameLine = if horizontal then math.abs(z - door.z) < 1e-4 else math.abs(x - door.x) < 1e-4
				local offset = if horizontal then x - door.x else z - door.z
				if
					edge ~= nil
					and across == horizontal
					and sameLine
					and math.abs(math.abs(offset) - door.width / 2) < 1e-4
				then
					return 0
				end
			end
		end
		-- A wall ending at a glass pane stops flush at it, like at a door aperture.
		for _, pane in panes do
			local paneHorizontal = pane.z1 == pane.z2
			if paneHorizontal == horizontal then
				local sameLine = if horizontal then math.abs(z - pane.z1) < 1e-4 else math.abs(x - pane.x1) < 1e-4
				local at = if horizontal then x else z
				local from = if horizontal then pane.x1 else pane.z1
				local to = if horizontal then pane.x2 else pane.z2
				if sameLine and (math.abs(at - from) < 1e-4 or math.abs(at - to) < 1e-4) then
					return 0
				end
			end
		end
		return thickness / 2
	end
	for _, segment in OfficeLayoutUtils.mergedWallSegments(layout) do
		local horizontal = segment.z1 == segment.z2
		local length = if horizontal then segment.x2 - segment.x1 else segment.z2 - segment.z1
		-- Author wall art spans local X. Rotate vertical wall proxies while retaining their exact world bounds.
		-- Corner caps may overlap; doorway ends must stop exactly at the physical aperture.
		local first = endcap(segment.x1, segment.z1, horizontal)
		local last = endcap(segment.x2, segment.z2, horizontal)
		local size = Vector3.new(length + first + last, height, thickness)
		local offset = (last - first) / 2
		local centre = CFrame.new(
			(segment.x1 + segment.x2) / 2 + (if horizontal then offset else 0),
			height / 2,
			(segment.z1 + segment.z2) / 2 + (if horizontal then 0 else offset)
		)
		local turn = if horizontal then CFrame.identity else CFrame.Angles(0, math.pi / 2, 0)
		local wall = block("Wall", size, origin * centre * turn, OfficeConstants.WALL_COLOR, wallFolder)
		-- Default key only: a merged segment can border two rooms of different types, so no room-type variant.
		if art.attach(wall, "building", "wallSolid") ~= nil then
			opaqueBacking(wall, opaqueStructure)
		end
	end

	-- Glass panes: see-through, solid to walkers, no art skin and no opaque backing. Harlow's sight passes them.
	for _, pane in panes do
		local horizontal = pane.z1 == pane.z2
		local length = if horizontal then pane.x2 - pane.x1 else pane.z2 - pane.z1
		local centre = CFrame.new((pane.x1 + pane.x2) / 2, height / 2, (pane.z1 + pane.z2) / 2)
		local turn = if horizontal then CFrame.identity else CFrame.Angles(0, math.pi / 2, 0)
		local glass = block(
			"GlassWall",
			Vector3.new(length, height, thickness),
			origin * centre * turn,
			OfficeConstants.WALL_COLOR,
			wallFolder
		)
		glass.Material = Enum.Material.Glass
		glass.Transparency = 0.55
		glass.CanCollide = true
		glass.CanQuery = true
		CollectionService:AddTag(glass, OccupantConstants.SIGHT_THROUGH_TAG)
	end

	-- Visual-only frames retain the original open door gaps and never add collision.
	local doorFolder = folder("DoorFrames", model)
	for _, door in layout.doors do
		local room = OfficeLayoutUtils.room(layout, door.a)
		if room ~= nil then
			local edge = OfficeLayoutUtils.doorEdge(room, door)
			local turn = if edge == "minX" or edge == "maxX" then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity
			local frame = block(
				"DoorFrame",
				Vector3.new(door.width, height, thickness),
				origin * CFrame.new(door.x, height / 2, door.z) * turn,
				OfficeConstants.WALL_COLOR,
				doorFolder
			)
			frame:SetAttribute("ArtOpeningWidth", door.width)
			frame.Transparency = 1
			frame.CanCollide = false
			frame.CanQuery = false
			frame.CanTouch = false
			DoorwayVisual.build(frame)
			-- A real door's leaf stops at DOOR_HEIGHT: wall the rest of the opening so nothing shows over it.
			if door.kind == "solid" or door.kind == "glass" then
				local lintel = height - OfficeConstants.DOOR_HEIGHT
				local header = block(
					"DoorHeader",
					Vector3.new(door.width, lintel, thickness),
					origin * CFrame.new(door.x, OfficeConstants.DOOR_HEIGHT + lintel / 2, door.z) * turn,
					OfficeConstants.WALL_COLOR,
					doorFolder
				)
				if art.attach(header, "building", "wallSolid") ~= nil then
					opaqueBacking(header, opaqueStructure)
				end
			end
		end
	end

	local truckFolder = folder("Truck", model)
	local truck = layout.truck
	local bedWidth = truck.maxX - truck.minX
	local bedDepth = truck.maxZ - truck.minZ
	local bedHeight = OfficeConstants.BED_HEIGHT
	local bed = block(
		"TruckBed",
		Vector3.new(bedWidth, bedHeight, bedDepth),
		origin * CFrame.new(truck.minX + bedWidth / 2, bedHeight / 2, truck.minZ + bedDepth / 2),
		OfficeConstants.BED_COLOR,
		truckFolder
	)
	interactable(bed, CargoConstants.LOAD_KIND, true)
	TruckVisual.build(bed, truckFolder)
	-- The paperwork hangs inside the box on its front wall: the time clock's art is the truck's, this is its
	-- invisible hit box (queryable, so the prompt's sight check finds it); the overtime sheet is a clipboard.
	local clockFrame, clockSize = TruckVisual.paperwork(bed, "clock")
	local clock = block("TimeClock", clockSize, clockFrame, OfficeConstants.CLOCK_COLOR, truckFolder)
	clock.Transparency = 1
	clock.CanCollide = false
	clock.CanTouch = false
	interactable(clock, ShiftConstants.CLOCK_OUT_KIND, true)
	local sheetFrame, sheetSize = TruckVisual.paperwork(bed, "sheet")
	local overtime = block("OvertimeSheet", sheetSize, sheetFrame, OfficeConstants.OVERTIME_COLOR, truckFolder)
	overtime.CanCollide = false
	overtime.CanTouch = false
	interactable(overtime, ShiftConstants.OVERTIME_KIND, false)

	local furniture = folder("Furniture", model)
	local searchables: { [string]: BasePart } = {}
	for _, marker in layout.markers do
		if marker.kind == "desk" or marker.kind == "locker" then
			local isDesk = marker.kind == "desk"
			local size = if isDesk then OfficeConstants.DESK_SIZE else OfficeConstants.LOCKER_SIZE
			local part = block(
				if isDesk then "Desk" else "Locker",
				size,
				origin * CFrame.new(marker.x, size.Y / 2, marker.z) * CFrame.Angles(0, marker.rotation or 0, 0),
				if isDesk then OfficeConstants.DESK_COLOR else OfficeConstants.LOCKER_COLOR,
				furniture
			)
			OfficeArtKeyUtils.attachFirst(
				art,
				part,
				"furniture",
				OfficeArtKeyUtils.candidates(
					if isDesk then "desk" else "locker",
					marker.art,
					OfficeArtKeyUtils.roomType(OfficeLayoutUtils.room(layout, marker.room))
				)
			)
			if not isDesk then
				local room = OfficeLayoutUtils.room(layout, marker.room)
				if room ~= nil then
					local right = CFrame.Angles(0, marker.rotation or 0, 0).RightVector
					local function clearance(side: number): number
						local x, z = marker.x + right.X * side * size.X, marker.z + right.Z * side * size.X
						return math.min(x - room.minX, room.maxX - x, z - room.minZ, room.maxZ - z)
					end
					part:SetAttribute("OfficeDoorHingeSide", if clearance(1) > clearance(-1) then 1 else -1)
				end
			end
			if isDesk then
				-- The existing desktop remains the single monitor/keyboard fallback until decor supplies art.
				DeskVisual.build(part)
				part:SetAttribute("OfficeDeskDressed", true)
			end
			part:SetAttribute("OfficeMarkerId", marker.id)
			part:SetAttribute("ArtWallMounted", true)
			interactable(part, CargoConstants.SEARCH_KIND, false)
			-- A desk is a hiding spot too: under it (Hide). Lockers are not (their open and closed states).
			if isDesk then
				part:SetAttribute(HideConstants.FURNITURE_KIND_ATTRIBUTE, "desk")
				CollectionService:AddTag(part, HideConstants.FURNITURE_TAG)
			end
			searchables[marker.id] = part
		elseif
			marker.kind == "shelf"
			or marker.kind == "counter"
			or marker.kind == "plant"
			or marker.kind == "board"
		then
			local name = if marker.kind == "shelf"
				then "Shelf"
				elseif marker.kind == "counter" then "KitchenCounter"
				elseif marker.kind == "plant" then "OfficePlant"
				else "Corkboard"
			local size = if marker.kind == "shelf"
				then OfficeConstants.SHELF_SIZE
				elseif marker.kind == "counter" then OfficeConstants.COUNTER_SIZE
				elseif marker.kind == "plant" then OfficeConstants.PLANT_SIZE
				else OfficeConstants.BOARD_SIZE
			local part = block(
				name,
				size,
				origin
					* CFrame.new(
						marker.x,
						if marker.kind == "board" then OfficeConstants.BOARD_CENTER_HEIGHT else size.Y / 2,
						marker.z
					)
					* CFrame.Angles(0, marker.rotation or 0, 0),
				OfficeConstants.DESK_COLOR,
				furniture
			)
			part.CanCollide = marker.kind == "shelf" or marker.kind == "counter"
			part.CanQuery = part.CanCollide
			part.CanTouch = false
			part:SetAttribute("OfficeMarkerId", marker.id)
			part:SetAttribute("ArtWallMounted", marker.kind ~= "plant")
			local roomType = OfficeArtKeyUtils.roomType(OfficeLayoutUtils.room(layout, marker.room))
			if marker.kind == "plant" then
				OfficeArtKeyUtils.attachFirst(
					art,
					part,
					"cargo",
					OfficeArtKeyUtils.candidates("officePlant", marker.art, roomType)
				)
			else
				local key = if marker.kind == "shelf"
					then "shelf"
					elseif marker.kind == "counter" then "kitchenCounter"
					else "corkboard"
				OfficeArtKeyUtils.attachFirst(
					art,
					part,
					"furniture",
					OfficeArtKeyUtils.candidates(key, marker.art, roomType)
				)
				local supportY = part:GetAttribute("ArtSupportSurfaceY")
				if marker.kind == "counter" and type(supportY) == "number" then
					part.CanCollide = false
					part.CanQuery = false
					local support = block(
						"WorktopSupport",
						Vector3.new(size.X, supportY, size.Z),
						part.CFrame * CFrame.new(0, (supportY - size.Y) / 2, 0),
						part.Color,
						part
					)
					support.Transparency = 1
					support.CanTouch = false
				end
			end
		end
	end

	-- The truck's box is Harlow's no-go zone (he may walk the rest of the bay): a volume his paths cost math.huge
	-- (his kind's pathCosts).
	do
		local min, max = OfficeLoadingBayUtils.truckBox(layout.truck)
		local zone = block(
			OfficeConstants.SAFE_ZONE_NAME,
			max - min,
			origin * CFrame.new((min + max) / 2),
			OfficeConstants.WALL_COLOR,
			model
		)
		zone.Transparency = 1
		zone.CanCollide = false
		-- Queryable on purpose: PathfindingService ignores a PathfindingModifier on a CanQuery=false part. Downward
		-- floor probes must set RespectCanCollide so they skip this non-colliding volume.
		zone.CanQuery = true
		zone.CanTouch = false
		zone.CastShadow = false
		local modifier = Instance.new("PathfindingModifier")
		modifier.Label = OccupantConstants.SAFE_ZONE_LABEL
		modifier.PassThrough = false
		modifier.Parent = zone
	end

	local doors = OfficeDoorSystem.build(layout, origin, model, art)

	model.Parent = Workspace
	return {
		model = model,
		bed = bed,
		clock = clock,
		overtime = overtime,
		searchables = searchables,
		doors = doors,
	}
end

return OfficeBuildSystem
