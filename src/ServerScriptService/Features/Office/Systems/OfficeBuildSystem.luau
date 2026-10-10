--!strict
--[=[
	OfficeBuildSystem: builds the office's static graybox from a layout, once (Cleanup Crew spec §1
	"polished feel on graybox", §5): a floor per room, walls broken around doors (OfficeLayoutUtils.
	wallSegments, merged so a shared wall is built once), the truck (its bed is the banking zone and carries Cargo's Load prompt; a cab at its back, inside the bay),
	the time clock (Shift's Clock out prompt), and a desk or locker on every desk / locker marker (Cargo's
	Search prompt, off until Cargo stocks it). Everything is anchored under one Model in Workspace at the
	layout's origin. No ceiling: the graybox keeps the camera free.

	Spec-exempt shell (Instances); the layout is the one the specced OfficeLayoutRules validated.

	@class OfficeBuildSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local OfficeServer = ServerScriptService.Features.Office
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

export type Built = {
	model: Model,
	bed: BasePart,
	clock: BasePart,
	searchables: { [string]: BasePart },
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

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

-- Every room emits its own walls, so a wall two rooms share comes out twice (and rooms of different
-- lengths overlap only partly). Union the pieces per line so each stretch of wall is built exactly once.
local function mergedWalls(layout: OfficeTypes.Layout): { OfficeTypes.Segment }
	local lines: { [string]: { horizontal: boolean, fixed: number, spans: { { number } } } } = {}
	for _, room in layout.rooms do
		for _, segment in OfficeLayoutUtils.wallSegments(room, layout.doors) do
			local horizontal = segment.z1 == segment.z2
			local fixed = if horizontal then segment.z1 else segment.x1
			local key = `{if horizontal then "h" else "v"}{fixed}`
			local line = lines[key]
			if line == nil then
				line = { horizontal = horizontal, fixed = fixed, spans = {} }
				lines[key] = line
			end
			local from = if horizontal then segment.x1 else segment.z1
			local to = if horizontal then segment.x2 else segment.z2
			table.insert(line.spans, { from, to })
		end
	end
	local merged: { OfficeTypes.Segment } = {}
	for _, line in lines do
		table.sort(line.spans, function(a, b)
			return a[1] < b[1]
		end)
		local from, to = line.spans[1][1], line.spans[1][2]
		local function emit()
			if line.horizontal then
				table.insert(merged, { x1 = from, z1 = line.fixed, x2 = to, z2 = line.fixed })
			else
				table.insert(merged, { x1 = line.fixed, z1 = from, x2 = line.fixed, z2 = to })
			end
		end
		for index = 2, #line.spans do
			local span = line.spans[index]
			if span[1] <= to + 1e-6 then
				to = math.max(to, span[2])
			else
				emit()
				from, to = span[1], span[2]
			end
		end
		emit()
	end
	return merged
end

local OfficeBuildSystem = {}

function OfficeBuildSystem.build(layout: OfficeTypes.Layout, origin: CFrame): Built
	local model = Instance.new("Model")
	model.Name = OfficeConstants.MODEL_NAME
	local height = OfficeConstants.WALL_HEIGHT
	local thickness = OfficeConstants.WALL_THICKNESS
	local floorThickness = OfficeConstants.FLOOR_THICKNESS
	local colors = OfficeConstants.FLOOR_COLORS

	for index, room in layout.rooms do
		local roomFolder = folder(room.name, model)
		local width = room.maxX - room.minX
		local depth = room.maxZ - room.minZ
		block(
			"Floor",
			Vector3.new(width, floorThickness, depth),
			origin * CFrame.new(room.minX + width / 2, -floorThickness / 2, room.minZ + depth / 2),
			colors[(index - 1) % #colors + 1],
			roomFolder
		)
	end

	local wallFolder = folder("Walls", model)
	for _, segment in mergedWalls(layout) do
		local horizontal = segment.z1 == segment.z2
		local length = if horizontal then segment.x2 - segment.x1 else segment.z2 - segment.z1
		local size = if horizontal
			then Vector3.new(length + thickness, height, thickness)
			else Vector3.new(thickness, height, length + thickness)
		local centre = CFrame.new((segment.x1 + segment.x2) / 2, height / 2, (segment.z1 + segment.z2) / 2)
		block("Wall", size, origin * centre, OfficeConstants.WALL_COLOR, wallFolder)
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
	local cab = OfficeConstants.CAB_SIZE
	block(
		"TruckCab",
		cab,
		origin * CFrame.new(truck.minX + bedWidth / 2, cab.Y / 2, truck.maxZ + cab.Z / 2),
		OfficeConstants.TRUCK_COLOR,
		truckFolder
	)
	local clockSize = OfficeConstants.CLOCK_SIZE
	local clock = block(
		"TimeClock",
		clockSize,
		origin * CFrame.new(truck.clockX, clockSize.Y / 2, truck.clockZ),
		OfficeConstants.CLOCK_COLOR,
		truckFolder
	)
	interactable(clock, ShiftConstants.CLOCK_OUT_KIND, true)

	local furniture = folder("Furniture", model)
	local searchables: { [string]: BasePart } = {}
	for _, marker in layout.markers do
		if marker.kind == "desk" or marker.kind == "locker" then
			local isDesk = marker.kind == "desk"
			local size = if isDesk then OfficeConstants.DESK_SIZE else OfficeConstants.LOCKER_SIZE
			local part = block(
				if isDesk then "Desk" else "Locker",
				size,
				origin * CFrame.new(marker.x, size.Y / 2, marker.z),
				if isDesk then OfficeConstants.DESK_COLOR else OfficeConstants.LOCKER_COLOR,
				furniture
			)
			interactable(part, CargoConstants.SEARCH_KIND, false)
			searchables[marker.id] = part
		end
	end

	model.Parent = Workspace
	return { model = model, bed = bed, clock = clock, searchables = searchables }
end

return OfficeBuildSystem
