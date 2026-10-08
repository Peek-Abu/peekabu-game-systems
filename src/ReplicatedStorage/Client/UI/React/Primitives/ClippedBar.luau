--!strict
--[=[
	ClippedBar: the reusable "sprite bar" behind every meter in the HUD — resource bars (health / rot /
	stamina) and the XP bar all render through this one component. It owns the *mechanism*; the caller
	supplies the *look* (which sprites, colour, tick count).

	**The clip technique (why this isn't a stretched sprite).** A meter must not squash its art as the
	value drops — the fill sprite keeps its native proportions and is simply *revealed* left-to-right,
	via a `ClipsDescendants` window:

	- the **clip** frame's width is the fraction (`X.Scale = f`), masking off the empty part, and
	- the **fill** (and its overlay) counter-scale to `X.Scale = 1/f`, so their *absolute* width stays
	  the full bar width at any fraction.

	Their product is the bar width at every value — the sprite is a fixed-width image the clip slides a
	window over (identical to the authored `resizeCustomLoadingBar`: clip → `f`, fill → `1/f`). Because
	both sizes derive from the SAME `f` each render, they never desync — unlike the authored code, which
	tweened `f` and `1/f` independently and momentarily over-widened the sprite mid-animation.

	**Layering, back to front (sibling ZIndex, so each layer's whole subtree stacks in order):**
	`backdrop` (a solid track BEHIND the fill — the XP bar has one; hollow-framed bars don't) → `catchup`
	(the damage/drain trail, a second clip lagging behind the main one) → the main `fill` (+ optional
	outline) → `overlay` (a gloss/shade over the fill, clipped with it) → `frame` (a HOLLOW border IN
	FRONT — resource bars have one, the XP bar doesn't) → `tick` dividers, front-most.

	A solid sprite must go in `backdrop` (behind), never `frame` (front) — a front solid layer hides the
	fill entirely. All ids come from `UIAssets` via the caller (the CI gate forbids literals here).

	@class ClippedBar
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

-- Back-to-front sibling ZIndex ladder for the bar's layers.
local BACKDROP_ZINDEX = 1
local CATCHUP_ZINDEX = 2
local CLIP_ZINDEX = 3
local FRAME_ZINDEX = 4
local TICK_ZINDEX = 5
-- Within a clip window: fill under overlay.
local FILL_ZINDEX = 1
local OVERLAY_ZINDEX = 2

local TICK_WIDTH_PX = 2

-- An outline on the fill sprite (Rot uses a saturated purple; most bars pass nil).
export type BarStroke = {
	color: Color3,
	thickness: number,
	transparency: number,
}

-- A tinted sprite layer (backdrop behind the fill, or gloss/shade over it).
export type BarLayer = {
	image: string,
	tint: Color3,
	transparency: number,
}

-- The hollow frame drawn in front of the fill.
export type BarFrame = {
	image: string,
	tint: Color3,
}

-- The divider sprite. `heightScale` lets ticks overhang the bar (XP notches stand taller than 1).
export type BarTick = {
	image: string,
	tint: Color3,
	heightScale: number,
}

-- The sprite set that gives a bar its look. `fill` is tinted by the `color` prop; the rest carry their
-- own tints. Every layer but `fill` is optional — a bar has EITHER a `backdrop` (solid, behind) OR a
-- `frame` (hollow, in front), not both, and may skip the gloss/ticks.
export type BarSprites = {
	backdrop: BarLayer?,
	fill: string,
	overlay: BarLayer?,
	frame: BarFrame?,
	tick: BarTick?,
}

-- The lagging drain trail behind the fill: its own fraction (eased by the caller) reusing `fill`'s
-- sprite in a darker tint.
export type BarCatchup = {
	fraction: number | React.Binding<number>,
	tint: Color3,
}

export type ClippedBarProps = {
	position: UDim2,
	size: UDim2,
	color: Color3, -- the fill tint
	-- Fill as a fraction of the bar (0..1): a plain number for undriven bars, a binding for live values.
	fraction: number | React.Binding<number>,
	sprites: BarSprites,
	ticks: number,
	stroke: BarStroke?,
	catchup: BarCatchup?,
}

-- The clip window's width is the fraction; the fill inside counter-scales so its absolute width is
-- constant (the full bar). `invert` picks which of the two a given layer needs.
local function sizeFromFraction(fraction: number, invert: boolean): UDim2
	local f = math.clamp(fraction, 0, 1)
	if invert then
		return UDim2.fromScale(if f > 0 then 1 / f else 0, 1)
	end
	return UDim2.fromScale(f, 1)
end

-- (clip width, fill counter-scale) for a fraction, whether static or a live binding.
local function sizesFor(
	fraction: number | React.Binding<number>
): (UDim2 | React.Binding<UDim2>, UDim2 | React.Binding<UDim2>)
	if type(fraction) == "number" then
		return sizeFromFraction(fraction, false), sizeFromFraction(fraction, true)
	end
	return fraction:map(function(f: number)
		return sizeFromFraction(f, false)
	end),
		fraction:map(function(f: number)
			return sizeFromFraction(f, true)
		end)
end

-- A ClipsDescendants window (width = the fraction) holding counter-scaled inner layers.
local function clipWindow(
	clipSize: UDim2 | React.Binding<UDim2>,
	zindex: number,
	children: { [string]: React.ReactNode }
): React.ReactNode
	return e("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = clipSize,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = zindex,
	}, children)
end

-- A counter-scaled fill image (anchored left, stretched), optionally carrying children (e.g. a stroke).
local function fillImage(
	fillSize: UDim2 | React.Binding<UDim2>,
	image: string,
	tint: Color3,
	transparency: number,
	zindex: number,
	children: { [string]: React.ReactNode }?
): React.ReactNode
	return e("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = fillSize,
		BackgroundTransparency = 1,
		Image = image,
		ImageColor3 = tint,
		ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = zindex,
	}, children)
end

--[=[
	@param props ClippedBarProps
	@return React.ReactNode
]=]
local function ClippedBar(props: ClippedBarProps): React.ReactNode
	local sprites = props.sprites
	local clipSize, fillSize = sizesFor(props.fraction)

	local rootChildren: { [string]: React.ReactNode } = {}

	-- Backdrop: a solid track BEHIND the fill (not clipped).
	local backdrop = sprites.backdrop
	if backdrop ~= nil then
		rootChildren.backdrop = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = backdrop.image,
			ImageColor3 = backdrop.tint,
			ImageTransparency = backdrop.transparency,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = BACKDROP_ZINDEX,
		})
	end

	-- Catchup: the lagging drain trail, a clip behind the main fill using the fill sprite in a dark tint.
	local catchup = props.catchup
	if catchup ~= nil then
		local catchupClip, catchupFill = sizesFor(catchup.fraction)
		rootChildren.catchup = clipWindow(catchupClip, CATCHUP_ZINDEX, {
			fill = fillImage(catchupFill, sprites.fill, catchup.tint, 0, FILL_ZINDEX),
		})
	end

	-- Optional outline on the fill (built as a typed local so the sealed `{outline=…}` literal matches
	-- the `{ [string]: ReactNode }` indexer — the usual React-lua children-typing dance).
	local stroke = props.stroke
	local fillChildren: { [string]: React.ReactNode }? = nil
	if stroke ~= nil then
		-- Assign by index (not a sealed `{outline=…}` literal) so the element widens to ReactNode against
		-- the map's indexer — same reason the tick loop below builds its map this way.
		local children: { [string]: React.ReactNode } = {}
		children.outline = e("UIStroke", {
			Color = stroke.color,
			Thickness = stroke.thickness,
			Transparency = stroke.transparency,
			-- Inner so the outline sits inside the fill's edge rather than bulging the bar out.
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		})
		fillChildren = children
	end

	-- The main clip: the counter-scaled fill (+ optional outline) then an optional overlay over it.
	local clipChildren: { [string]: React.ReactNode } = {
		fill = fillImage(fillSize, sprites.fill, props.color, 0, FILL_ZINDEX, fillChildren),
	}
	local overlay = sprites.overlay
	if overlay ~= nil then
		clipChildren.overlay = fillImage(fillSize, overlay.image, overlay.tint, overlay.transparency, OVERLAY_ZINDEX)
	end
	rootChildren.clipping = clipWindow(clipSize, CLIP_ZINDEX, clipChildren)

	-- Frame: a HOLLOW border drawn IN FRONT of the fill.
	local frame = sprites.frame
	if frame ~= nil then
		rootChildren.frame = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = frame.image,
			ImageColor3 = frame.tint,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = FRAME_ZINDEX,
		})
	end

	-- Evenly spaced tick dividers, front-most (none when `ticks` is 0 or no tick sprite is given).
	local tick = sprites.tick
	if tick ~= nil then
		for i = 1, props.ticks do
			rootChildren[`tick-{i}`] = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(i / (props.ticks + 1), 0.5),
				Size = UDim2.new(0, TICK_WIDTH_PX, tick.heightScale, 0),
				BackgroundTransparency = 1,
				Image = tick.image,
				ImageColor3 = tick.tint,
				ScaleType = Enum.ScaleType.Stretch,
				ZIndex = TICK_ZINDEX,
			})
		end
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0, 0),
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
	}, rootChildren)
end

return ClippedBar
