--!strict
--[=[
	DepotHubPanel: the depot hub's HUD in the V1 kit (hub-desktop / hub-mobile renders), laid out in HUD design px
	(1920x1080 desktop, scaled by PaperHudFrame; 844x390 phone):
	- top-left, right of Roblox's menu and chat buttons: the profile card (Pippa's portrait breaking the card, the
	  player's name, the Clearance Level star, the rank name on desktop and the XP bar);
	- under it the menu tiles (JOBS, LOCKER, GUIDE, SETTINGS: renders breaking their tiles; a column on desktop, a 2x2
	  grid on phone, clear of the thumbstick);
	- top-right: the Gleam counter (the coin render overlapping a gold number) and the daily gift (OPEN! with a badge,
	  else the time to the next day); on desktop the Tonight card (tonight's building photo, the Manager breaking its
	  edge), which opens the Jobs board;
	- bottom-centre: the Next shift card (DepotNextShiftCard), unless the queue pad's own card is up.
	Presentational: the words come from DepotHubViewModel / DepotPadViewModel, the actions from DepotHub. Exempt; story
	in DepotHubPanel.story.

	@class DepotHubPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local DepotHubViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubViewModel)
local DepotNextShiftCard = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotNextShiftCard)
local DepotPadViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBar = require(Toon.ToonBar)
local ToonButton = require(Toon.ToonButton)
local ToonIcon = require(Toon.ToonIcon)
local ToonPill = require(Toon.ToonPill)
local ToonSparkle = require(Toon.ToonSparkle)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

export type DepotHubPanelProps = {
	phone: boolean,
	profile: DepotHubViewModel.ProfileView,
	gleam: string,
	gift: DepotHubViewModel.GiftView,
	tonight: DepotHubViewModel.TonightView,
	-- Nil while the queue pad's own card shows.
	cta: DepotPadViewModel.CtaView?,
	newJobs: boolean,
	onJobs: () -> (),
	onLocker: () -> (),
	onGuide: () -> (),
	onSettings: () -> (),
	onGift: () -> (),
	onGo: () -> (),
}

type Tile = {
	key: string,
	label: string,
	icon: UIAssets.ToonIcon,
	variant: ToonStyleViewModel.Variant,
	activate: () -> (),
}

