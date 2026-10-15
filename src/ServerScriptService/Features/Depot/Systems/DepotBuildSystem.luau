--!strict
--[=[
	DepotBuildSystem: builds the depot's static graybox once (Cleanup Crew spec §1 "polished feel on
	graybox", §3 step 1, §5): a floor and four walls; per truck a bed that is a Queue pad (QueueCapacity,
	QueueCountdown and QueueDestination set BEFORE the QueuePad tag, because Queue reads them once when the
	pad is tagged), a cab behind it and an empty truck tag shell above it (tagged, its truck number and seats as attributes; the client draws it); the contract board's sign shell with tonight's
	contract as attributes; the result board's sign shell, and `pinCard`, which hangs a returning player's review shell
	that only they see (in their PlayerGui, kept across respawns). Physical boards are SurfaceGui; truck tags are BillboardGui. The client
	draws (Figma World UI 2a, DepotBillboardSystem). Everything is anchored under one Model in Workspace.

	Hub v1: a concrete slab floor with real expansion joints, warm ceiling strips over the trucks and over each
	board, and the floor paint DepotMarkingUtils plans (bays, ramp hazard bands, lanes, oil stains, BAY n stencils)
	as thin non-colliding parts on top.

	Instance shell; specs cover enclosure/surfaces, the lights and the floor paint, and DepotLayoutRules validates the
	layout.

	@class DepotBuildSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)
local DepotMarkingUtils = require(ServerScriptService.Features.Depot.Utils.DepotMarkingUtils)

export type BuiltTruck = {
	id: string,
	-- 1-based, in layout order: "TRUCK 1".
	index: number,
	capacity: number,
	pad: BasePart,
}

