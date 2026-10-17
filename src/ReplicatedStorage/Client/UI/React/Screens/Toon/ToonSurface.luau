--!strict
--[=[
	ToonSurface: the V1 depth stack every panel, button, pill and slot is drawn on (depth-stack.md), as Frames, back
	to front: the lilac selected ring and glow, the hard ink drop, the lip (the body's darker hue along the bottom,
	carrying the ink outline), the body (hi -> base gradient), the inner light rim, the hard-edged gloss band and the
	pattern tile. `pose` (a binding, else rest) moves the body over its drop: hover lifts it, press sinks it onto the
	drop and squashes the lip, selected lifts it and lights the ring; `scale` is applied around the centre. Children
	are drawn on the body's face (above the lip), in front of the stack; `overlay` over the whole face, lip included. Presentational (exempt; story in
	ToonSurface.story; the poses are specced in ToonStyleViewModel).

	@class ToonSurface
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

local DEPTH = UIToonConstants.DEPTH
local COLOR = UIToonConstants.COLOR

export type Pattern = "sparkle" | "bubbles"

export type ToonSurfaceProps = {
	hue: UIToonConstants.Hue,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	radius: number?,
	pose: React.Binding<ToonStyleViewModel.Pose>?,
	pattern: Pattern?,
	-- The gloss band (default on; dark in-run plates may drop it).
	gloss: boolean?,
	-- Thinner chrome for small pieces (pills, tags): a thinner outline, drop and lip.
	small: boolean?,
	zIndex: number?,
	layoutOrder: number?,
	children: { [string]: React.ReactNode }?,
	-- Drawn over the whole face, lip included (a goo pool that sits on the component's very bottom edge).
	overlay: { [string]: React.ReactNode }?,
}

local REST: ToonStyleViewModel.Pose = ToonStyleViewModel.pose({
	hovered = false,
	pressed = false,
	selected = false,
	disabled = false,
	receded = false,
})
local restBinding = React.createBinding(REST)

local PATTERN: { [Pattern]: { image: string, tile: number, tint: Color3 } } = {
	sparkle = { image = UIAssets.toon.patternSparkle, tile = 72, tint = UIToonConstants.shade("grape").base },
	bubbles = { image = UIAssets.toon.patternBubbles, tile = 60, tint = COLOR.white },
}

-- The gloss band's transparency (top, bottom) per hue: dark plates take a fainter gloss, so they read as lacquer
-- rather than a grey stripe.
local GLOSS: { [UIToonConstants.Hue]: { top: number, bottom: number } } = {
	night = { top = 0.8, bottom = 0.94 },
	grape = { top = 0.6, bottom = 0.85 },
	coral = { top = 0.5, bottom = 0.78 },
	cream = { top = 0.3, bottom = 0.7 },
	gold = { top = 0.42, bottom = 0.72 },
	mint = { top = 0.42, bottom = 0.72 },
	sky = { top = 0.42, bottom = 0.72 },
	lilac = { top = 0.45, bottom = 0.75 },
	steel = { top = 0.5, bottom = 0.8 },
}

local function corner(radius: number): React.ReactNode
	return e("UICorner", { CornerRadius = UDim.new(0, math.max(0, radius)) })
end

local function ToonSurface(props: ToonSurfaceProps): React.ReactNode
	local shade = UIToonConstants.shade(props.hue)
	local radius = props.radius or DEPTH.buttonRadius
	local small = props.small == true
	local outline = if small then 3 else DEPTH.outline
	local lipHeight = if small then 5 else DEPTH.lip
	local dropScale = if small then 0.6 else 1
	local pose = props.pose or restBinding
	local gloss = GLOSS[props.hue]

	local face: { [string]: React.ReactNode } = {
		-- The lip: the whole shape in the darker hue, outlined in ink. The body sits on it, short of its bottom.
		lip = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = shade.lo,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			corner = corner(radius),
			stroke = e("UIStroke", {
				Color = COLOR.ink,
				Thickness = outline,
				LineJoinMode = Enum.LineJoinMode.Round,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		body = e("Frame", {
			Size = pose:map(function(value: ToonStyleViewModel.Pose): UDim2
				return UDim2.new(1, 0, 1, -lipHeight * value.lip)
			end),
			BackgroundColor3 = shade.base,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			corner = corner(radius),
			gradient = e("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, shade.hi),
					ColorSequenceKeypoint.new(0.5, shade.base),
					ColorSequenceKeypoint.new(1, shade.base),
				}),
			}),
			-- The pattern tile, clipped to the body's rounded shape by its own corner.
			pattern = if props.pattern ~= nil
				then e("ImageLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = PATTERN[props.pattern].image,
					ImageColor3 = PATTERN[props.pattern].tint,
					ImageTransparency = DEPTH.patternTransparency,
					ScaleType = Enum.ScaleType.Tile,
					TileSize = UDim2.fromOffset(PATTERN[props.pattern].tile, PATTERN[props.pattern].tile),
					ZIndex = 2,
				}, { corner = corner(radius) })
				else nil,
			-- The inner light rim: a stroke drawn just inside the body's edge, strong at the top, gone at the foot.
			rim = e("Frame", {
				Position = UDim2.fromOffset(DEPTH.rim, DEPTH.rim),
				Size = UDim2.new(1, -2 * DEPTH.rim, 1, -2 * DEPTH.rim),
				BackgroundTransparency = 1,
				ZIndex = 3,
			}, {
				corner = corner(radius - DEPTH.rim),
				stroke = e("UIStroke", {
					Color = COLOR.white,
					Thickness = DEPTH.rim,
					Transparency = 0,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}, {
					gradient = e("UIGradient", {
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, DEPTH.rimTransparency - 0.2),
							NumberSequenceKeypoint.new(0.45, DEPTH.rimTransparency + 0.25),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),
				}),
			}),
			-- The gloss band: the top 44%, inset, with a hard lower edge (candy plastic, not airbrush).
			gloss = if props.gloss ~= false
				then e("Frame", {
					Position = UDim2.fromOffset(outline, math.max(3, outline - 1)),
					Size = UDim2.new(1, -2 * outline, DEPTH.gloss, -math.max(3, outline - 1)),
					BackgroundColor3 = COLOR.white,
					BorderSizePixel = 0,
					ZIndex = 4,
				}, {
					corner = corner(radius - outline),
					gradient = e("UIGradient", {
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, gloss.top),
							NumberSequenceKeypoint.new(1, gloss.bottom),
						}),
					}),
				})
				else nil,
			-- A receded sibling darkens.
			dim = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = COLOR.ink,
				BackgroundTransparency = pose:map(function(value: ToonStyleViewModel.Pose): number
					return 1 - value.dim
				end),
				BorderSizePixel = 0,
				ZIndex = 5,
			}, { corner = corner(radius) }),
			content = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 6,
			}, props.children),
		}),
		overlay = if props.overlay ~= nil
			then e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, props.overlay)
			else nil,
	}

	local stack: { [string]: React.ReactNode } = {
		scale = e("UIScale", {
			Scale = pose:map(function(value: ToonStyleViewModel.Pose): number
				return value.scale
			end),
		}),
		-- The lilac selected glow (a tinted soft 9-slice) and ring, outside the outline.
		glow = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 56, 1, 56),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.glow,
			ImageColor3 = COLOR.selected,
			ImageTransparency = pose:map(function(value: ToonStyleViewModel.Pose): number
				return 1 - 0.85 * value.ring
			end),
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(48, 48, 80, 80),
			ZIndex = 1,
		}),
		ring = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = pose:map(function(value: ToonStyleViewModel.Pose): UDim2
				return UDim2.new(0.5, 0, 0, -value.lift - outline - 3)
			end),
			Size = UDim2.new(1, 2 * (outline + 3), 1, 2 * (outline + 3) + DEPTH.drop * dropScale),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			corner = corner(radius + outline + 3),
			stroke = e("UIStroke", {
				Color = COLOR.selected,
				Thickness = 5,
				Transparency = pose:map(function(value: ToonStyleViewModel.Pose): number
					return 1 - value.ring
				end),
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		-- The hard drop stays put; the body moves over it.
		drop = e("Frame", {
			Position = UDim2.fromOffset(0, DEPTH.drop * dropScale),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.ink,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, {
			corner = corner(radius),
			stroke = e("UIStroke", {
				Color = COLOR.ink,
				Thickness = outline,
				LineJoinMode = Enum.LineJoinMode.Round,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		face = e("Frame", {
			Position = pose:map(function(value: ToonStyleViewModel.Pose): UDim2
				return UDim2.fromOffset(0, -value.lift * dropScale)
			end),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, face),
	}

	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
	}, {
		-- Centred inside, so the pose's scale grows and shrinks the stack about its middle.
		stack = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, stack),
	})
end

return ToonSurface
