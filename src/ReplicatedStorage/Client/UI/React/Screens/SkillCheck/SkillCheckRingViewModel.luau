--!strict
--[=[
	SkillCheckRingViewModel: the closing ring's layout and motion, in HUD design px (desktop 1920x1080, phone 844x390;
	PaperHudFrame scales them). The inner circle is a ring of beads whose opening beads glow mint (where to put the
	icon); the outer ring is a ring of Gloom-grape beads with the opening left out, closing straight in from
	`outerStart` to the inner circle over the ring's travel (`fraction`, on the server clock). The icon rides the inner
	circle at the player's angle (`place`). A verdict flashes for FLASH_SECONDS; the ring stays LINGER seconds past its
	arrival so the flash reads, then goes. The words show under the first rings only (`hint`). Pure.

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
	-- How far below the screen's middle the ring's centre sits (clear of the pile in front of the player).
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
		below = 110,
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
	-- Design px kept free at the bottom of the screen for the HUD's bottom-centre stack (hotbar, stamina bar, the
	-- prompt chip over them), and at each side (Roblox's buttons, the phone's thumbstick and action arc): the hint never
	-- goes there (2026-11-18: under the ring it sat on the hotbar).
	HINT_BOTTOM_RESERVE = table.freeze({ desktop = 220, phone = 130 }),
	HINT_SIDE_RESERVE = table.freeze({ desktop = 60, phone = 50 }),
	-- The side the hint prefers: right on desktop; left on a phone, whose action arc (HELPER, SPRINT) is right of the
	-- ring at its height.
	HINT_SIDE = table.freeze({ desktop = 1, phone = -1 }),
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
	The ring's centre in the HUD's area (`viewport`, design px): the middle line, a little below the middle, kept on
	screen for the outer ring's start.
]=]
function SkillCheckRingViewModel.centre(layout: Layout, viewport: Vector2): Vector2
	local metrics = METRICS[layout]
	local y = math.clamp(
		viewport.Y / 2 + metrics.below,
		metrics.outerStart,
		math.max(metrics.outerStart, viewport.Y - metrics.outerStart)
	)
	return Vector2.new(viewport.X / 2, y)
end

--[=[
	Where the "Line it up!" words sit: beside the ring at its centre's height, just past the outer ring's start, on the
	layout's HINT_SIDE (the ring is centred, so both sides have the same room; the spec checks every supported screen
	keeps it clear of HINT_SIDE_RESERVE). Never under the ring, where the HUD's bottom stack (the hotbar) is.
]=]
function SkillCheckRingViewModel.hintFrame(layout: Layout): HintFrame
	local metrics = METRICS[layout]
	local size = HINT_SIZE[layout]
	local reach = metrics.outerStart + metrics.bead + SkillCheckRingViewModel.HINT_GAP
	if SkillCheckRingViewModel.HINT_SIDE[layout] > 0 then
		return { offset = Vector2.new(reach, 0), anchor = Vector2.new(0, 0.5), size = size }
	end
	return { offset = Vector2.new(-reach, 0), anchor = Vector2.new(1, 0.5), size = size }
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
