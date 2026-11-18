--!strict
--[=[
	SkillCheckRingViewModel: the closing ring's layout and motion, in HUD design px (desktop 1920x1080, phone 844x390;
	PaperHudFrame scales them). The inner circle is a ring of beads whose opening beads glow mint (where to put the
	icon); the outer ring is a ring of Gloom-grape beads with the opening left out, closing straight in from
	`outerStart` to the inner circle over the ring's travel (`fraction`, on the server clock). The icon rides the inner
	circle at the player's angle (`place`). A verdict flashes for FLASH_SECONDS; the ring stays LINGER seconds past its
	arrival so the flash reads, then goes. It sits over the local character's real top on screen, or beside the
	character when the top has no room (`placement`), and the words show beside it for the first rings only (`hint`,
	`hintSide`). Pure.

	@class SkillCheckRingViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillCheckAngleFormulas = require(ReplicatedStorage.Shared.Features.SkillCheck.Utils.SkillCheckAngleFormulas)

export type Layout = "desktop" | "phone"

export type Metrics = {
	-- The inner circle's radius and the outer ring's radius at its start.
	inner: number,
	outerStart: number,
	-- Beads in each ring, and a bead's thickness.
	beads: number,
	bead: number,
	-- The icon's size and the hint's text size.
	knob: number,
	hint: number,
	-- How far below the screen's middle the ring's centre sits (negative: above it). Kept under TOP_RESERVE.
	below: number,
}

export type Bead = { angle: number, open: boolean }

local METRICS: { [Layout]: Metrics } = table.freeze({
	desktop = table.freeze({
		inner = 70,
		outerStart = 200,
		beads = 36,
		bead = 16,
		knob = 48,
		hint = 30,
		-- Above the middle, over the character's head rather than its body (owner 11-18, "a bit higher, off your
		-- character"; it sat on the body at +110); TOP_RESERVE stops it at the Gloom meter.
		below = -180,
	}),
	phone = table.freeze({
		inner = 46,
		outerStart = 120,
		beads = 28,
		bead = 11,
		knob = 34,
		hint = 18,
		below = 30,
	}),
})

-- A box on screen in HUD design px (the character's projected bounds).
export type Box = { left: number, top: number, right: number, bottom: number }

-- Where the ring goes: above the character, beside it (right or left), or the plain middle placement (no character).
export type Spot = "above" | "right" | "left" | "middle"
export type Placement = { centre: Vector2, spot: Spot }

export type HintFrame = {
	-- The hint box's anchor point, as an offset from the ring's centre (design px).
	offset: Vector2,
	anchor: Vector2,
	size: Vector2,
}

-- The hint box's size (the words fit inside it).
local HINT_SIZE: { [Layout]: Vector2 } = table.freeze({
	desktop = Vector2.new(220, 40),
	phone = Vector2.new(130, 28),
})

local SkillCheckRingViewModel = {
	METRICS = METRICS,
	-- Design px at the top the outer ring's start never reaches into: desktop, the Gloom meter's band (its top 40 + 96
	-- tall, ShiftHudViewModel.METER) and a margin. Phone: the screen is too short to clear the meter and its hearts
	-- (98 + about 20) with the ring still above the hotbar, so the phone ring only keeps a little under the meter.
	TOP_RESERVE = table.freeze({ desktop = 160, phone = 105 }),
	-- Design px kept free at the bottom of the screen for the HUD's bottom-centre stack (hotbar, stamina bar, the
	-- prompt chip over them), and at each side (Roblox's buttons, the phone's thumbstick and action arc): the hint never
	-- goes there (2026-11-18: under the ring it sat on the hotbar).
	HINT_BOTTOM_RESERVE = table.freeze({ desktop = 220, phone = 130 }),
	HINT_SIDE_RESERVE = table.freeze({ desktop = 60, phone = 50 }),
	-- The side the hint prefers: right on desktop; left on a phone, whose action arc (HELPER, SPRINT) is right of the
	-- ring at its height.
	HINT_SIDE = table.freeze({ desktop = 1, phone = -1 }),
	-- Design px between the character's box and the inner circle's beads (placement).
	HEAD_MARGIN = table.freeze({ desktop = 16, phone = 10 }),
	-- The sides placement tries, in order, when the character's top has no room: right then left on desktop; left
	-- first on a phone, whose action arc (HELPER, SPRINT) is on the right.
	SIDE_ORDER = table.freeze({ desktop = table.freeze({ 1, -1 }), phone = table.freeze({ -1, 1 }) }),
	-- The gap between the outer ring's start and the hint.
	HINT_GAP = 12,
	HINT_SIZE = HINT_SIZE,
	-- Seconds a verdict's flash lasts, and the ring stays after arriving.
	FLASH_SECONDS = 0.4,
	LINGER = 0.45,
}

--[=[
	How far the outer ring has closed in, 0 at its start to 1 at `arriveAt` (server clock), clamped.
]=]
function SkillCheckRingViewModel.fraction(now: number, arriveAt: number, travel: number): number
	if travel <= 0 or now >= arriveAt then
		return 1
	end
	return math.clamp((now - (arriveAt - travel)) / travel, 0, 1)
end

--[=[
	The outer ring's radius at `fraction`: straight in from its start to the inner circle.
]=]
function SkillCheckRingViewModel.outerRadius(layout: Layout, fraction: number): number
	local metrics = METRICS[layout]
	return metrics.outerStart + (metrics.inner - metrics.outerStart) * math.clamp(fraction, 0, 1)
end

--[=[
	`count` beads evenly round the circle from straight up, each marked open when it sits in the opening centred on
	`gap`, `width` wide. However narrow the opening, the bead nearest its centre is open, so it always shows.
]=]
function SkillCheckRingViewModel.beads(count: number, gap: number, width: number): { Bead }
	local list: { Bead } = {}
	local nearest, nearestDistance = 1, math.huge
	for index = 1, count do
		local angle = (index - 1) * 360 / count
		local distance = SkillCheckAngleFormulas.distance(angle, gap)
		if distance < nearestDistance then
			nearest, nearestDistance = index, distance
		end
		table.insert(list, { angle = angle, open = SkillCheckAngleFormulas.inGap(angle, gap, width, 0) })
	end
	if count > 0 then
		list[nearest].open = true
	end
	return list
end

--[=[
	The offset from the ring's centre of a point at `angle` on a circle of `radius` (design px, y down).
]=]
function SkillCheckRingViewModel.place(angle: number, radius: number): Vector2
	return SkillCheckAngleFormulas.toVector(angle) * radius
end

--[=[
	The ring's centre in the HUD's area (`viewport`, design px): the middle line, `below` the middle (above it on
	desktop), with the outer ring's start kept under TOP_RESERVE and on screen.
]=]
function SkillCheckRingViewModel.centre(layout: Layout, viewport: Vector2): Vector2
	local metrics = METRICS[layout]
	local top = SkillCheckRingViewModel.TOP_RESERVE[layout] + metrics.outerStart
	local y = math.clamp(viewport.Y / 2 + metrics.below, top, math.max(top, viewport.Y - metrics.outerStart))
	return Vector2.new(viewport.X / 2, y)
end

--[=[
	A viewport point (real px, as Camera:WorldToViewportPoint gives it) in HUD design px: measured from the HUD frame's
	`origin` (its AbsolutePosition, in the same px) and divided by the HUD's `scale`.
]=]
function SkillCheckRingViewModel.toDesign(point: Vector2, origin: Vector2, scale: number): Vector2
	return (point - origin) / scale
end

--[=[
	The box spanning `points` (the character's projected bounds), or nil for none.
]=]
function SkillCheckRingViewModel.screenBox(points: { Vector2 }): Box?
	if #points == 0 then
		return nil
	end
	local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
	for _, point in points do
		left = math.min(left, point.X)
		right = math.max(right, point.X)
		top = math.min(top, point.Y)
		bottom = math.max(bottom, point.Y)
	end
	return { left = left, top = top, right = right, bottom = bottom }
end

--[=[
	Where the ring goes for the local character's on-screen box `body` (design px; nil: no character on screen, the
	plain `centre` placement). The rule: the INNER circle (the icon and the opening, what the player watches) never
	overlaps the character; the outer ring may sweep over it for its short close. So the inner circle sits HEAD_MARGIN
	above the character's real top (ears, hats, tall skins: whatever its box holds), centred on it. When that would push
	the outer ring's start into TOP_RESERVE (camera close, or looking down), the ring goes beside the character at its
	top's height, its inner circle HEAD_MARGIN clear of the box, on the first side in SIDE_ORDER that keeps the outer
	ring on screen; with neither, the side with more room, against the screen's edge. Every placement keeps the outer
	ring's start under TOP_RESERVE and on screen.
]=]
function SkillCheckRingViewModel.placement(layout: Layout, viewport: Vector2, body: Box?): Placement
	if body == nil then
		return { centre = SkillCheckRingViewModel.centre(layout, viewport), spot = "middle" }
	end
	local metrics = METRICS[layout]
	local clear = metrics.inner + metrics.bead + SkillCheckRingViewModel.HEAD_MARGIN[layout]
	local minY = SkillCheckRingViewModel.TOP_RESERVE[layout] + metrics.outerStart
	local maxY = math.max(minY, viewport.Y - metrics.outerStart)
	local minX = metrics.outerStart
	local maxX = math.max(minX, viewport.X - metrics.outerStart)
	local above = body.top - clear
	if above >= minY then
		local x = math.clamp((body.left + body.right) / 2, minX, maxX)
		return { centre = Vector2.new(x, math.min(above, maxY)), spot = "above" }
	end
	local y = math.clamp(body.top, minY, maxY)
	for _, side in SkillCheckRingViewModel.SIDE_ORDER[layout] do
		local x = if side > 0 then body.right + clear else body.left - clear
		if x >= minX and x <= maxX then
			return { centre = Vector2.new(x, y), spot = if side > 0 then "right" else "left" }
		end
	end
	if viewport.X - body.right >= body.left then
		return { centre = Vector2.new(maxX, y), spot = "right" }
	end
	return { centre = Vector2.new(minX, y), spot = "left" }
end

--[=[
	Where the "Line it up!" words sit: beside the ring at its centre's height, just past the outer ring's start, on
	`side` (1 right, -1 left; default the layout's HINT_SIDE). Never under the ring, where the HUD's bottom stack (the
	hotbar) is.
]=]
function SkillCheckRingViewModel.hintFrame(layout: Layout, side: number?): HintFrame
	local metrics = METRICS[layout]
	local size = HINT_SIZE[layout]
	local reach = metrics.outerStart + metrics.bead + SkillCheckRingViewModel.HINT_GAP
	if (side or SkillCheckRingViewModel.HINT_SIDE[layout]) > 0 then
		return { offset = Vector2.new(reach, 0), anchor = Vector2.new(0, 0.5), size = size }
	end
	return { offset = Vector2.new(-reach, 0), anchor = Vector2.new(1, 0.5), size = size }
end

--[=[
	The side the words go for a ring at `centre`: `away` (the side of the character the ring sits on, so the words
	are not over the character) or, for a ring above it or in the middle, the layout's HINT_SIDE; the other side when
	that one would cross HINT_SIDE_RESERVE.
]=]
function SkillCheckRingViewModel.hintSide(layout: Layout, centre: Vector2, viewport: Vector2, away: number?): number
	local preferred = away or SkillCheckRingViewModel.HINT_SIDE[layout]
	local reserve = SkillCheckRingViewModel.HINT_SIDE_RESERVE[layout]
	local frame = SkillCheckRingViewModel.hintFrame(layout, preferred)
	local left = centre.X + frame.offset.X - frame.anchor.X * frame.size.X
	if left >= reserve and left + frame.size.X <= viewport.X - reserve then
		return preferred
	end
	return -preferred
end

--[=[
	The verdict flash's strength `elapsed` seconds after it came: 1 falling to 0 over FLASH_SECONDS (0 before it).
]=]
function SkillCheckRingViewModel.flash(elapsed: number): number
	if elapsed < 0 or elapsed >= SkillCheckRingViewModel.FLASH_SECONDS then
		return 0
	end
	return 1 - elapsed / SkillCheckRingViewModel.FLASH_SECONDS
end

--[=[
	Whether a ring arriving at `arriveAt` still shows at `now` (server clock).
]=]
function SkillCheckRingViewModel.shown(now: number, arriveAt: number): boolean
	return now <= arriveAt + SkillCheckRingViewModel.LINGER
end

--[=[
	Whether the "Line it up!" words show: only for the first `rings` rings of the session (`seen` counts this one).
]=]
function SkillCheckRingViewModel.hint(seen: number, rings: number): boolean
	return seen >= 1 and seen <= rings
end

return SkillCheckRingViewModel