export type Built = {
	model: Model,
	trucks: { BuiltTruck },
	resultBoard: BasePart,
	contractBoard: BasePart,
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

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

-- An empty world-sign shell over `adornee` (M3b world UI), sized in studs from its Figma design (`design` px times
-- DepotConstants.STUDS_PER_PX). The client draws into it (DepotBillboardSystem). The caller writes its attributes, then
-- tags and parents it. Returned unparented.
local function shell(name: string, adornee: BasePart, design: Vector2, offset: Vector3): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	local studs = design * DepotConstants.STUDS_PER_PX
	gui.Size = UDim2.fromScale(studs.X, studs.Y)
	gui.StudsOffset = offset
	gui.MaxDistance = DepotLayoutConstants.LABEL_MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return gui
end

local function surface(name: string, adornee: BasePart, design: Vector2): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = design
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = DepotLayoutConstants.LABEL_MAX_DISTANCE
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return gui
end

local TruckVisual = require(ServerScriptService.Features.Depot.Systems.DepotTruckVisualSystem)

-- Floor paint is a decal-thin layer: nothing collides with, raycasts against, touches or shadows it.
local function decalPart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = block(name, size, cframe, DepotLayoutConstants.FLOOR_COLOR, parent)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- The garage floor: concrete slabs (DepotMarkingUtils.slabs) on a darker joint bed that shows only in the expansion
-- joints between them. The slabs top out at the floor plane; the bed sits a joint's depth below.
local function layFloor(layout: DepotTypes.Layout, origin: CFrame, model: Model)
	local floor = layout.floor
	local width = floor.maxX - floor.minX
	local depth = floor.maxZ - floor.minZ
	local thickness = DepotLayoutConstants.FLOOR_THICKNESS
	local below = DepotLayoutConstants.MARKING.JOINT_DEPTH
	local container = folder("Floor", model)
	local base = block(
		"Base",
		Vector3.new(width, thickness, depth),
		origin * CFrame.new(floor.minX + width / 2, -below - thickness / 2, floor.minZ + depth / 2),
		DepotLayoutConstants.FLOOR_COLOR,
		container
	)
	base.Material = Enum.Material.Concrete
	local slabs = folder("Slabs", container)
	for index, slab in DepotMarkingUtils.slabs(floor) do
		local part = block(`Slab{index}`, slab.size, origin * CFrame.new(slab.position), slab.color, slabs)
		part.Material = Enum.Material.Concrete
	end
end

-- The bays, ramp hazard bands, lanes, oil stains and BAY n stencils (DepotMarkingUtils' plan), in the depot's space.
local function paintFloor(layout: DepotTypes.Layout, origin: CFrame, model: Model)
	local markings = folder("FloorMarkings", model)
	local plan = DepotMarkingUtils.plan(layout)
	for _, piece in plan.paints do
		local at = origin * CFrame.new(piece.position)
		local size = piece.size
		if piece.round then
			-- A cylinder's axis is its X: a quarter turn about Z lays the disc flat.
			at *= CFrame.Angles(0, 0, math.pi / 2)
			size = Vector3.new(size.Y, size.X, size.Z)
		end
		local part = decalPart(piece.name, size, at, markings)
		if piece.round then
			part.Shape = Enum.PartType.Cylinder
		end
		part.Color = piece.color
		part.Transparency = piece.transparency
	end
	for _, label in plan.labels do
		-- A Top-face SurfaceGui's width runs along the part's -Z: a quarter turn (and the size swapped to match) lays
		-- the text along -X, so it reads left to right, upright, for someone walking from the spawns toward the
		-- truck (+Z). The footprint is unchanged.
		local part = decalPart(
			label.name,
			Vector3.new(label.size.Z, label.size.Y, label.size.X),
			origin * CFrame.new(label.position) * CFrame.Angles(0, math.pi / 2, 0),
			markings
		)
		part.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Stencil"
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = DepotLayoutConstants.STENCIL_PIXELS_PER_STUD
		gui.LightInfluence = 1
		gui.Parent = part
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Text = label.text
		text.TextScaled = true
		text.FontFace = Font.new(Font.fromEnum(Enum.Font.Oswald).Family, Enum.FontWeight.Bold)
		text.TextColor3 = DepotLayoutConstants.MARKING.YELLOW
		text.Parent = gui
	end
end

local DepotBuildSystem = {}

function DepotBuildSystem.build(
	layout: DepotTypes.Layout,
	origin: CFrame,
	contractAttributes: { [string]: string }
): Built
	local model = Instance.new("Model")
	model.Name = DepotLayoutConstants.MODEL_NAME
	local floor = layout.floor
	local width = floor.maxX - floor.minX
	local depth = floor.maxZ - floor.minZ
	local centreX = floor.minX + width / 2
	local centreZ = floor.minZ + depth / 2
	layFloor(layout, origin, model)

	local height = DepotLayoutConstants.WALL_HEIGHT
	local thickness = DepotLayoutConstants.WALL_THICKNESS
	local walls = folder("Walls", model)
	local across = Vector3.new(width + thickness, height, thickness)
	local along = Vector3.new(thickness, height, depth + thickness)
	for _, wall in
		{
			{ size = across, x = centreX, z = floor.minZ },
			{ size = across, x = centreX, z = floor.maxZ },
			{ size = along, x = floor.minX, z = centreZ },
			{ size = along, x = floor.maxX, z = centreZ },
		}
	do
		block(
			"Wall",
			wall.size,
			origin * CFrame.new(wall.x, height / 2, wall.z),
			DepotLayoutConstants.WALL_COLOR,
			walls
		)
	end

	block(
		"Ceiling",
		Vector3.new(width + thickness, 1, depth + thickness),
		origin * CFrame.new(centreX, height + 0.5, centreZ),
		DepotLayoutConstants.WALL_COLOR,
		model
	)
	-- Warm tungsten strips over the trucks, and a brighter one over each board (hub v1).
	local lights = folder("Lights", model)
	local function fixture(name: string, x: number, z: number, color: Color3, range: number, brightness: number)
		local strip =
			block(name, DepotLayoutConstants.LIGHT_SIZE, origin * CFrame.new(x, height - 0.2, z), color, lights)
		strip.Material = Enum.Material.Neon
		strip.CanCollide = false
		strip.CanQuery = false
		strip.CanTouch = false
		strip.CastShadow = false
		local light = Instance.new("PointLight")
		light.Range = range
		light.Brightness = brightness
		light.Color = color
		light.Parent = strip
	end
	for _, x in DepotLayoutConstants.LIGHT_XS do
		fixture(
			"GarageLight",
			x,
			DepotLayoutConstants.LIGHT_Z,
			DepotLayoutConstants.LIGHT_COLOR,
			DepotLayoutConstants.LIGHT_RANGE,
			DepotLayoutConstants.LIGHT_BRIGHTNESS
		)
	end
	for _, board in { layout.contractBoard, layout.resultBoard } do
		fixture(
			"BoardLight",
			board.x,
			board.z + DepotLayoutConstants.BOARD_LIGHT_SETBACK,
			DepotLayoutConstants.BOARD_LIGHT_COLOR,
			DepotLayoutConstants.BOARD_LIGHT_RANGE,
			DepotLayoutConstants.BOARD_LIGHT_BRIGHTNESS
		)
	end

	paintFloor(layout, origin, model)

	local bed = DepotLayoutConstants.BED_SIZE
	local trucks: { BuiltTruck } = {}
	for index, truck in layout.trucks do
		local truckFolder = folder(truck.id, model)
		-- Annotated: `block` returns a Part, and BuiltTruck.pad is a BasePart (table fields are invariant).
		local pad: BasePart = block(
			"TruckBed",
			bed,
			origin * CFrame.new(truck.x, bed.Y / 2, truck.z),
			DepotLayoutConstants.BED_COLOR,
			truckFolder
		)
		pad:SetAttribute(QueueConstants.CAPACITY_ATTRIBUTE, truck.capacity)
		pad:SetAttribute(QueueConstants.COUNTDOWN_ATTRIBUTE, truck.countdown)
		pad:SetAttribute(QueueConstants.DESTINATION_ATTRIBUTE, DepotConstants.ROLE_SHIFT)
		CollectionService:AddTag(pad, QueueConstants.TAG)
		TruckVisual.build(pad, truckFolder)
		local tag = shell("PadTag", pad, DepotConstants.BILLBOARD_PX.truck, DepotLayoutConstants.PAD_TAG_OFFSET)
		tag:SetAttribute(DepotConstants.TRUCK_ATTRIBUTE, index)
		tag:SetAttribute(DepotConstants.CAPACITY_ATTRIBUTE, truck.capacity)
		CollectionService:AddTag(tag, DepotConstants.BILLBOARD_TAGS.truck)
		tag.Parent = truckFolder
		table.insert(trucks, { id = truck.id, index = index, capacity = truck.capacity, pad = pad })
	end

	local boards = folder("Boards", model)
	local boardSize = DepotLayoutConstants.BOARD_SIZE
	local contractPoint = layout.contractBoard
	local contractBoard = block(
		"ContractBoard",
		boardSize,
		origin * CFrame.new(contractPoint.x, boardSize.Y / 2, contractPoint.z),
		DepotLayoutConstants.BOARD_COLOR,
		boards
	)
	-- The board's prompt opens the work order (M3 UI): attributes first, then the tag (Interaction reads them on tag).
	-- The sign draws the whole board; the part stays as its adornee, collision and prompt anchor but is not seen.
	contractBoard.Transparency = 1
	contractBoard:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, DepotConstants.BOARD_KIND)
	CollectionService:AddTag(contractBoard, InteractionConstants.TAG)
	local contractSign = surface("ContractSign", contractBoard, DepotConstants.BILLBOARD_PX.contract)
	for key, value in contractAttributes do
		contractSign:SetAttribute(key, value)
	end
	CollectionService:AddTag(contractSign, DepotConstants.BILLBOARD_TAGS.contract)
	contractSign.Parent = boards
	local resultPoint = layout.resultBoard
	local resultBoard = block(
		"ResultBoard",
		boardSize,
		origin * CFrame.new(resultPoint.x, boardSize.Y / 2, resultPoint.z),
		DepotLayoutConstants.BOARD_COLOR,
		boards
	)
	-- The sign draws the whole board; the part stays as its adornee but is not seen.
	resultBoard.Size =
		Vector3.new(DepotConstants.BILLBOARD_PX.result.X / 80, DepotConstants.BILLBOARD_PX.result.Y / 80, 1)
	resultBoard.CFrame = origin * CFrame.new(resultPoint.x, resultBoard.Size.Y / 2, resultPoint.z)
	local resultSign = surface("ResultSign", resultBoard, DepotConstants.BILLBOARD_PX.result)
	CollectionService:AddTag(resultSign, DepotConstants.BILLBOARD_TAGS.result)
	resultSign.Parent = boards

	model.Parent = Workspace
	return { model = model, trucks = trucks, resultBoard = resultBoard, contractBoard = contractBoard }
end

--[=[
	Pins `attributes` (ShiftCardUtils.attributes) on the result board for `player` only: a review shell in their
	PlayerGui (replacing their last card, kept across respawns) at the board's spot and size, which their client draws as
	the whole board with the card on it (DepotBillboardSystem). Yields up to PLAYER_GUI_WAIT seconds for the PlayerGui;
	false when it never appears or the player left.
]=]
function DepotBuildSystem.pinCard(
	player: Player,
	board: BasePart,
	attributes: { [string]: string | number | boolean }
): boolean
	local found = player:WaitForChild("PlayerGui", DepotLayoutConstants.PLAYER_GUI_WAIT)
	if found == nil or not found:IsA("PlayerGui") or player.Parent == nil then
		return false
	end
	-- The old card goes after the new one is parented, so a client's review set never drops to 0 in between.
	local old = found:FindFirstChild(DepotLayoutConstants.CARD_NAME)
	local card = surface(DepotLayoutConstants.CARD_NAME, board, DepotConstants.BILLBOARD_PX.result)
	for key, value in attributes do
		card:SetAttribute(key, value)
	end
	CollectionService:AddTag(card, DepotConstants.BILLBOARD_TAGS.review)
	card.ResetOnSpawn = false
	card.Parent = found
	if old ~= nil then
		old:Destroy()
	end
	return true
end

return DepotBuildSystem