local function profileCard(props: DepotHubPanelProps): React.ReactNode
	local phone = props.phone
	local profile = props.profile
	local portrait = if phone then 78 else 168
	local cardX = if phone then 168 else 150
	local cardY = if phone then 6 else 80
	local card = if phone then Vector2.new(232, 52) else Vector2.new(356, 134)
	local textLeft = if phone then 36 else 46
	local face: { [string]: React.ReactNode } = {
		name = e(ToonText, {
			text = profile.name,
			-- On phone the name sits right above the XP bar: a size whose caps (optically centred) and drop clear it.
			textSize = if phone then 23 else 44,
			position = UDim2.fromOffset(textLeft, if phone then 0 else 10),
			size = UDim2.fromOffset(card.X - textLeft - (if phone then 52 else 80), if phone then 28 else 48),
			fit = true,
			automaticWidth = false,
		}),
		level = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, if phone then -8 else -18, 0, if phone then -6 else 4),
			Size = UDim2.fromOffset(if phone then 40 else 62, if phone then 40 else 62),
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, {
			star = e(ToonIcon, { icon = "xp", size = UDim2.fromScale(1, 1), drop = 3 }),
			-- Centred on the star's body (its optical centre sits 3% below its box's centre), not on its box.
			number = e(ToonText, {
				text = profile.level,
				textSize = if phone then 18 else 28,
				position = UDim2.fromScale(0, 0.03),
				size = UDim2.fromScale(1, 1),
				align = "center",
				zIndex = 3,
			}),
		}),
		bar = e(ToonBar, {
			kind = "xp",
			fill = profile.fill,
			label = if phone then nil else profile.xpText,
			labelSize = 20,
			position = UDim2.fromOffset(textLeft - 4, if phone then 32 else 86),
			size = UDim2.fromOffset(card.X - textLeft - 14, if phone then 12 else 32),
		}),
	}
	if not phone then
		face.rank = e(ToonText, {
			text = profile.rank,
			font = "body",
			textSize = 22,
			position = UDim2.fromOffset(textLeft, 56),
			size = UDim2.fromOffset(card.X - textLeft - 14, 26),
			fit = true,
		})
	end
	return e("Frame", {
		Position = UDim2.fromOffset(if phone then 128 else 22, if phone then 0 else 56),
		Size = UDim2.fromOffset(cardX - (if phone then 128 else 22) + card.X, portrait),
		BackgroundTransparency = 1,
	}, {
		card = e(ToonSurface, {
			hue = "cream",
			radius = if phone then 18 else 26,
			pattern = "sparkle",
			small = phone,
			position = UDim2.fromOffset(cardX - (if phone then 128 else 22), cardY - (if phone then 0 else 56)),
			size = UDim2.fromOffset(card.X, card.Y),
			children = face,
		}),
		-- Pippa's portrait in a ring, breaking the card's left edge.
		portrait = e("Frame", {
			Size = UDim2.fromOffset(portrait, portrait),
			BackgroundColor3 = UIToonConstants.shade("lilac").hi,
			ZIndex = 3,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = if phone then 4 else 6 }),
			ring = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -10, 1, -10),
				BackgroundTransparency = 1,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				stroke = e("UIStroke", { Color = COLOR.white, Thickness = if phone then 2 else 4 }),
			}),
			photo = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -12, 1, -12),
				BackgroundTransparency = 1,
				Image = UIAssets.toonPhotos.pippaPortrait,
				ScaleType = Enum.ScaleType.Crop,
			}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
		}),
	})
end

local function tiles(props: DepotHubPanelProps): React.ReactNode
	local phone = props.phone
	local list: { Tile } = {
		{ key = "jobs", label = "JOBS", icon = "jobs", variant = "gleam", activate = props.onJobs },
		{ key = "locker", label = "LOCKER", icon = "locker", variant = "grape", activate = props.onLocker },
		{ key = "guide", label = "GUIDE", icon = "guide", variant = "primary", activate = props.onGuide },
		{ key = "settings", label = "SETTINGS", icon = "settings", variant = "lilac", activate = props.onSettings },
	}
	local side = if phone then 68 else 136
	local gap = if phone then 12 else 18
	local nodes: { [string]: React.ReactNode } = {}
	for index, tile in list do
		local column = if phone then (index - 1) % 2 else 0
		local row = if phone then (index - 1) // 2 else index - 1
		nodes[tile.key] = e(ToonButton, {
			variant = tile.variant,
			layout = "tile",
			icon = tile.icon,
			text = tile.label,
			textSize = if phone then 15 else 28,
			badge = if tile.key == "jobs" and props.newJobs then "NEW" else nil,
			position = UDim2.fromOffset(column * (side + gap), row * (side + gap + 6)),
			size = UDim2.fromOffset(side, side),
			small = phone,
			radius = if phone then 16 else 24,
			onActivated = tile.activate,
		})
	end
	return e("Frame", {
		Position = if phone then UDim2.fromOffset(16, 76) else UDim2.fromOffset(34, 270),
		Size = UDim2.fromOffset(if phone then 2 * side + gap else side, 4 * (side + gap)),
		BackgroundTransparency = 1,
	}, nodes)
end

