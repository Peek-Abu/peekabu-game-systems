--!strict
--[=[
	DepotBoardVisualSystem: the contract board's physical body in the depot hub. The board part is the sign's adornee,
	its collision and its prompt anchor, and stays invisible: the client draws the whole board face (DepotBillboardSystem)
	on its front (+Z, NormalId.Back) face. Without a body it was a flat picture standing on the floor: edge-on it vanished,
	and from behind there was nothing at all.

	`build(board, parent)` adds, behind the sign's face and inside its footprint (DepotLayoutConstants.BOARD_BODY): a
	graphite frame of four rails giving it real thickness, a recessed ivory back, three teal battens bracing it, a
	two-strut kickstand down to floor pads behind it, and the company's sticker on the back (a SurfaceGui facing back,
	lit by the room). It is inset from the board's outline so the card's rounded corners hide it from the front, and
	nothing sits in front of the face, so the GUI stays on the front face only. The trucks' palette and finish; only
	the kickstand collides (the board part already blocks the body).

	@class DepotBoardVisualSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)

local BODY = DepotLayoutConstants.BOARD_BODY
local BACKER = DepotLayoutConstants.BOARD_BACKER
local IDLE = DepotSpotConstants.IDLE

local function piece(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function label(text: string, font: Font, color: Color3, position: UDim2, size: UDim2, parent: Instance): TextLabel
	local created = Instance.new("TextLabel")
	created.BackgroundTransparency = 1
	created.Position = position
	created.Size = size
	created.Text = text
	created.FontFace = font
	created.TextColor3 = color
	created.TextScaled = true
	created.Parent = parent
	return created
end

-- The company sticker's face: the trucks' livery as a label (a teal band with the gold MM roundel and the company, the
-- depot below).
local function sticker(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sticker"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = BODY.STICKER_PX
	gui.LightInfluence = 1
	gui.MaxDistance = DepotLayoutConstants.LABEL_MAX_DISTANCE
	local paper = Instance.new("Frame")
	paper.Name = "Paper"
	paper.Size = UDim2.fromScale(1, 1)
	paper.BackgroundColor3 = BODY.STICKER_PAPER
	paper.BorderSizePixel = 0
	paper.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = paper
	local stroke = Instance.new("UIStroke")
	stroke.Color = BODY.STICKER_TEAL
	stroke.Thickness = 5
	stroke.Parent = paper
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.Position = UDim2.fromScale(0, 0.08)
	band.Size = UDim2.fromScale(1, 0.42)
	band.BackgroundColor3 = BODY.STICKER_TEAL
	band.BorderSizePixel = 0
	band.Parent = paper
	local roundel = Instance.new("Frame")
	roundel.Name = "Roundel"
	roundel.AnchorPoint = Vector2.new(0, 0.5)
	roundel.Position = UDim2.fromScale(0.04, 0.5)
	roundel.Size = UDim2.fromScale(0.78, 0.78)
	roundel.SizeConstraint = Enum.SizeConstraint.RelativeYY
	roundel.BackgroundColor3 = BODY.STICKER_GOLD
	roundel.BorderSizePixel = 0
	roundel.Parent = band
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = roundel
	local heading = Font.new(Font.fromEnum(Enum.Font.Oswald).Family, Enum.FontWeight.Bold)
	label("MM", heading, BODY.STICKER_INK, UDim2.fromScale(0.14, 0.14), UDim2.fromScale(0.72, 0.72), roundel)
	local body = Font.fromEnum(Enum.Font.SpecialElite)
	label(BODY.STICKER_TITLE, heading, BODY.STICKER_PAPER, UDim2.fromScale(0.22, 0.1), UDim2.fromScale(0.74, 0.8), band)
	label(BODY.STICKER_LINE, heading, BODY.STICKER_INK, UDim2.fromScale(0.08, 0.53), UDim2.fromScale(0.84, 0.22), paper)
	label(BODY.STICKER_SMALL, body, BODY.STICKER_INK, UDim2.fromScale(0.1, 0.78), UDim2.fromScale(0.8, 0.13), paper)
	gui.Parent = part
end

local DepotBoardVisualSystem = {}

--[=[
	Builds the body behind `board`'s sign face into a Model under `parent`, and returns it.
]=]
function DepotBoardVisualSystem.build(board: BasePart, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = `{board.Name}Body`
	local outline = board.Size
	local size = Vector3.new(outline.X - 2 * BODY.INSET, outline.Y - 2 * BODY.INSET, outline.Z)
	local at = board.CFrame
	local front = size.Z / 2 - BODY.FACE_GAP
	local rail, depth = BODY.RAIL, BODY.DEPTH
	local railZ = front - depth / 2
	local finish = Enum.Material.SmoothPlastic
	local inner = Vector2.new(size.X - 2 * rail, size.Y - 2 * rail)

	-- The frame: its rails carry the board's full outline and depth.
	for _, spec in
		{
			{ Vector3.new(size.X, rail, depth), Vector3.new(0, size.Y / 2 - rail / 2, railZ) },
			{ Vector3.new(size.X, rail, depth), Vector3.new(0, -size.Y / 2 + rail / 2, railZ) },
			{ Vector3.new(rail, inner.Y, depth), Vector3.new(size.X / 2 - rail / 2, 0, railZ) },
			{ Vector3.new(rail, inner.Y, depth), Vector3.new(-size.X / 2 + rail / 2, 0, railZ) },
		}
	do
		piece("Rail", spec[1], at * CFrame.new(spec[2]), BODY.FRAME_COLOR, finish, model)
	end

	-- The ivory back, flush with the frame's front, so from behind it sits recessed in the frame.
	local panelZ = front - BODY.PANEL_DEPTH / 2
	piece(
		"Backing",
		Vector3.new(inner.X, inner.Y, BODY.PANEL_DEPTH),
		at * CFrame.new(0, 0, panelZ),
		BODY.PANEL_COLOR,
		finish,
		model
	)
	local panelBack = front - BODY.PANEL_DEPTH

	-- The bracing: two uprights and a crosspiece behind them, low, leaving the sticker's spot clear.
	local battenZ = panelBack - BODY.BATTEN_DEPTH / 2
	for _, x in { -size.X / 4, size.X / 4 } do
		piece(
			"Batten",
			Vector3.new(BODY.BATTEN, inner.Y, BODY.BATTEN_DEPTH),
			at * CFrame.new(x, 0, battenZ),
			BODY.BATTEN_COLOR,
			finish,
			model
		)
	end
	piece(
		"Batten",
		Vector3.new(inner.X, BODY.BATTEN, BODY.BATTEN_DEPTH),
		at * CFrame.new(0, -size.Y / 4, battenZ - BODY.BATTEN_DEPTH),
		BODY.BATTEN_COLOR,
		finish,
		model
	)

	-- The kickstand: from a bracket on each upright's back down to a pad on the floor behind the board.
	local floorY = -outline.Y / 2
	local pad = Vector3.new(0.7, 0.12, 1)
	local backZ = front - depth
	for _, side in { -1, 1 } do
		local x = side * (size.X / 2 - BODY.STRUT_INSET)
		local top = Vector3.new(x, BODY.STRUT_TOP, backZ)
		local footZ = front - BODY.KICK
		local padTop = floorY + pad.Y
		local bottom = Vector3.new(x, padTop + BODY.STRUT / 2, footZ)
		local mid = (top + bottom) / 2
		local strut = piece(
			"Strut",
			Vector3.new(BODY.STRUT, BODY.STRUT, (top - bottom).Magnitude),
			at * CFrame.lookAt(mid, top),
			BODY.STRUT_COLOR,
			finish,
			model
		)
		strut.CanCollide = true
		local foot =
			piece("FloorPad", pad, at * CFrame.new(x, floorY + pad.Y / 2, footZ), BODY.STRUT_COLOR, finish, model)
		foot.CanCollide = true
		piece(
			"Bracket",
			Vector3.new(0.6, 0.6, 0.12),
			at * CFrame.new(x, BODY.STRUT_TOP, backZ - 0.06),
			BODY.STRUT_COLOR,
			finish,
			model
		)
	end

	-- The company sticker, on the back panel between the uprights, above the crosspiece; its Front faces away from the sign.
	local stickerPart = piece(
		"Sticker",
		Vector3.new(BODY.STICKER_SIZE.X, BODY.STICKER_SIZE.Y, 0.02),
		at * CFrame.new(0, size.Y / 4 - 0.2, panelBack - 0.012),
		BODY.STICKER_PAPER,
		Enum.Material.SmoothPlastic,
		model
	)
	stickerPart.Transparency = 1
	sticker(stickerPart)

	model.Parent = parent
	return model
end

--[=[
	Builds a back behind a small sign into a Model `name` under `parent`, and returns it. `face` is the centre of the
	sign's face, its +Z toward the readers (a board part's frame); `size` the face's width and height. The panel stands
	on the floor (`floorY`) when it reaches it, else on two legs with feet, so nothing floats and nothing is
	see-through from behind. Only the legs collide.
]=]
function DepotBoardVisualSystem.backer(
	name: string,
	face: CFrame,
	size: Vector2,
	floorY: number,
	parent: Instance
): Model
	local model = Instance.new("Model")
	model.Name = name
	local finish = Enum.Material.SmoothPlastic
	local width = size.X + 2 * BACKER.MARGIN
	local top = size.Y / 2 + BACKER.MARGIN
	local floor = floorY - face.Y
	local bottom = -size.Y / 2 - BACKER.MARGIN
	local raised = bottom - floor > BACKER.MIN_LEG
	if not raised then
		bottom = floor
	end
	local panelZ = -BACKER.GAP - BACKER.DEPTH / 2
	piece(
		"Backing",
		Vector3.new(width, top - bottom, BACKER.DEPTH),
		face * CFrame.new(0, (top + bottom) / 2, panelZ),
		BACKER.PANEL_COLOR,
		finish,
		model
	)
	if raised then
		local legZ = -BACKER.GAP - BACKER.DEPTH - BACKER.LEG / 2
		-- Each leg runs up behind the panel to half its height, so it reads as holding it.
		local legTop = (top + bottom) / 2
		for _, side in { -1, 1 } do
			local x = side * (width / 2 - BACKER.LEG_INSET)
			local leg = piece(
				"Leg",
				Vector3.new(BACKER.LEG, legTop - floor, BACKER.LEG),
				face * CFrame.new(x, (legTop + floor) / 2, legZ),
				BACKER.LEG_COLOR,
				finish,
				model
			)
			leg.CanCollide = true
			piece(
				"Foot",
				BACKER.FOOT,
				face * CFrame.new(x, floor + BACKER.FOOT.Y / 2, legZ - BACKER.FOOT.Z / 2 + BACKER.LEG / 2),
				BACKER.LEG_COLOR,
				finish,
				model
			)
		end
	end
	model.Parent = parent
	return model
end

--[=[
	Hangs the weekly time clock (owner 11-11: it faced the wall, and its sign floated): `art` (the approved clock
	template, nil = the hit box stays a graybox block) is cloned, fitted to `clock` (the hit box, its +Z toward the
	readers) and turned to face them on the hit box's back; `sign` (its sign part, already above the clock) moves onto
	that back; and one back (`backer`, "ClockBacker") behind both stands on the floor.
]=]
function DepotBoardVisualSystem.hangClock(clock: BasePart, art: Model?, sign: BasePart, parent: Instance)
	local backZ = BACKER.CLOCK_BACK_Z
	if art ~= nil then
		local body = art:Clone()
		body.Name = "TimeClockArt"
		local _, artSize = body:GetBoundingBox()
		body:ScaleTo(math.min(clock.Size.X / math.max(artSize.X, 0.1), clock.Size.Y / math.max(artSize.Y, 0.1)))
		-- The art's pivot is its back centre and its face its LookVector.
		body:PivotTo(clock.CFrame * CFrame.new(0, 0, backZ) * CFrame.Angles(0, math.pi, 0))
		for _, part in body:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
		-- Its dial ticks (DepotIdleMotionSystem's "tick": a second hand on the dial's -Z face, which looks at the readers).
		local dial = body:FindFirstChild(IDLE.CLOCK_DIAL, true)
		if dial ~= nil and dial:IsA("BasePart") then
			dial:SetAttribute(IDLE.ATTRIBUTE, "tick")
			CollectionService:AddTag(dial, IDLE.TAG)
		end
		body.Parent = parent
		clock.Transparency = 1
	end
	local offset = clock.CFrame:ToObjectSpace(sign.CFrame)
	sign.CFrame = clock.CFrame * CFrame.new(offset.X, offset.Y, backZ + sign.Size.Z / 2)
	local low = -clock.Size.Y / 2 + BACKER.MARGIN
	local high = offset.Y + sign.Size.Y / 2
	DepotBoardVisualSystem.backer(
		"ClockBacker",
		clock.CFrame * CFrame.new(0, (low + high) / 2, backZ),
		Vector2.new(math.max(sign.Size.X, clock.Size.X), high - low),
		clock.Position.Y - clock.Size.Y / 2,
		parent
	)
end

return DepotBoardVisualSystem
