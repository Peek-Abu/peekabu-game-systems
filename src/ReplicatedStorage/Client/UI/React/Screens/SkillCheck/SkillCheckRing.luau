--!strict
--[=[
	SkillCheckRing: the closing ring, on the kit's restrained shift-HUD stack (few pieces, same depth: ink outline, hard
	ink drop, a body gradient from each hue's hi to lo). The inner circle is a ring of night beads whose opening beads
	glow mint: put the icon there. The outer ring is Gloom-grape beads (the goo's own colours) with the one opening left
	out and two cream posts at its edges, closing in on the inner circle by `fraction` (fading in over its first
	moments). The icon is a cream knob with the vacuum render and the kit's lilac selected ring, riding the inner circle
	at `angle`. A verdict flashes by `flash`: a mint ring and a pop on a hit, a coral ring and a shake on a miss. The
	`hint` words ("Line it up!") sit beside the ring (never under it, where the hotbar is). No sparkle shapes, no faces. Laid out in HUD design px (SkillCheckHud
	draws it inside PaperHudFrame). Presentational (exempt; story in SkillCheckRing.story; layout and motion specced in
	SkillCheckRingViewModel).

	@class SkillCheckRing
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SkillCheckRingViewModel = require(ReplicatedStorage.Client.UI.React.Screens.SkillCheck.SkillCheckRingViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local GLOOM: UIToonConstants.Shade = { hi = COLOR.gooHi, base = COLOR.gooBase, lo = COLOR.gooLo }
-- The share of each bead's slot round its circle the bead fills (the rest is the gap between beads).
local BEAD_FILL = 0.62

export type SkillCheckRingProps = {
	layout: SkillCheckRingViewModel.Layout,
	-- The ring's centre in HUD design px.
	centre: Vector2,
	gap: number,
	width: number,
	-- 0 at the ring's start to 1 at its arrival.
	fraction: React.Binding<number>,
	-- The icon's angle (screen degrees).
	angle: React.Binding<number>,
	-- The verdict flash's strength (1 just judged, fading to 0) and the verdict (nil: none yet).
	flash: React.Binding<number>,
	hit: boolean?,
	-- The words under the ring (the first rings only); nil: none.
	hint: string?,
	-- Handed the inner circle's frame (the input's centre and radius are read from it).
	onHub: ((Frame?) -> ())?,
}

local function gradient(shade: UIToonConstants.Shade): React.ReactNode
	return e("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, shade.hi),
			ColorSequenceKeypoint.new(0.45, shade.base),
			ColorSequenceKeypoint.new(1, shade.lo),
		}),
		Rotation = 90,
	})
end

type BeadProps = {
	position: UDim2 | React.Binding<UDim2>,
	size: UDim2 | React.Binding<UDim2>,
	rotation: number,
	shade: UIToonConstants.Shade,
	outline: number,
	drop: number,
	transparency: (number | React.Binding<number>)?,
	zIndex: number,
}

-- One bead: a hard ink drop under a rounded pill with an ink outline and its hue's gradient.
local function Bead(props: BeadProps): React.ReactNode
	local transparency = props.transparency or 0
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.position,
		Size = props.size,
		Rotation = props.rotation,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, {
		drop = e("Frame", {
			Position = UDim2.fromOffset(0, props.drop),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			ZIndex = props.zIndex,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			ZIndex = props.zIndex + 1,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			stroke = e("UIStroke", {
				Color = COLOR.ink,
				Thickness = props.outline,
				Transparency = transparency,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			fill = gradient(props.shade),
		}),
	})
end

-- A plain stroked circle of `radius` round the ring's centre (the verdict flash).
local function circle(
	radius: number,
	color: Color3,
	thickness: number,
	transparency: React.Binding<number>
): React.ReactNode
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(2 * radius, 2 * radius),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		stroke = e("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency }),
	})
end

