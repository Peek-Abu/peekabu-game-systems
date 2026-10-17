--!strict
--[=[
	ToonStyleViewModel: the V1 kit's state and colour rules. `pose` is the tween target of every state (hover lifts
	and grows with the drop growing under it; press drops the body onto its shadow, collapsing the drop and the lip;
	selected lifts, grows and rings in V2's lilac; the unselected siblings recede; disabled ignores all of it). `hue`
	is a variant's palette colour (steel when disabled), `textOn` the text colour that reads on a face, `stroke` /
	`drop` the ink stroke and hard drop for display text of a size, `grouped` a count with thousands commas, `blend` the pose part-way between two states. Pure.

	@class ToonStyleViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

export type Variant = "primary" | "gleam" | "danger" | "secondary" | "grape" | "night" | "sky" | "lilac"

export type State = {
	hovered: boolean,
	pressed: boolean,
	selected: boolean,
	disabled: boolean,
	receded: boolean,
}

export type Pose = {
	-- Up is positive (design px the body rises from rest).
	lift: number,
	scale: number,
	-- How far below the body its ink drop shows.
	drop: number,
	-- 1 = the lip at full height, less when the press squashes it.
	lip: number,
	-- 0..1: the lilac selected ring and glow.
	ring: number,
	-- 0..1: how much the face is darkened (a receded sibling).
	dim: number,
}

local MOTION = UIToonConstants.MOTION
local DEPTH = UIToonConstants.DEPTH

local HUE: { [Variant]: UIToonConstants.Hue } = table.freeze({
	primary = "mint",
	gleam = "gold",
	danger = "coral",
	secondary = "cream",
	grape = "grape",
	night = "night",
	sky = "sky",
	lilac = "lilac",
})

local INK_ON: { [UIToonConstants.Hue]: boolean } = table.freeze({
	cream = true,
	steel = false,
	grape = false,
	gold = false,
	mint = false,
	coral = false,
	night = false,
	sky = false,
	lilac = false,
})

local ToonStyleViewModel = {}

function ToonStyleViewModel.pose(state: State): Pose
	local pose: Pose = { lift = 0, scale = 1, drop = DEPTH.drop, lip = 1, ring = 0, dim = 0 }
	if state.disabled then
		return pose
	end
	if state.selected then
		pose.ring = 1
		pose.lift = MOTION.selectedLift
		pose.scale = MOTION.selectedScale
	elseif state.receded then
		pose.scale = MOTION.recedeScale
		pose.dim = 0.15
	end
	if state.pressed then
		-- The body sinks most of the way onto its drop; the lip squashes with it.
		pose.lift = -(DEPTH.drop - 2)
		pose.lip = 0.45
		pose.scale = MOTION.pressScale
	elseif state.hovered then
		pose.lift = math.max(pose.lift, MOTION.hoverLift)
		pose.scale = math.max(pose.scale, MOTION.hoverScale)
		pose.dim = 0
	end
	-- The drop stays where it was at rest, so it shows as much more (or less) as the body moved.
	pose.drop = DEPTH.drop + pose.lift
	return pose
end

-- The pose `t` (0..1) of the way from `from` to `to` (what a tween draws between two states).
function ToonStyleViewModel.blend(from: Pose, to: Pose, t: number): Pose
	local function mix(a: number, b: number): number
		return a + (b - a) * t
	end
	return {
		lift = mix(from.lift, to.lift),
		scale = mix(from.scale, to.scale),
		drop = mix(from.drop, to.drop),
		lip = mix(from.lip, to.lip),
		ring = mix(from.ring, to.ring),
		dim = mix(from.dim, to.dim),
	}
end

function ToonStyleViewModel.hue(variant: Variant, disabled: boolean): UIToonConstants.Hue
	if disabled then
		return "steel"
	end
	return HUE[variant]
end

function ToonStyleViewModel.textOn(hue: UIToonConstants.Hue): "ink" | "white"
	return if INK_ON[hue] then "ink" else "white"
end

-- The ink stroke for display text `size` px tall (about an eighth of it, 2..14).
function ToonStyleViewModel.stroke(size: number): number
	return math.clamp(math.round(size * DEPTH.textStroke), 2, 14)
end

-- The hard ink drop under display text `size` px tall (2..8).
function ToonStyleViewModel.drop(size: number): number
	return math.clamp(math.round(size * DEPTH.textDrop), 2, 8)
end

--[=[
	Luckiest Guy's line box is its hhea ascent (1440) over its descent (608) of 2048 units, and its caps and digits
	stand on the baseline up to the ascent: they fill the top 70% of the line, so text aligned to the box's centre
	reads high by this fraction of its size (twice it at the bottom).
]=]
-- The caps' centre (half the ascent) above the line box's centre (half of ascent minus descent), in ems.
ToonStyleViewModel.DISPLAY_CAP_SHIFT = (1440 / 2 - (1440 - 608) / 2) / 2048

-- How far down (px) display text drawn at `size` with a hard drop of `drop` px moves so that its caps and its drop,
-- together, sit centred in (or on the foot of) its box: its caps' offset in the line box, less the drop hanging under
-- it (half of it when centred). Top-aligned text keeps its caps at the box's top.
function ToonStyleViewModel.optical(alignY: "top" | "center" | "bottom", size: number, drop: number): number
	if alignY == "top" or size <= 0 then
		return 0
	end
	local shift = ToonStyleViewModel.DISPLAY_CAP_SHIFT * size
	if alignY == "bottom" then
		return 2 * shift - drop
	end
	return shift - drop / 2
end

function ToonStyleViewModel.grouped(value: number): string
	if value ~= value or value <= 0 then
		return "0"
	end
	local digits = tostring(math.floor(value))
	local groups: { string } = {}
	local index = #digits
	while index > 0 do
		table.insert(groups, 1, string.sub(digits, math.max(1, index - 2), index))
		index -= 3
	end
	return table.concat(groups, ",")
end

return ToonStyleViewModel
