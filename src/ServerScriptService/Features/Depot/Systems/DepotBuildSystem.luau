--!strict
--[=[
	DepotBuildSystem: builds the depot's static graybox once (Cleanup Crew spec §1 "polished feel on
	graybox", §3 step 1, §5): a floor and four walls; per truck a bed that is a Queue pad (QueueCapacity,
	QueueCountdown and QueueDestination set BEFORE the QueuePad tag, because Queue reads them once when the
	pad is tagged), a cab behind it and a label above it; the contract board with tonight's contract; the
	result board, where `pinCard` hangs a returning player's card that only they see (a BillboardGui in their
	PlayerGui, kept across respawns). Plain placeholder look on purpose: the final boards and labels wait for
	the developer's Figma approval (spec §7). Everything is anchored under one Model in Workspace.

	Spec-exempt shell (Instances); the layout is the one the specced DepotLayoutRules validated.

	@class DepotBuildSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)

export type BuiltTruck = {
	id: string,
	-- 1-based, in layout order: "TRUCK 1".
	index: number,
	capacity: number,
	pad: BasePart,
	label: TextLabel,
}

export type Built = {
	model: Model,
	trucks: { BuiltTruck },
	resultBoard: BasePart,
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

-- A plain text billboard over `adornee` (size in studs). Returned unparented with its label.
local function billboard(
	name: string,
	adornee: BasePart,
	size: Vector2,
	offset: Vector3,
	text: string
): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(size.X, size.Y)
	gui.StudsOffset = offset
	gui.MaxDistance = DepotLayoutConstants.LABEL_MAX_DISTANCE
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = DepotLayoutConstants.LABEL_BACKGROUND
	label.BackgroundTransparency = 0.1
	label.TextColor3 = DepotLayoutConstants.LABEL_TEXT
	label.Font = Enum.Font.SourceSansSemibold
	label.TextScaled = true
	label.TextWrapped = true
	-- Card text is decoded teleport data (client-forgeable): never markup.
	label.RichText = false
	label.Text = text
	label.Parent = gui
	return gui, label
end

local DepotBuildSystem = {}

function DepotBuildSystem.build(layout: DepotTypes.Layout, origin: CFrame, boardLines: { string }): Built
	local model = Instance.new("Model")
	model.Name = DepotLayoutConstants.MODEL_NAME
	local floor = layout.floor
	local width = floor.maxX - floor.minX
	local depth = floor.maxZ - floor.minZ
	local centreX = floor.minX + width / 2
	local centreZ = floor.minZ + depth / 2
	local floorThickness = DepotLayoutConstants.FLOOR_THICKNESS
	block(
		"Floor",
		Vector3.new(width, floorThickness, depth),
		origin * CFrame.new(centreX, -floorThickness / 2, centreZ),
		DepotLayoutConstants.FLOOR_COLOR,
		model
	)

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

	local bed = DepotLayoutConstants.BED_SIZE
	local cab = DepotLayoutConstants.CAB_SIZE
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
		block(
			"TruckCab",
			cab,
			origin * CFrame.new(truck.x, cab.Y / 2, truck.z + bed.Z / 2 + cab.Z / 2),
			DepotLayoutConstants.TRUCK_COLOR,
			truckFolder
		)
		local gui, label =
			billboard("PadLabel", pad, DepotLayoutConstants.PAD_LABEL_SIZE, DepotLayoutConstants.PAD_LABEL_OFFSET, "")
		gui.Parent = truckFolder
		table.insert(trucks, { id = truck.id, index = index, capacity = truck.capacity, pad = pad, label = label })
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
	local contractGui = billboard(
		"ContractText",
		contractBoard,
		DepotLayoutConstants.BOARD_LABEL_SIZE,
		DepotLayoutConstants.BOARD_LABEL_OFFSET,
		table.concat(boardLines, "\n")
	)
	contractGui.Parent = boards
	local resultPoint = layout.resultBoard
	local resultBoard = block(
		"ResultBoard",
		boardSize,
		origin * CFrame.new(resultPoint.x, boardSize.Y / 2, resultPoint.z),
		DepotLayoutConstants.BOARD_COLOR,
		boards
	)
	local titleGui = billboard(
		"ResultTitle",
		resultBoard,
		DepotLayoutConstants.TITLE_LABEL_SIZE,
		DepotLayoutConstants.TITLE_LABEL_OFFSET,
		DepotConstants.RESULT_BOARD_TITLE
	)
	titleGui.Parent = boards

	model.Parent = Workspace
	return { model = model, trucks = trucks, resultBoard = resultBoard }
end

--[=[
	Hangs `lines` on the result board for `player` only: a BillboardGui in their PlayerGui (replacing their
	last card, kept across respawns). Yields up to PLAYER_GUI_WAIT seconds for the PlayerGui; false when it
	never appears or the player left.
]=]
function DepotBuildSystem.pinCard(player: Player, board: BasePart, lines: { string }): boolean
	local found = player:WaitForChild("PlayerGui", DepotLayoutConstants.PLAYER_GUI_WAIT)
	if found == nil or not found:IsA("PlayerGui") or player.Parent == nil then
		return false
	end
	local old = found:FindFirstChild(DepotLayoutConstants.CARD_NAME)
	if old ~= nil then
		old:Destroy()
	end
	local gui = billboard(
		DepotLayoutConstants.CARD_NAME,
		board,
		DepotLayoutConstants.CARD_LABEL_SIZE,
		DepotLayoutConstants.CARD_LABEL_OFFSET,
		table.concat(lines, "\n")
	)
	gui.ResetOnSpawn = false
	gui.Parent = found
	return true
end

return DepotBuildSystem