local function SkillCheckRing(props: SkillCheckRingProps): React.ReactNode
	local layout: SkillCheckRingViewModel.Layout = props.layout
	local metrics = SkillCheckRingViewModel.METRICS[layout]
	local phone = layout == "phone"
	local outline = if phone then 2 else 3
	local drop = if phone then 2 else 3
	local beads = SkillCheckRingViewModel.beads(metrics.beads, props.gap, props.width)
	-- A bead's length per stud of radius (its slot round the circle, less the gap between beads).
	local perRadius = 2 * math.pi / metrics.beads * BEAD_FILL
	local children: { [string]: React.ReactNode } = {}

	-- The inner circle: night beads, the opening's beads mint.
	for index, bead in beads do
		local at = SkillCheckRingViewModel.place(bead.angle, metrics.inner)
		children[`inner{index}`] = e(Bead, {
			position = UDim2.new(0.5, at.X, 0.5, at.Y),
			size = UDim2.fromOffset(perRadius * metrics.inner, metrics.bead * 0.8),
			rotation = bead.angle,
			shade = if bead.open then UIToonConstants.shade("mint") else UIToonConstants.shade("night"),
			outline = outline,
			drop = drop,
			zIndex = 2,
		})
	end

	-- The outer ring: Gloom beads with the opening left out, closing in and fading in over its first fifth.
	local fadeIn = props.fraction:map(function(value: number): number
		return math.max(0, 1 - value * 5)
	end)
	local function outerAt(angle: number): React.Binding<UDim2>
		return props.fraction:map(function(value: number): UDim2
			local at = SkillCheckRingViewModel.place(angle, SkillCheckRingViewModel.outerRadius(layout, value))
			return UDim2.new(0.5, at.X, 0.5, at.Y)
		end)
	end
	local outerSize = props.fraction:map(function(value: number): UDim2
		local radius = SkillCheckRingViewModel.outerRadius(layout, value)
		return UDim2.fromOffset(math.max(perRadius * radius, metrics.bead), metrics.bead)
	end)
	for index, bead in beads do
		if not bead.open then
			children[`outer{index}`] = e(Bead, {
				position = outerAt(bead.angle),
				size = outerSize,
				rotation = bead.angle,
				shade = GLOOM,
				outline = outline,
				drop = drop,
				transparency = fadeIn,
				zIndex = 4,
			})
		end
	end
	-- Cream posts at the opening's edges, standing across the ring so the opening reads at a glance.
	for side, edge in { -1, 1 } do
		local angle = props.gap + edge * props.width / 2
		children[`post{side}`] = e(Bead, {
			position = outerAt(angle),
			size = UDim2.fromOffset(metrics.bead * 0.85, metrics.bead * 1.9),
			rotation = angle,
			shade = UIToonConstants.shade("cream"),
			outline = outline,
			drop = drop,
			transparency = fadeIn,
			zIndex = 5,
		})
	end

	-- The verdict flash: a ring at the inner circle, mint on a hit, coral on a miss.
	local hit = props.hit
	if hit ~= nil then
		children.verdict = circle(
			metrics.inner + metrics.bead,
			if hit then UIToonConstants.shade("mint").base else UIToonConstants.shade("coral").base,
			metrics.bead * 0.9,
			props.flash:map(function(value: number): number
				return 1 - value
			end)
		)
	end

	-- The icon: a cream knob with the vacuum render and the lilac selected ring; it pops on a hit.
	local knob = metrics.knob
	children.knob = e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.angle:map(function(value: number): UDim2
			local at = SkillCheckRingViewModel.place(value, metrics.inner)
			return UDim2.new(0.5, at.X, 0.5, at.Y)
		end),
		Size = UDim2.fromOffset(knob, knob),
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, {
		pop = e("UIScale", {
			Scale = props.flash:map(function(value: number): number
				return if hit == true then 1 + 0.25 * value else 1
			end),
		}),
		drop = e("Frame", {
			Position = UDim2.fromOffset(0, drop + 1),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.ink,
			BorderSizePixel = 0,
			ZIndex = 8,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 9,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			stroke = e("UIStroke", {
				Color = COLOR.selected,
				Thickness = outline + 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			fill = gradient(UIToonConstants.shade("cream")),
		}),
		icon = e(ToonIcon, {
			icon = "vacuum",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			size = UDim2.fromOffset(knob * 0.78, knob * 0.78),
			drop = 0,
			zIndex = 10,
		}),
	})

	local hint = props.hint
	if hint ~= nil then
		-- Beside the ring, never under it (the hotbar is there): SkillCheckRingViewModel.hintFrame.
		local frame = SkillCheckRingViewModel.hintFrame(layout)
		children.hint = e(ToonText, {
			text = hint,
			textSize = metrics.hint,
			meaning = "mint",
			anchor = frame.anchor,
			align = if frame.anchor.X > 0 then "right" else "left",
			position = UDim2.new(0.5, frame.offset.X, 0.5, frame.offset.Y),
			size = UDim2.fromOffset(frame.size.X, frame.size.Y),
			fit = true,
			zIndex = 12,
		})
	end

	-- A miss shakes the whole ring sideways a few px as its flash fades.
	local hub = 2 * metrics.inner
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.flash:map(function(value: number): UDim2
			local shake = if hit == false then math.sin(value * 40) * 6 * value else 0
			return UDim2.fromOffset(props.centre.X + shake, props.centre.Y)
		end),
		Size = UDim2.fromOffset(hub, hub),
		BackgroundTransparency = 1,
		ref = props.onHub,
	}, children)
end

return SkillCheckRing
