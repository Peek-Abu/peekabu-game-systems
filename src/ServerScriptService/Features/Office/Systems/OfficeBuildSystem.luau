--!strict
--[=[
	OfficeBuildSystem: builds the office's graybox from the current seeded layout (Cleanup Crew spec §1
	"polished feel on graybox", §5): a floor per room (its material by room type), the truck (its bed is the banking
	zone and carries Cargo's Load prompt; a cab at its back, inside the bay), the time clock inside the truck's box
	(Shift's Clock out prompt), the overtime sheet beside it on the box's front wall (Shift's Start overtime prompt, off
	until Shift opens it once the quota is met), and a desk or locker on every desk / locker marker (Cargo's Search
	prompt, off until Cargo stocks it; a desk is also a hiding spot, tagged for Hide). The walls, door casings and
	lintels, glass panes, ceilings and ceiling lights (tagged for Harlow's tells) are OfficeShellVisualSystem's.
	M2: the truck box's PathfindingModifier volume (Harlow walks the loading bay but never paths into the truck's box).
	Everything is anchored under one Model in Workspace at the layout's origin.
	Art keys: every furniture attach goes through OfficeArtKeyUtils (a marker's own `art` key, then the default key's
	room-type variant, then the default key), so a kit may restyle one piece (serverRack for a shelf), and every
	Attachment of an attached template named in OfficeConstants.ACCENT_LIGHTS (a server rack's LedLight) gets that
	accent's point light (OfficeLightingUtils.accentFor). A board stands on the floor on its own legs.
	Doors: OfficeDoorSystem adds a real leaf to each solid or glass door plus a locked flush leaf on every facade
	(`Built.doors`, destroyed with the office).
	Outside (generated maps): the truck's bed is turned by `truck.yaw` (its art and paperwork follow the bed), and
	OfficeGroundsSystem adds the Outdoors safe volumes, the entrances' outside door hit boxes and inside exits
	(`Built.outside`).

	Instance shell; specs cover the instance shell, and OfficeLayoutRules validates the layout.

	@class OfficeBuildSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)

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
local OfficeLightingUtils = require(OfficeServer.Utils.OfficeLightingUtils)
local OfficeDoorSystem = require(script.Parent.OfficeDoorSystem)
local OfficeGroundsSystem = require(script.Parent.OfficeGroundsSystem)

local log = Logger.new("OfficeBuildSystem")

export type Built = {
	model: Model,
	bed: BasePart,
	clock: BasePart,
	overtime: BasePart,
	searchables: { [string]: BasePart },
	doors: OfficeDoorSystem.DoorSet,
	-- The teleport entrances' inside exits and outside doors (empty without grounds).
	outside: OfficeGroundsSystem.Built,
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

local function interactable(part: BasePart, kind: string, enabled: boolean)
	part:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, kind)
	if not enabled then
		part:SetAttribute(InteractionConstants.ENABLED_ATTRIBUTE, false)
	end
	CollectionService:AddTag(part, InteractionConstants.TAG)
end

-- Templates may not carry lights (ArtKitRules): an accent part holds an Attachment named in ACCENT_LIGHTS for the code
-- to hang that accent's shadowless glow on, whichever template attached.
local function accentLights(visual: Instance?)
	if visual == nil then
		return
	end
	for _, descendant in visual:GetDescendants() do
		local accent = if descendant:IsA("Attachment") then OfficeLightingUtils.accentFor(descendant.Name) else nil
		if accent ~= nil then
			local glow = Instance.new("PointLight")
			glow.Color = accent.color
			glow.Range = accent.range
			glow.Brightness = accent.brightness
			glow.Shadows = false
			glow.Parent = descendant
		end
	end
end

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local TruckVisual = require(ServerScriptService.Features.Depot.Systems.DepotTruckVisualSystem)
local DeskVisual = require(script.Parent.OfficeDeskVisualSystem)
local Shell = require(script.Parent.OfficeShellVisualSystem)

local OfficeBuildSystem = {}

function OfficeBuildSystem.build(
	layout: OfficeTypes.Layout,
	origin: CFrame,
	visuals: ArtVisualSystem.Controller?,
	seed: number?
): Built
	local art = visuals or ArtVisualSystem
	local model = Instance.new("Model")
	model.Name = OfficeConstants.MODEL_NAME
	model:SetAttribute("ArtKitId", layout.artKit or OfficeConstants.ART_KIT_ID)
	local floorThickness = OfficeConstants.FLOOR_THICKNESS

	for _, room in layout.rooms do
		local roomFolder = folder(room.name, model)
		local width = room.maxX - room.minX
		local depth = room.maxZ - room.minZ
		local floor = block(
			"Floor",
			Vector3.new(width, floorThickness, depth),
			origin * CFrame.new(room.minX + width / 2, -floorThickness / 2, room.minZ + depth / 2),
			OfficeConstants.WALL_COLOR,
			roomFolder
		)
		-- Only the loading bay (the start room) is vinyl; other authored rooms have no type and take carpet.
		local roomType = if room.id == layout.startRoom or room.id == "bay"
			then "bay"
			else OfficeArtKeyUtils.roomType(room)
		Shell.apply(floor, Shell.floorMaterial(roomType))
	end
	Shell.build(layout, origin, model, art, nil, seed)

	local truckFolder = folder("Truck", model)
	local truck = layout.truck
	local bedWidth = truck.maxX - truck.minX
	local bedDepth = truck.maxZ - truck.minZ
	local bedHeight = OfficeConstants.BED_HEIGHT
	local bed = block(
		"TruckBed",
		Vector3.new(bedWidth, bedHeight, bedDepth),
		origin
			* CFrame.new(truck.minX + bedWidth / 2, bedHeight / 2, truck.minZ + bedDepth / 2)
			* CFrame.Angles(0, truck.yaw or 0, 0),
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
			local visual = OfficeArtKeyUtils.attachFirst(
				art,
				part,
				"furniture",
				OfficeArtKeyUtils.candidates(
					if isDesk then "desk" else "locker",
					marker.art,
					OfficeArtKeyUtils.roomType(OfficeLayoutUtils.room(layout, marker.room))
				)
			)
			accentLights(visual)
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
			-- The art's own size when the marker restyles it (ART_SIZES), the kind's size otherwise.
			local size = OfficeLayoutUtils.markerSize(marker)
			if size == nil then
				error(`marker "{marker.id}" ({marker.kind}) has no size`)
			end
			local part = block(
				name,
				size,
				origin * CFrame.new(marker.x, size.Y / 2, marker.z) * CFrame.Angles(0, marker.rotation or 0, 0),
				OfficeConstants.DESK_COLOR,
				furniture
			)
			-- A standing board is floor furniture like a shelf: solid and queryable.
			part.CanCollide = marker.kind == "shelf" or marker.kind == "counter" or marker.kind == "board"
			part.CanQuery = part.CanCollide
			part.CanTouch = false
			part:SetAttribute("OfficeMarkerId", marker.id)
			-- Shelves and counters back onto a wall (ArtVisualSystem pushes their art to the proxy's back face); a plant
			-- and a free-standing board keep their art centred.
			if marker.kind == "shelf" or marker.kind == "counter" then
				part:SetAttribute("ArtWallMounted", true)
			end
			local roomType = OfficeArtKeyUtils.roomType(OfficeLayoutUtils.room(layout, marker.room))
			if marker.kind == "plant" then
				local visual = OfficeArtKeyUtils.attachFirst(
					art,
					part,
					"cargo",
					OfficeArtKeyUtils.candidates("officePlant", marker.art, roomType)
				)
				accentLights(visual)
			else
				local key = if marker.kind == "shelf"
					then "shelf"
					elseif marker.kind == "counter" then "kitchenCounter"
					else "corkboard"
				local visual = OfficeArtKeyUtils.attachFirst(
					art,
					part,
					"furniture",
					OfficeArtKeyUtils.candidates(key, marker.art, roomType)
				)
				accentLights(visual)
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
	local outside = OfficeGroundsSystem.build(layout, origin, model, art)

	model.Parent = Workspace
	return {
		model = model,
		bed = bed,
		clock = clock,
		overtime = overtime,
		searchables = searchables,
		doors = doors,
		outside = outside,
	}
end

--[=[
	Destroys every office model in `container` (default Workspace: a child named OfficeConstants.MODEL_NAME) except
	`keep`, warns "removed N stray office model(s)" when there were any, and returns how many it removed.
	OfficeServiceServer's rebuild and first build call this so a model its owner lost track of (a failed or interrupted
	cleanup in a shift transit) can never stand beside the new office as a second set of walls and door leaves.
]=]
function OfficeBuildSystem.clearStrays(keep: Model?, container: Instance?): number
	local removed = 0
	for _, child in (container or Workspace):GetChildren() do
		if child.Name == OfficeConstants.MODEL_NAME and child ~= keep then
			child:Destroy()
			removed += 1
		end
	end
	if removed > 0 then
		log:warn(`removed {removed} stray office model(s)`)
	end
	return removed
end

return OfficeBuildSystem