local function topRight(props: DepotHubPanelProps): React.ReactNode
	local phone = props.phone
	local gift = props.gift
	local nodes: { [string]: React.ReactNode } = {
		gleam = e(ToonPill, {
			text = props.gleam,
			meaning = "gold",
			textSize = if phone then 30 else 56,
			icon = "gleam",
			iconSize = if phone then 60 else 108,
			small = phone,
			anchor = Vector2.new(1, 0),
			position = UDim2.fromScale(1, 0),
			size = if phone then UDim2.fromOffset(176, 46) else UDim2.fromOffset(330, 82),
		}),
		-- Gleam's sparkles over the counter (the kit marks what you earn).
		sparkles = e(ToonSparkle, {
			spots = {
				{
					position = UDim2.fromOffset(if phone then -40 else -76, if phone then 2 else 4),
					size = if phone then 16 else 30,
				},
				{
					position = UDim2.fromOffset(if phone then -110 else -210, if phone then 44 else 78),
					size = if phone then 11 else 20,
				},
			},
			zIndex = 4,
		}),
		gift = e(ToonButton, {
			variant = "grape",
			layout = "tile",
			icon = "gift",
			text = gift.text,
			textSize = if phone then 13 else 24,
			badge = if gift.ready then "!" else nil,
			selected = gift.ready,
			anchor = Vector2.new(1, 0),
			position = UDim2.fromOffset(0, if phone then 62 else 118),
			size = if phone then UDim2.fromOffset(66, 66) else UDim2.fromOffset(134, 134),
			small = phone,
			radius = if phone then 16 else 24,
			sound = "confirm",
			onActivated = props.onGift,
		}),
	}
	if not phone then
		local tonight = props.tonight
		local card: { [string]: React.ReactNode } = {
			photo = e("ImageLabel", {
				Position = UDim2.fromOffset(14, 14),
				Size = UDim2.new(1, -28, 0, 136),
				BackgroundColor3 = COLOR.ink,
				Image = UIAssets.toonPhotos.officeCard,
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = 1,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
				stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 4 }),
				-- A scrim so the name reads over the photo.
				scrim = e("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.fromScale(1, 0.55),
					BackgroundColor3 = COLOR.ink,
					BorderSizePixel = 0,
				}, {
					corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
					gradient = e("UIGradient", {
						Rotation = 90,
						Transparency = NumberSequence.new(1, 0.15),
					}),
				}),
				title = e(ToonText, {
					text = tonight.title,
					textSize = 30,
					position = UDim2.new(0, 14, 1, -46),
					size = UDim2.new(1, -96, 0, 38),
					fit = true,
					zIndex = 3,
				}),
			}),
			manager = e(ToonIcon, {
				icon = "managerHunt",
				anchor = Vector2.new(1, 1),
				position = UDim2.new(1, 18, 0, 164),
				size = UDim2.fromOffset(98, 98),
				rotation = 8,
				zIndex = 4,
			}),
			site = e(ToonText, {
				text = tonight.site,
				font = "body",
				textSize = 22,
				position = UDim2.new(0, 18, 1, -46),
				size = UDim2.new(1, -36, 0, 30),
				fit = true,
			}),
		}
		nodes.tonight = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(-156, 118),
			Size = UDim2.fromOffset(336, 214),
			BackgroundTransparency = 1,
		}, {
			card = e(ToonButton, {
				variant = "secondary",
				size = UDim2.fromScale(1, 1),
				content = card,
				onActivated = props.onJobs,
			}),
			tag = e(ToonPill, {
				text = "TONIGHT",
				hue = "mint",
				textSize = 24,
				tilt = -7,
				position = UDim2.fromOffset(-14, -22),
				size = UDim2.fromOffset(150, 44),
				zIndex = 5,
			}),
		})
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = if phone then UDim2.new(1, -14, 0, 6) else UDim2.new(1, -28, 0, 18),
		Size = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
	}, nodes)
end

local function DepotHubPanel(props: DepotHubPanelProps): React.ReactNode
	local nodes: { [string]: React.ReactNode } = {
		profile = profileCard(props),
		tiles = tiles(props),
		topRight = topRight(props),
	}
	if props.cta ~= nil then
		nodes.cta = e(DepotNextShiftCard, { cta = props.cta, phone = props.phone, onGo = props.onGo })
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, nodes)
end

return DepotHubPanel
