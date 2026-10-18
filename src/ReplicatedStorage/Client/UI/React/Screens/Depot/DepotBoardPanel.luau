--!strict
--[=[
	DepotBoardPanel: the Jobs menu (the contract board scene) in the V1 kit (menu-jobs render): a cream modal popping in
	over the dimmed depot, its grape JOBS header with the clipboard render breaking the corner, the header's foot melting
	into Gloom drips over the panel, and the coral close. Under it the tabs (CONTRACTS, LOCKER, GUIDE: the current one in
	V2's lilac selected ring), then a Doors-style photo card per building: tonight's office open and selected (lilac
	ring, a pointer to the detail), the planned buildings locked (darkened concept photo, the padlock render, Gloom
	pooled inside the photo's floor, a SOON sticker). The detail: the Manager on site, the client, four contract chips
	with renders (QUOTA, SHIFT, PAY, CREW), the tip line, FIND A TRUCK and READ THE BRIEF, and the returning player's
	last shift. Drawn at 1580x900 (phone 748x320) and scaled by `scale` (DepotBoardViewModel.fit), centred.
	Presentational: it draws the view it is given (specced in DepotBoardViewModel).

	@class DepotBoardPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonGoo = require(Toon.ToonGoo)
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

export type Tab = "contracts" | "locker" | "guide"

export type DepotBoardPanelProps = {
	view: DepotBoardViewModel.BoardView,
	layout: UIPaperConstants.Layout,
	-- The board's scale on this screen (DepotBoardViewModel.fit).
	scale: number,
	onClose: () -> (),
	-- The other tabs (the hub's Locker and Guide pages) and READ THE BRIEF (the Guide).
	onTab: ((tab: Tab) -> ())?,
}

type Nodes = { [string]: React.ReactNode }

local DESKTOP = Vector2.new(1580, 900)
local PHONE = Vector2.new(748, 320)

local function photoOf(photo: "office" | "hospital" | "motel" | "mall"): string
	local photos = UIAssets.toonPhotos
	if photo == "hospital" then
		return photos.hospitalCard
	elseif photo == "motel" then
		return photos.motelCard
	elseif photo == "mall" then
		return photos.mallCard
	end
	return photos.officeCard
end

local function buildingCard(
	building: DepotBoardViewModel.BuildingView,
	phone: boolean,
	size: Vector2,
	position: UDim2
): React.ReactNode
	local inset = if phone then 6 else 12
	local photoSize = Vector2.new(size.X - 2 * inset, size.Y - 2 * inset - (if phone then 4 else 8))
	local radius = if phone then 12 else 20
	local photo: Nodes = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }),
		stroke = e("UIStroke", { Color = COLOR.ink, Thickness = if phone then 3 else 4 }),
		scrim = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.6),
			BackgroundColor3 = COLOR.ink,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }),
			gradient = e("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.1) }),
		}),
		name = e(ToonText, {
			text = building.name,
			textSize = if phone then 17 else 36,
			position = UDim2.new(0, if phone then 8 else 18, 1, if phone then -48 else -104),
			size = UDim2.new(1, if phone then -16 else -36, 0, if phone then 22 else 44),
			fit = true,
			zIndex = 4,
		}),
		site = e(ToonText, {
			text = building.site,
			font = "body",
			color = COLOR.white,
			textSize = if phone then 12 else 21,
			position = UDim2.new(0, if phone then 9 else 20, 1, if phone then -26 else -60),
			size = UDim2.new(1, -20, 0, if phone then 16 else 28),
			fit = true,
			zIndex = 4,
		}),
	}
	if not building.open then
		-- The Gloom pooled inside the photo's floor (clear of its rounded corners), a padlock, and the photo darkened.
		photo.dark = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }) })
		photo.goo = e(ToonGoo, {
			kind = "pool",
			width = photoSize.X,
			radius = radius,
			scale = if phone then 0.45 else 0.9,
			zIndex = 3,
		})
		photo.lock = e(ToonIcon, {
			icon = "lock",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, if phone then 0.28 else 0.36),
			size = UDim2.fromOffset(if phone then 36 else 110, if phone then 36 else 110),
			drop = if phone then 3 else 6,
			zIndex = 5,
		})
	end
	local face: Nodes = {
		photo = e("ImageLabel", {
			Position = UDim2.fromOffset(inset, inset),
			Size = UDim2.fromOffset(photoSize.X, photoSize.Y),
			BackgroundColor3 = COLOR.ink,
			Image = photoOf(building.photo),
			ScaleType = Enum.ScaleType.Crop,
		}, photo),
	}
	local nodes: Nodes = {
		card = e(ToonSurface, {
			hue = "night",
			size = UDim2.fromScale(1, 1),
			radius = if phone then 16 else 26,
			pattern = "bubbles",
			gloss = false,
			pose = nil,
			children = face,
		}),
		tag = e(ToonPill, {
			text = building.tag,
			hue = if building.open then "mint" else "lilac",
			textSize = if phone then 12 else 24,
			tilt = if building.open then 6 else 4,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, if phone then 6 else 12, 0, if phone then 4 else 8),
			size = UDim2.fromOffset(if phone then 74 else 150, if phone then 22 else 44),
			zIndex = 6,
		}),
	}
	if building.open then
		-- Selected: V2's lilac ring and glow, lifted, with a pointer down to the detail.
		nodes.ring = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, if phone then 12 else 22, 1, if phone then 14 else 24),
			BackgroundTransparency = 1,
			ZIndex = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, if phone then 20 else 34) }),
			stroke = e("UIStroke", { Color = COLOR.selected, Thickness = if phone then 4 else 7 }),
		})
		nodes.pointer = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 1, if phone then 12 else 22),
			Size = UDim2.fromOffset(if phone then 14 else 26, if phone then 14 else 26),
			Rotation = 45,
			BackgroundColor3 = COLOR.selected,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, { stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 3 }) })
	end
	return e("Frame", {
		Position = position,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, nodes)
end

local function chip(view: DepotBoardViewModel.ChipView, phone: boolean, size: Vector2, position: UDim2): React.ReactNode
	local icon = if phone then 40 else 76
	local left = if phone then 26 else 62
	local face: Nodes = {
		icon = e(ToonIcon, {
			icon = view.icon,
			position = UDim2.fromOffset(-icon * 0.32, (size.Y - icon) / 2 - 2),
			size = UDim2.fromOffset(icon, icon),
			drop = 4,
			zIndex = 4,
		}),
		label = e(ToonText, {
			text = view.label,
			textSize = if phone then 12 else 16,
			position = UDim2.fromOffset(left, if phone then 2 else 6),
			size = UDim2.fromOffset(size.X - left - 8, if phone then 14 else 22),
			fit = true,
		}),
		value = e(ToonText, {
			text = view.value,
			font = "body",
			textSize = if phone then 14 else 26,
			position = UDim2.fromOffset(left, if phone then 16 else 26),
			size = UDim2.fromOffset(size.X - left - 8, if phone then 20 else 34),
			fit = true,
		}),
	}
	return e(ToonPanel, {
		size = size,
		position = position,
		radius = if phone then 12 else 20,
		children = face,
	})
end

local function managerCard(size: Vector2, position: UDim2): React.ReactNode
	local face: Nodes = {
		photo = e("ImageLabel", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 1, -20),
			BackgroundColor3 = COLOR.ink,
			Image = UIAssets.toonPhotos.managerPortrait,
			ScaleType = Enum.ScaleType.Crop,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 18) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 4 }),
			scrim = e("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(1, 0.5),
				BackgroundColor3 = COLOR.ink,
				BorderSizePixel = 0,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, 18) }),
				gradient = e("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.05) }),
			}),
			title = e(ToonText, {
				text = "THE MANAGER",
				textSize = 32,
				position = UDim2.new(0, 14, 1, -70),
				size = UDim2.new(1, -28, 0, 38),
				fit = true,
				zIndex = 3,
			}),
			line = e(ToonText, {
				text = "Hears vacuums and dropped things",
				font = "body",
				color = UIToonConstants.shade("coral").hi,
				textSize = 17,
				position = UDim2.new(0, 15, 1, -32),
				size = UDim2.new(1, -28, 0, 22),
				fit = true,
				zIndex = 3,
			}),
		}),
		tag = e(ToonPill, {
			text = "ON SITE",
			hue = "coral",
			textSize = 20,
			tilt = -6,
			position = UDim2.fromOffset(20, 22),
			size = UDim2.fromOffset(124, 38),
			zIndex = 5,
		}),
	}
	return e(ToonPanel, {
		hue = "night",
		size = size,
		position = position,
		radius = 24,
		gloss = false,
		children = face,
	})
