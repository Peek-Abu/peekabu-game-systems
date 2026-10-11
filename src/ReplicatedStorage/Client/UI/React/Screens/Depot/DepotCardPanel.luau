--!strict
--[=[
	DepotCardPanel: the travel cards (Figma World UI 2c, S1), centred at 40% of the screen height and scaled by `scale`
	(WorldBillboardViewModel.screenScale). Drive: a 520x260 cream dispatch ticket tilted 1.5° with a 46 px ink
	letterhead ("TRUCK n" in glow green on the right), ON THE ROAD (Oswald 58), "Heading to …" (Special Elite 24) and a
	road of 13 dashes (24x6, every 36 px) that a 30x20 stamp-red truck block crosses over the card's seconds. Arrival: a
	640x400 manila folder with a 220 px ARRIVAL tab, the client (Oswald 56), the job line (Special Elite 26), a 330x170
	cream CLEARANCE CONTRACT slip tilted 1.5° (CLEAR n in Oswald 58, its deadline) and the note on a sticky tilted -2°.
	Presentational; the lines are DepotCardViewModel. Remount it per card (DepotCard keys it) so the truck starts again.

	@class DepotCardPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotCardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardViewModel)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local PaperTexture = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture)
local StickyNote = require(ReplicatedStorage.Client.UI.React.Screens.Paper.StickyNote)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperMotion = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperMotion)

local e = React.createElement

export type DepotCardPanelProps = {
	drive: DepotCardViewModel.DriveView?,
	arrival: DepotCardViewModel.ArrivalView?,
	-- WorldBillboardViewModel.screenScale of this screen.
	scale: number,
}

local COLOR = UIPaperConstants.COLOR
local DRIVE = Vector2.new(520, 260)
local ARRIVAL = Vector2.new(640, 400)
local BAND = 46
local DASHES = 13
local DASH = Vector2.new(24, 6)
local DASH_STEP = 36
local ROAD = Vector2.new(24, 206)
local TRUCK = Vector2.new(30, 20)

local function label(
	text: string,
	role: PaperLabel.Role,
	size: number,
	color: Color3,
	position: UDim2,
	frame: UDim2,
	scaled: boolean?
): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = role,
		size = size,
		color = color,
		position = position,
		frame = frame,
		autoSize = false,
		wrapped = scaled ~= true,
		scaled = scaled,
		-- Above the card's PaperTexture (ZIndex 0).
		zIndex = 2,
		-- The card is itself scaled (down to 0.6): a large absolute minimum would overflow the frame.
		minSize = if scaled == true then 8 else nil,
	})
end

-- The dashed road and the truck crossing it once over `seconds`, from mount.
local function Road(props: { seconds: number }): React.ReactNode
	local alpha = usePaperMotion(props.seconds)
	local children: { [string]: React.ReactNode } = {
		truck = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = alpha:map(function(value: number): UDim2
				return UDim2.fromOffset(DASH.X / 2 + value * (DASHES - 1) * DASH_STEP, DASH.Y / 2)
			end),
			Size = UDim2.fromOffset(TRUCK.X, TRUCK.Y),
			BackgroundColor3 = COLOR.stamp,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
	}
	for index = 1, DASHES do
		children[`dash{index}`] = e("Frame", {
			Position = UDim2.fromOffset((index - 1) * DASH_STEP, 0),
			Size = UDim2.fromOffset(DASH.X, DASH.Y),
			BackgroundColor3 = COLOR.manilaDeep,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	return e("Frame", {
		Position = UDim2.fromOffset(ROAD.X, ROAD.Y),
		Size = UDim2.fromOffset((DASHES - 1) * DASH_STEP + DASH.X, DASH.Y),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, children)
end

local function driveCard(view: DepotCardViewModel.DriveView): React.ReactNode
	local truck = view.truck
	return e("Frame", {
		Size = UDim2.fromOffset(DRIVE.X, DRIVE.Y),
		Rotation = 1.5,
		BackgroundTransparency = 1,
	}, {
		shadow = e("Frame", {
			Position = UDim2.fromOffset(4, 6),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.night,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
		paper = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.cream,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			texture = e(PaperTexture, { paper = COLOR.cream, corner = 4 }),
			band = e("Frame", {
				Size = UDim2.new(1, 0, 0, BAND),
				BackgroundColor3 = COLOR.ink,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				label = label(
					view.band,
					"heading",
					22,
					COLOR.cream,
					UDim2.fromOffset(20, 0),
					UDim2.new(1, -170, 1, 0),
					true
				),
				truck = if truck ~= nil
					then e(PaperLabel, {
						text = truck,
						role = "heading",
						size = 22,
						color = COLOR.fluorGlow,
						align = "right",
						position = UDim2.new(1, -140, 0, 0),
						frame = UDim2.fromOffset(120, BAND),
						autoSize = false,
						wrapped = false,
					})
					else nil,
			}),
			title = label(
				view.title,
				"heading",
				58,
				COLOR.ink,
				UDim2.fromOffset(24, 62),
				UDim2.new(1, -48, 0, 72),
				true
			),
			heading = label(
				view.heading,
				"body",
				24,
				COLOR.ink,
				UDim2.fromOffset(24, 138),
				UDim2.new(1, -48, 0, 34),
				true
			),
			road = e(Road, { seconds = view.seconds }),
		}),
	})
end

local function arrivalCard(view: DepotCardViewModel.ArrivalView): React.ReactNode
	local slip: { [string]: React.ReactNode } = {
		clear = label(view.clear, "heading", 58, COLOR.ink, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 66), true),
		before = label(view.before, "body", 20, COLOR.ink, UDim2.fromOffset(0, 70), UDim2.new(1, 0, 0, 28)),
	}
	local folder: { [string]: React.ReactNode } = {
		client = label(
			view.client,
			"heading",
			56,
			COLOR.ink,
			UDim2.fromOffset(30, 22),
			UDim2.fromOffset(580, 70),
			true
		),
		job = label(view.job, "body", 26, COLOR.ink, UDim2.fromOffset(30, 96), UDim2.fromOffset(580, 66)),
		slip = e(PaperSheet, {
			position = UDim2.fromOffset(24, 170),
			size = UDim2.fromOffset(330, 170),
			paper = COLOR.cream,
			tilt = 1.5,
			band = view.slip,
			padding = 16,
		}, slip),
		sticky = e(StickyNote, {
			text = view.note,
			width = 200,
			size = 20,
			tilt = -2,
			position = UDim2.fromOffset(400, 184),
		}),
	}
	return e(PaperSheet, {
		size = UDim2.fromOffset(ARRIVAL.X, ARRIVAL.Y),
		paper = COLOR.manila,
		tab = view.tab,
		tabWidth = 220,
		tabTextSize = 26,
		padding = 0,
	}, folder)
end

local function DepotCardPanel(props: DepotCardPanelProps): React.ReactNode
	local arrival = props.arrival
	local drive = props.drive
	local size = if arrival ~= nil then ARRIVAL else DRIVE
	local card: React.ReactNode = nil
	if arrival ~= nil then
		card = arrivalCard(arrival)
	elseif drive ~= nil then
		card = driveCard(drive)
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, {
		scale = e("UIScale", { Scale = props.scale }),
		card = card,
	})
end

return DepotCardPanel
