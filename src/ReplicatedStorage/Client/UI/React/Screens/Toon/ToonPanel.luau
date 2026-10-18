--!strict
--[=[
	ToonPanel: a panel on the kit's depth stack (radius 26). Optional parts:
	- `header`: a grape band across the top with the title (Luckiest Guy), a subtitle, a render breaking the top-left
	  corner and, with `goo`, the band's foot melting into Gloom drips that flow down over the panel (one outline, one
	  light: the goo starts at the band's foot, inside the panel, clear of its corners). `onClose` adds the coral X.
	- `goo`: a goo run on the body itself (a `pool` on the floor of a locked or dangerous card, a `cap` along its top).
	- `pop`: pops in (0.6 -> 1.08 -> 1) on mount; `wipe`: arrives goo-smeared and a squeegee wipes it clean.
	Cream panels carry the faint sparkle pattern, dark ones the goo bubbles. Presentational (exempt; story in
	ToonPanel.story).

	@class ToonPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonButton = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonButton)
local ToonGoo = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonGoo)
local ToonGooViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonGooViewModel)
local ToonIcon = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonIcon)
local ToonMotionViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonMotionViewModel)
local ToonSurface = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSurface)
local ToonText = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonText)
local ToonWipe = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonWipe)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local useToonPlay = require(ReplicatedStorage.Client.UI.React.Screens.Toon.useToonPlay)

local e = React.createElement

local DEPTH = UIToonConstants.DEPTH
local MOTION = UIToonConstants.MOTION

export type Header = {
	title: string,
	subtitle: string?,
	icon: UIAssets.ToonIcon?,
	-- Drawn in the icon's place instead (a live CharacterPortrait), given the icon's size in design px.
	art: ((size: number) -> React.ReactNode)?,
	height: number?,
	titleSize: number?,
	-- The band's foot melts into drips over the panel (`gooScale` sizes them; default 0.75).
	goo: boolean?,
	gooScale: number?,
}

export type Goo = {
	kind: ToonGooViewModel.Kind,
	from: number?,
	to: number?,
	scale: number?,
}

export type ToonPanelProps = {
	-- Design px.
	size: Vector2,
	position: UDim2?,
	anchor: Vector2?,
	hue: UIToonConstants.Hue?,
	radius: number?,
	header: Header?,
	onClose: (() -> ())?,
	goo: Goo?,
	pop: boolean?,
	wipe: boolean?,
	gloss: boolean?,
	zIndex: number?,
	layoutOrder: number?,
	children: { [string]: React.ReactNode }?,
	-- Drawn over the whole face, lip included.
	overlay: { [string]: React.ReactNode }?,
}