end

local function desktop(props: DepotBoardPanelProps): Nodes
	local view = props.view
	local onTab = props.onTab
	local nodes: Nodes = {}
	-- The tabs.
	type TabSpec = { key: Tab, label: string, width: number }
	local tabs: { TabSpec } = {
		{ key = "contracts", label = "CONTRACTS", width = 200 },
		{ key = "locker", label = "LOCKER", width = 160 },
		{ key = "guide", label = "GUIDE", width = 140 },
	}
	local x = 44
	for _, tab: TabSpec in tabs do
		local key: Tab = tab.key
		nodes[`tab_{key}`] = e(ToonButton, {
			variant = if key == "contracts" then "gleam" else "secondary",
			text = tab.label,
			textSize = 28,
			selected = key == "contracts",
			position = UDim2.fromOffset(x, 178),
			size = UDim2.fromOffset(tab.width, 58),
			onActivated = function()
				if key ~= "contracts" and onTab ~= nil then
					onTab(key)
				end
			end,
		})
		x += tab.width + 22
	end
	-- The building cards.
	local cardSize = Vector2.new(356, 310)
	for index, building in view.buildings do
		nodes[`building{index}`] =
			buildingCard(building, false, cardSize, UDim2.fromOffset(44 + (index - 1) * (cardSize.X + 22), 240))
	end
	-- The detail.
	local detail: Nodes = {
		manager = managerCard(Vector2.new(320, 256), UDim2.fromOffset(16, 12)),
		client = e(ToonText, {
			text = view.client,
			textSize = 50,
			position = UDim2.fromOffset(372, 14),
			size = UDim2.fromOffset(650, 58),
			fit = true,
		}),
		tip = e(ToonText, {
			text = view.tip,
			font = "body",
			textSize = 19,
			position = UDim2.fromOffset(372, 238),
			size = UDim2.fromOffset(660, 26),
			fit = true,
		}),
		find = e(ToonButton, {
			variant = "primary",
			icon = "truck",
			text = "FIND A TRUCK",
			textSize = 44,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -20, 0, 20),
			size = UDim2.fromOffset(420, 104),
			sound = "cta",
			onActivated = props.onClose,
		}),
		brief = e(ToonButton, {
			variant = "secondary",
			text = "READ THE BRIEF",
			textSize = 36,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -20, 0, 142),
			size = UDim2.fromOffset(420, 78),
			onActivated = function()
				if onTab ~= nil then
					onTab("guide")
				end
			end,
		}),
	}
	for index, view_chip in view.chips do
		local column = (index - 1) % 2
		local row = (index - 1) // 2
		detail[`chip{index}`] =
			chip(view_chip, false, Vector2.new(318, 70), UDim2.fromOffset(394 + column * 336, 82 + row * 80))
	end
	local lastLine = view.lastLine
	if lastLine ~= nil then
		detail.last = e(ToonText, {
			text = lastLine,
			font = "body",
			textSize = 17,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -20, 0, 232),
			size = UDim2.fromOffset(420, 24),
			align = "center",
			fit = true,
		})
	end
	nodes.detail = e(ToonPanel, {
		size = Vector2.new(DESKTOP.X - 88, 286),
		position = UDim2.fromOffset(44, 604),
		children = detail,
	})
	return nodes
