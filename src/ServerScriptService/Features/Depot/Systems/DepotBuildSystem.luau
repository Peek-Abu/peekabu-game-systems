--!strict
--[=[
	DepotBuildSystem: builds the depot's static graybox once (Cleanup Crew spec §1 "polished feel on
	graybox", §3 step 1, §5): a floor and four walls; per truck a bed that is a Queue pad (QueueCapacity,
	QueueCountdown and QueueDestination set BEFORE the QueuePad tag, because Queue reads them once when the
	pad is tagged), a cab behind it and an empty truck tag shell above it (tagged, its truck number and seats as attributes; the client draws it); the contract board's sign shell with tonight's
	contract as attributes; the result board's sign shell, and `pinCard`, which hangs a returning player's review shell
	that only they see (in their PlayerGui, kept across respawns). Physical boards are SurfaceGui (the contract board
	with a built body behind its face, DepotBoardVisualSystem); truck tags are BillboardGui. The client
	draws (Figma World UI 2a, DepotBillboardSystem). Everything is anchored under one Model in Workspace.

	Hub v1: a concrete slab floor with real expansion joints, warm ceiling strips over the trucks and over each
	board, and the floor paint DepotMarkingUtils plans (bays, ramp hazard bands, lanes, oil stains, BAY n stencils)
	as thin non-colliding parts on top.

	`buildPlan` places the same gameplay pieces where a DepotHubRules plan says (a Studio-built hub's markers) and
	builds no room: the hub brings its own art. `build` is the graybox: buildPlan of the layout's plan, with the room.

	Instance shell; specs cover enclosure/surfaces, the lights, the floor paint and a hub plan's placement, and
	DepotLayoutRules / DepotHubRules validate the layouts.

	@class DepotBuildSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local HostConstants = require(ReplicatedStorage.Shared.Features.Host.Data.HostConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local TimecardConstants = require(ReplicatedStorage.Shared.Features.Timecard.Data.TimecardConstants)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)
local DepotMarkingUtils = require(ServerScriptService.Features.Depot.Utils.DepotMarkingUtils)
local DepotHubRules = require(ServerScriptService.Features.Depot.Rules.DepotHubRules)

-- A plan's board spot faces its readers; a board's sign is on its part's back face, so the part is turned round.
local FLIP = CFrame.Angles(0, math.pi, 0)

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
local BoardVisual = require(ServerScriptService.Features.Depot.Systems.DepotBoardVisualSystem)

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
		-- The kit's display face (Luckiest Guy), so the floor paint reads like the rest of the game's type.
		text.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
		text.TextColor3 = DepotLayoutConstants.MARKING.YELLOW
		text.Parent = gui
	end
end

local DepotBuildSystem = {}

-- The graybox room: walls, ceiling, floor, ceiling lights over the trucks and boards, and the floor paint.
local function buildRoom(layout: DepotTypes.Layout, origin: CFrame, model: Model)
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
	local lit: { DepotTypes.Point } = { layout.contractBoard, layout.resultBoard }
	if layout.crewBoard ~= nil then
		table.insert(lit, layout.crewBoard)
	end
	for _, board in lit do
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
end

-- A part `size` big whose bottom stands `lift` below its centre on `spot` (a plan board spot, which faces the
-- readers). Signs are drawn on a part's back face, so the part is turned round to face its sign at the readers too.
local function boardAt(name: string, size: Vector3, spot: CFrame, lift: number, color: Color3, parent: Instance): Part
	return block(name, size, spot * FLIP * CFrame.new(0, lift, 0), color, parent)
end

--[=[
	Builds the graybox depot: `layout` at `origin`, the room and every gameplay piece (buildPlan of
	DepotHubRules.fromLayout, with the room).
]=]
function DepotBuildSystem.build(
	layout: DepotTypes.Layout,
	origin: CFrame,
	contractAttributes: { [string]: string }
): Built
	return DepotBuildSystem.buildPlan(
		DepotHubRules.fromLayout(layout, origin),
		contractAttributes,
		{ layout = layout, origin = origin }
	)
end

--[=[
	Builds the depot's gameplay pieces where `plan` puts them, under one Model in Workspace: per truck its bed (a
	Queue pad: QueueCapacity, QueueCountdown and QueueDestination set BEFORE the QueuePad tag), its art and its tag
	shell; the contract, result and crew boards; the time clock and the daily sheet. With `room` (the graybox), the
	room too; a Studio-built hub brings its own.
]=]
function DepotBuildSystem.buildPlan(
	plan: DepotHubRules.Plan,
	contractAttributes: { [string]: string },
	room: { layout: DepotTypes.Layout, origin: CFrame }?
): Built
	local model = Instance.new("Model")
	model.Name = DepotLayoutConstants.MODEL_NAME
	if room ~= nil then
		buildRoom(room.layout, room.origin, model)
	end

	local bed = DepotLayoutConstants.BED_SIZE
	local trucks: { BuiltTruck } = {}
	for _, truck in plan.trucks do
		local truckFolder = folder(truck.id, model)
		-- Annotated: `block` returns a Part, and BuiltTruck.pad is a BasePart (table fields are invariant).
		local pad: BasePart = block(
			"TruckBed",
			bed,
			truck.cframe * CFrame.new(0, bed.Y / 2, 0),
			DepotLayoutConstants.BED_COLOR,
			truckFolder
		)
		pad:SetAttribute(QueueConstants.CAPACITY_ATTRIBUTE, truck.capacity)
		pad:SetAttribute(QueueConstants.COUNTDOWN_ATTRIBUTE, truck.countdown)
		pad:SetAttribute(QueueConstants.DESTINATION_ATTRIBUTE, DepotConstants.ROLE_SHIFT)
		-- Crew hosting: the first player in hosts the truck and starts the trip (HostServiceServer).
		pad:SetAttribute(QueueConstants.HOLD_ATTRIBUTE, true)
		CollectionService:AddTag(pad, QueueConstants.TAG)
		TruckVisual.build(pad, truckFolder)
		local tag = shell("PadTag", pad, DepotConstants.BILLBOARD_PX.truck, DepotLayoutConstants.PAD_TAG_OFFSET)
		tag:SetAttribute(DepotConstants.TRUCK_ATTRIBUTE, truck.index)
		-- The sign of an empty truck shows a regular truck's seats; a hosted one shows its live seats (Queue's).
		tag:SetAttribute(DepotConstants.CAPACITY_ATTRIBUTE, math.min(truck.capacity, HostConstants.SEATS))
		CollectionService:AddTag(tag, DepotConstants.BILLBOARD_TAGS.truck)
		tag.Parent = truckFolder
		table.insert(trucks, { id = truck.id, index = truck.index, capacity = truck.capacity, pad = pad })
	end

	local boards = folder("Boards", model)
	local boardSize = DepotLayoutConstants.BOARD_SIZE
	local contractBoard = boardAt(
		"ContractBoard",
		boardSize,
		plan.boards.contract,
		boardSize.Y / 2,
		DepotLayoutConstants.BOARD_COLOR,
		boards
	)
	-- The board's prompt opens the work order (M3 UI): attributes first, then the tag (Interaction reads them on tag).
	-- The sign draws the whole board; the part stays as its adornee, collision and prompt anchor but is not seen.
	contractBoard.Transparency = 1
	-- Its body (frame, plywood back, bracing, kickstand, company sticker) sits behind the sign's face, so the board
	-- has thickness edge-on and a finished back.
	BoardVisual.build(contractBoard, boards)
	contractBoard:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, DepotConstants.BOARD_KIND)
	CollectionService:AddTag(contractBoard, InteractionConstants.TAG)
	local contractSign = surface("ContractSign", contractBoard, DepotConstants.BILLBOARD_PX.contract)
	for key, value in contractAttributes do
		contractSign:SetAttribute(key, value)
	end
	CollectionService:AddTag(contractSign, DepotConstants.BILLBOARD_TAGS.contract)
	contractSign.Parent = boards
	-- The sign draws the whole board; the part stays as its adornee but is not seen.
	local resultPx = DepotConstants.BILLBOARD_PX.result
	local resultSize = Vector3.new(resultPx.X / 80, resultPx.Y / 80, 1)
	local resultBoard = boardAt(
		"ResultBoard",
		resultSize,
		plan.boards.result,
		resultSize.Y / 2,
		DepotLayoutConstants.BOARD_COLOR,
		boards
	)
	local resultSign = surface("ResultSign", resultBoard, resultPx)
	CollectionService:AddTag(resultSign, DepotConstants.BILLBOARD_TAGS.result)
	resultSign.Parent = boards
	-- The weekly crew leaderboard beside it (drawn by the client from the `crewBoard` world entry).
	local crewSpot = plan.boards.crew
	if crewSpot ~= nil then
		local crewPx = DepotConstants.BILLBOARD_PX.crew
		-- The result board's scale (80 px a stud), so the two signs read as a pair.
		local crewSize = Vector3.new(crewPx.X / 80, crewPx.Y / 80, 1)
		local crewBoard =
			boardAt("CrewBoard", crewSize, crewSpot, crewSize.Y / 2, DepotLayoutConstants.BOARD_COLOR, boards)
		local crewSign = surface("CrewSign", crewBoard, crewPx)
		CollectionService:AddTag(crewSign, DepotConstants.BILLBOARD_TAGS.crew)
		crewSign.Parent = boards
	end

	-- A small physical clock (in the graybox: clear of both board silhouettes and the spawn lane).
	local clockSpot = plan.boards.clock
	if clockSpot ~= nil then
		local clock = boardAt("WeeklyTimeClock", Vector3.new(3, 4, 1), clockSpot, 2, Color3.fromHex("1f6e66"), boards)
		clock:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, TimecardConstants.CLOCK_KIND)
		CollectionService:AddTag(clock, InteractionConstants.TAG)
		local clockFace = surface("ClockFace", clock, Vector2.new(300, 400))
		local clockText = Instance.new("TextLabel")
		clockText.Size = UDim2.fromScale(1, 1)
		clockText.BackgroundColor3 = Color3.fromHex("f1dfa9")
		clockText.TextColor3 = Color3.fromHex("2e3536")
		clockText.Font = Enum.Font.GothamBold
		clockText.TextSize = 32
		clockText.TextWrapped = true
		clockText.Text = "WEEKLY\nTIMECARD\n\nVIEW YOUR CARD\n\nANY 5 OF 7 DAYS"
		clockText.Parent = clockFace
		clockFace.Parent = clock
	end
	local dailySpot = plan.boards.daily
	if dailySpot ~= nil then
		local daily = boardAt(
			"DailyWorkOrderSheet",
			Vector3.new(2.8, 3.6, 0.18),
			dailySpot,
			2.2,
			Color3.fromHex("f1dfa9"),
			boards
		)
		daily.CanCollide = false
		daily:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, TimecardConstants.DAILY_KIND)
		CollectionService:AddTag(daily, InteractionConstants.TAG)
		local sheet = surface("DailyOrderFace", daily, Vector2.new(280, 360))
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = 28
		text.TextColor3 = Color3.fromHex("2e3536")
		text.TextWrapped = true
		text.Text = "TODAY'S\nJOB\n\nBONUS CREDITS\n\nREAD IT HERE"
		text.Parent = sheet
		sheet.Parent = daily
	end
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
