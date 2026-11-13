--!strict
--[=[
	DepotBoardPanel: the places menu (the contract board scene; p1-places-menu) in the V1 kit (menu-jobs render): a
	cream modal popping in over the dimmed depot, its grape PLACES header with the clipboard render breaking the corner,
	the header's foot melting into Gloom drips over the panel, and the coral close. Under it the tabs (CONTRACTS,
	LOCKER, GUIDE: the current one in V2's lilac selected ring), then a Doors-style photo card per place, each from our
	own posed scene shots: the Office and the School, each with its DANGER meter (Gloom drops, filled to the place's
	level), and the planned buildings locked (darkened concept photo, the padlock render, Gloom pooled inside the
	photo's floor, a SOON sticker). A locked place (the School before it is bought) shows the padlock and a gold BUY
	with its Credits price: the first tap turns it into SURE?, the second buys (`onBuy`). The focused card wears the
	lilac ring and a pointer to the detail; the truck's pick is tagged TONIGHT!. Tapping an open card picks it for the
	host's truck (`onPick`); anyone else's tap only shows that place's detail (`onView`). The line under the header
	says who picks. The detail: the place's monster on site (Harlow or Bramble), the client, four contract chips with
	renders (QUOTA, SHIFT, PAY, CREW), the tip line, FIND A TRUCK and READ THE BRIEF, and the returning player's last
	shift. Drawn at 1580x900 (phone 748x320) and scaled by `scale` (DepotBoardViewModel.fit), centred.
	Presentational: it draws the view it is given (specced in DepotBoardViewModel).

	@class DepotBoardPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)
local DepotPlaceCard = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPlaceCard)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
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
	-- A host's tap on an open place (picks it for their truck).
	onPick: ((map: ShiftTypes.MapId) -> ())?,
	-- Anyone else's tap on a place card (shows its detail).
	onView: ((map: ShiftTypes.MapId) -> ())?,
	-- A tap on a locked place's BUY (the first asks SURE?, the second buys).
	onBuy: ((map: ShiftTypes.MapId) -> ())?,
}

type Nodes = { [string]: React.ReactNode }

local DESKTOP = Vector2.new(1580, 900)
local PHONE = Vector2.new(748, 320)

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

type Monster = { image: string, title: string, line: string }

local BRAMBLE_PORTRAIT: UIAssets.ToonIcon = "brambleHunt"

-- The monster on site at each place: Harlow's manager render at the Office, Bramble's chase portrait at the School.
local MONSTERS: { [string]: Monster } = {
	harlow = {
		image = UIAssets.toonPhotos.managerPortrait,
		title = "THE MANAGER",
		line = "Hears vacuums and things you drop",
	},
	bramble = {
		image = UIAssets.toonIcons[BRAMBLE_PORTRAIT],
		title = "BRAMBLE THE OWL",
		line = "Stops when you look at it",
	},
}

local function managerCard(monster: string, size: Vector2, position: UDim2): React.ReactNode
	local who = MONSTERS[monster] or MONSTERS.harlow
	local face: Nodes = {
		photo = e("ImageLabel", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 1, -20),
			BackgroundColor3 = COLOR.ink,
			Image = who.image,
			ScaleType = if monster == "harlow" then Enum.ScaleType.Crop else Enum.ScaleType.Fit,
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
				text = who.title,
				textSize = 32,
				position = UDim2.new(0, 14, 1, -70),
				size = UDim2.new(1, -28, 0, 38),
				fit = true,
				zIndex = 3,
			}),
			line = e(ToonText, {
				text = who.line,
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
		{ key = "locker", label = "VACUUMS", width = 160 },
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
	-- Who picks the place, beside the tabs.
	nodes.pickLine = e(ToonText, {
		text = view.pickLine,
		textSize = 26,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -44, 0, 190),
		size = UDim2.fromOffset(DESKTOP.X - x - 60, 34),
		align = "right",
		fit = true,
	})
	-- The place cards: five across.
	local gap = 18
	local width = (DESKTOP.X - 88 - gap * (#view.buildings - 1)) / #view.buildings
	local cardSize = Vector2.new(width, 310)
	for index, building in view.buildings do
		nodes[`building{index}`] = DepotPlaceCard(
			building,
			view,
			props,
			false,
			cardSize,
			UDim2.fromOffset(44 + (index - 1) * (cardSize.X + gap), 260)
		)
	end
	-- The detail.
	local detail: Nodes = {
		manager = managerCard(view.monster, Vector2.new(320, 256), UDim2.fromOffset(16, 12)),
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
		size = Vector2.new(DESKTOP.X - 88, 270),
		position = UDim2.fromOffset(44, 616),
		children = detail,
	})
	return nodes
end

local function phoneNodes(props: DepotBoardPanelProps): Nodes
	local view = props.view
	local nodes: Nodes = {}
	local gap = 6
	local width = (PHONE.X - 24 - gap * (#view.buildings - 1)) / #view.buildings
	local cardSize = Vector2.new(width, 118)
	for index, building in view.buildings do
		nodes[`building{index}`] = DepotPlaceCard(
			building,
			view,
			props,
			true,
			cardSize,
			UDim2.fromOffset(12 + (index - 1) * (cardSize.X + gap), 100)
		)
	end
	for index, view_chip in view.chips do
		nodes[`chip{index}`] =
			chip(view_chip, true, Vector2.new(124, 42), UDim2.fromOffset(28 + (index - 1) * 134, 232))
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
		text = `{view.client} · {view.pickLine}`,
		textSize = 14,
		position = UDim2.fromOffset(16, 282),
		size = UDim2.fromOffset(530, 22),
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
			title = props.view.header,
			subtitle = if phone then nil else "Morrow & Morrow Clearance · where to clean tonight",
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