end

local function phoneNodes(props: DepotBoardPanelProps): Nodes
	local view = props.view
	local nodes: Nodes = {}
	local cardSize = Vector2.new(170, 112)
	for index, building in view.buildings do
		nodes[`building{index}`] =
			buildingCard(building, true, cardSize, UDim2.fromOffset(12 + (index - 1) * (cardSize.X + 8), 104))
	end
	for index, view_chip in view.chips do
		nodes[`chip{index}`] =
			chip(view_chip, true, Vector2.new(124, 42), UDim2.fromOffset(28 + (index - 1) * 134, 230))
	end
	nodes.find = e(ToonButton, {
		variant = "primary",
		text = "FIND A TRUCK",
		textSize = 22,
		small = true,
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -12, 1, -10),
		size = UDim2.fromOffset(176, 48),
		sound = "cta",
		onActivated = props.onClose,
	})
	nodes.tip = e(ToonText, {
		text = view.client,
		textSize = 16,
		position = UDim2.fromOffset(16, 278),
		size = UDim2.fromOffset(520, 24),
		fit = true,
	})
	return nodes
end

local function DepotBoardPanel(props: DepotBoardPanelProps): React.ReactNode
	local phone = props.layout == "phone"
	local canvas = if phone then PHONE else DESKTOP
	local outer = React.useContext(PaperScaleContext.Context)
	local deps: { unknown } = { outer, props.scale }
	local combined = React.useMemo(function(): React.Binding<number>
		return outer:map(function(value: number): number
			return value * props.scale
		end)
	end, deps)
	local panel = e(ToonPanel, {
		size = canvas,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		header = {
			title = "JOBS",
			subtitle = if phone then nil else "Morrow & Morrow Clearance · tonight's contracts",
			icon = "jobs",
			height = if phone then 70 else 130,
			titleSize = if phone then 44 else 84,
			goo = true,
			gooScale = if phone then 0.45 else 0.75,
		},
		onClose = props.onClose,
		pop = true,
		wipe = true,
		children = if phone then phoneNodes(props) else desktop(props),
	})
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLOR.ink,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, {
		scaled = e(PaperScaleContext.Context.Provider, { value = combined }, {
			frame = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(canvas.X, canvas.Y),
				BackgroundTransparency = 1,
			}, {
				scale = e("UIScale", { Scale = props.scale }),
				panel = panel,
			}),
		}),
	})
end

return DepotBoardPanel