local function header(props: ToonPanelProps, spec: Header, radius: number): { [string]: React.ReactNode }
	local height = spec.height or 120
	local titleSize = spec.titleSize or 64
	local shade = UIToonConstants.shade("grape")
	local hasIcon = spec.icon ~= nil or spec.art ~= nil
	-- The render breaking the corner scales with the band, and the title starts clear of it.
	local iconSize = math.floor(height * 1.55)
	local textLeft = if hasIcon then math.floor(height * 1.45) else 32
	local nodes: { [string]: React.ReactNode } = {
		band = e("Frame", {
			Size = UDim2.new(1, 0, 0, height),
			BackgroundColor3 = shade.base,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }),
			gradient = e("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, shade.hi),
					ColorSequenceKeypoint.new(0.55, shade.base),
					ColorSequenceKeypoint.new(1, shade.base),
				}),
			}),
			-- Squares the band's bottom corners (only its top follows the panel's rounding).
			foot = e("Frame", {
				Position = UDim2.new(0, 0, 1, -radius),
				Size = UDim2.new(1, 0, 0, radius),
				BackgroundColor3 = shade.base,
				BorderSizePixel = 0,
			}),
			bubbles = e("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = UIAssets.toon.patternBubbles,
				ImageTransparency = 0.88,
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(60, 60),
				ZIndex = 2,
			}, { corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }) }),
			gloss = e("Frame", {
				Position = UDim2.fromOffset(DEPTH.outline + 2, 4),
				Size = UDim2.new(1, -2 * (DEPTH.outline + 2), 0.42, 0),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ZIndex = 3,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, radius - 4) }),
				gradient = e("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new(0.55, 0.8),
				}),
			}),
		}),
		title = e(ToonText, {
			text = spec.title,
			textSize = titleSize,
			position = UDim2.fromOffset(textLeft, math.max(4, height * 0.08)),
			size = UDim2.new(1, -textLeft - height * 0.95, 0, titleSize + 12),
			fit = true,
			zIndex = 3,
		}),
	}
	if spec.subtitle ~= nil then
		nodes.subtitle = e(ToonText, {
			text = spec.subtitle,
			font = "body",
			color = Color3.new(1, 1, 1),
			textSize = 22,
			position = UDim2.fromOffset(textLeft + 4, titleSize + math.max(8, height * 0.12)),
			size = UDim2.new(1, -textLeft - height * 1.1, 0, 28),
			fit = true,
			zIndex = 3,
		})
	end
	if spec.goo == true then
		nodes.goo = e(ToonGoo, {
			kind = "cap",
			width = props.size.X,
			radius = radius,
			scale = spec.gooScale or 0.75,
			top = height - 3,
			zIndex = 2,
		})
	end
	local art = spec.art
	if art ~= nil then
		-- The art breaks the panel's top-left corner where the render would.
		nodes.icon = e("Frame", {
			Position = UDim2.fromOffset(-iconSize * 0.23, -iconSize * 0.26),
			Size = UDim2.fromOffset(iconSize, iconSize),
			BackgroundTransparency = 1,
			ZIndex = 8,
		}, { art = art(iconSize) })
	elseif hasIcon then
		-- The render breaks the panel's top-left corner.
		nodes.icon = e(ToonIcon, {
			icon = spec.icon,
			position = UDim2.fromOffset(-iconSize * 0.23, -iconSize * 0.26),
			size = UDim2.fromOffset(iconSize, iconSize),
			rotation = -8,
			drop = 7,
			zIndex = 8,
		})
	end
	if props.onClose ~= nil then
		local onClose = props.onClose
		nodes.close = e(ToonButton, {
			variant = "danger",
			text = "X",
			textSize = math.floor(height * 0.36),
			layout = "inline",
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -math.floor(height * 0.2), 0, height / 2),
			size = UDim2.fromOffset(math.floor(height * 0.66), math.floor(height * 0.6)),
			small = height < 90,
			sound = "back",
			onActivated = onClose,
			zIndex = 8,
		})
	end
	return nodes
end

local function ToonPanel(props: ToonPanelProps): React.ReactNode
	local hue: UIToonConstants.Hue = props.hue or "cream"
	local radius = props.radius or DEPTH.panelRadius
	local pop = useToonPlay(if props.pop then MOTION.popSeconds else 0, 0, nil)
	local children: { [string]: React.ReactNode } = {}
	if props.header ~= nil then
		for key, node in header(props, props.header, radius) do
			children[`header_{key}`] = node
		end
	end
	if props.goo ~= nil then
		children.goo = e(ToonGoo, {
			kind = props.goo.kind,
			width = props.size.X,
			radius = radius,
			from = props.goo.from,
			to = props.goo.to,
			scale = props.goo.scale,
			zIndex = 2,
		})
	end
	if props.children ~= nil then
		for key, node in props.children do
			children[key] = node
		end
	end
	local overlay: { [string]: React.ReactNode } = {}
	if props.overlay ~= nil then
		for key, node in props.overlay do
			overlay[key] = node
		end
	end
	if props.wipe then
		overlay.wipe = e(ToonWipe, { radius = radius, zIndex = 50 })
	end
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = UDim2.fromOffset(props.size.X, props.size.Y),
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
	}, {
		pop = e("UIScale", {
			Scale = pop:map(function(alpha: number): number
				return if props.pop then ToonMotionViewModel.pop(alpha) else 1
			end),
		}),
		surface = e(ToonSurface, {
			hue = hue,
			size = UDim2.fromScale(1, 1),
			radius = radius,
			pattern = if hue == "cream" then "sparkle" else "bubbles",
			gloss = props.gloss,
			children = children,
			overlay = overlay,
		}),
	})
end

return ToonPanel
