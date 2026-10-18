--!strict
--[=[
	DepotCardPanel: the travel cards in the V1 kit, centred at 40% of the screen height and scaled by `scale`
	(PaperHudScaleViewModel.scale). Drive: a 520x260 cream panel on the depth stack under a grape
	header (the dispatch letterhead, the truck render breaking the corner), ON THE ROAD in stroked display type with
	"TRUCK n" on a tilted gold pill beside it, "Heading to …" and a lilac road of 13 dashes the truck render drives along over the card's
	seconds. Arrival: a 640x400 cream panel with a mint ARRIVAL sticker breaking its top-left corner, the client in big
	stroked type, the job line, the site contract on a dark plate (its name on a grape pill, the Gloom to remove as a
	stroked white number, its deadline) and the note on a lilac card tilted -2°. Presentational; the lines are
	DepotCardViewModel. Remount it per card (DepotCard keys it) so the truck starts again.

	@class DepotCardPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotCardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardViewModel)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local usePaperMotion = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperMotion)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type DepotCardPanelProps = {
	drive: DepotCardViewModel.DriveView?,
	arrival: DepotCardViewModel.ArrivalView?,
	-- The game's one UI scale (PaperHudScaleViewModel.scale) for this screen.
	scale: number,
}

local DRIVE = Vector2.new(520, 260)
local ARRIVAL = Vector2.new(640, 400)
local HEADER = 58
local DASHES = 13
local DASH = Vector2.new(24, 8)
local DASH_STEP = 36
local ROAD = Vector2.new(30, 218)
local TRUCK = 64

local function text(
	value: string,
	size: number,
	position: UDim2,
	frame: UDim2,
	display: boolean,
	meaning: UIToonConstants.Meaning?
): React.ReactNode
	return e(ToonText, {
		text = value,
		font = if display then "display" else "body",
		meaning = meaning,
		textSize = size,
		position = position,
		size = frame,
		wrapped = not display,
		fit = true,
		alignY = if display then "center" else "top",
	})
end

-- The lilac road and the truck render driving along it once over `seconds`, from mount.
local function Road(props: { seconds: number }): React.ReactNode
	local alpha = usePaperMotion(props.seconds)
	local children: { [string]: React.ReactNode } = {
		truck = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = alpha:map(function(value: number): UDim2
				return UDim2.fromOffset(DASH.X / 2 + value * (DASHES - 1) * DASH_STEP, DASH.Y + 6)
			end),
			Size = UDim2.fromOffset(TRUCK, TRUCK),
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, {
			icon = e(ToonIcon, { icon = "truck", size = UDim2.fromScale(1, 1), drop = 3 }),
		}),
	}
	for index = 1, DASHES do
		children[`dash{index}`] = e("Frame", {
			Position = UDim2.fromOffset((index - 1) * DASH_STEP, 0),
			Size = UDim2.fromOffset(DASH.X, DASH.Y),
			BackgroundColor3 = UIToonConstants.shade("lilac").base,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = UIToonConstants.COLOR.ink, Thickness = 2 }),
		})
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
	local face: { [string]: React.ReactNode } = {
		title = text(
			view.title,
			52,
			UDim2.fromOffset(28, HEADER + 12),
			UDim2.new(1, if truck ~= nil then -172 else -56, 0, 62),
			true
		),
		heading = text(view.heading, 22, UDim2.fromOffset(30, HEADER + 78), UDim2.new(1, -60, 0, 30), false),
		road = e(Road, { seconds = view.seconds }),
	}
	if truck ~= nil then
		face.truckTag = e(ToonPill, {
			text = truck,
			hue = "gold",
			textSize = 18,
			tilt = 4,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -18, 0, HEADER + 44),
			size = UDim2.fromOffset(120, 38),
			zIndex = 6,
		})
	end
	return e(ToonPanel, {
		size = DRIVE,
		header = {
			title = view.band,
			icon = "truck",
			height = HEADER,
			titleSize = 22,
		},
		pop = true,
		children = face,
	})
end

local function arrivalCard(view: DepotCardViewModel.ArrivalView): React.ReactNode
	local contract: { [string]: React.ReactNode } = {
		clear = text(view.clear, 44, UDim2.fromOffset(18, 34), UDim2.new(1, -36, 0, 54), true),
		before = e(ToonText, {
			text = view.before,
			font = "body",
			color = UIToonConstants.COLOR.white,
			textSize = 18,
			position = UDim2.fromOffset(20, 92),
			size = UDim2.new(1, -40, 0, 26),
			fit = true,
		}),
	}
	local note: { [string]: React.ReactNode } = {
		note = text(view.note, 18, UDim2.fromOffset(14, 12), UDim2.new(1, -28, 1, -24), false),
	}
	local face: { [string]: React.ReactNode } = {
		client = text(view.client, 52, UDim2.fromOffset(34, 34), UDim2.fromOffset(570, 64), true),
		job = text(view.job, 22, UDim2.fromOffset(36, 104), UDim2.fromOffset(568, 56), false),
		contract = e(ToonSurface, {
			hue = "night",
			gloss = false,
			radius = 22,
			pattern = "bubbles",
			position = UDim2.fromOffset(28, 176),
			size = UDim2.fromOffset(340, 140),
			children = contract,
		}),
		contractName = e(ToonPill, {
			text = view.slip,
			hue = "grape",
			textSize = 16,
			tilt = -3,
			position = UDim2.fromOffset(44, 160),
			size = UDim2.fromOffset(176, 32),
			zIndex = 6,
		}),
		note = e("Frame", {
			Position = UDim2.fromOffset(398, 182),
			Size = UDim2.fromOffset(206, 130),
			Rotation = -2,
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, {
			card = e(ToonSurface, {
				hue = "lilac",
				small = true,
				radius = 16,
				size = UDim2.fromScale(1, 1),
				children = note,
			}),
		}),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(ARRIVAL.X, ARRIVAL.Y),
		BackgroundTransparency = 1,
	}, {
		panel = e(ToonPanel, { size = ARRIVAL - Vector2.new(0, 8), pop = true, children = face }),
		tab = e(ToonPill, {
			text = view.tab,
			hue = "mint",
			textSize = 26,
			tilt = -6,
			position = UDim2.fromOffset(-22, -24),
			size = UDim2.fromOffset(190, 50),
			zIndex = 8,
		}),
	})
end

local function DepotCardPanel(props: DepotCardPanelProps): React.ReactNode
	local arrival = props.arrival
	local drive = props.drive
	local size = if arrival ~= nil then ARRIVAL else DRIVE
	-- PaperLabel's shrink-to-fit limits follow the card's scale (see PaperScaleContext).
	local scale = React.useMemo(function(): React.Binding<number>
		local binding = React.createBinding(props.scale)
		return binding
	end, { tostring(props.scale) })
	local card: React.ReactNode = nil
	if arrival ~= nil then
		card = arrivalCard(arrival)
	elseif drive ~= nil then
		card = driveCard(drive)
	end
	return e(PaperScaleContext.Context.Provider, { value = scale }, {
		root = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundTransparency = 1,
		}, {
			scale = e("UIScale", { Scale = props.scale }),
			card = card,
		}),
	})
end

return DepotCardPanel
