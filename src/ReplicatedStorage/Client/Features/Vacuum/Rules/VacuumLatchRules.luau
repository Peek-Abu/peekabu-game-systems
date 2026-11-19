--!strict
--[=[
	VacuumLatchRules: click once to clean (owner pick I1, 2026-11-19: holding the click while the mouse steers the
	skill check ring "is kind of weird"). With the latch on (VacuumConstants.LATCH), one press starts the vacuum and it
	stays on, with the button let go, until its pile is clean, the player walks out of reach (or starts carrying, or puts
	the vacuum away), or they press again. A fresh press gets LATCH_GRACE seconds to find a pile before it gives up, so
	a press on nothing does nothing. With the latch off it is the old hold-to-vacuum. Pure.

	- `press(latch, on)`: what a press does: "begin" (start) or "end" (a latched vacuum's second press).
	- `release(latch)`: whether letting go of the button stops the vacuum (only in hold mode).
	- `allows(latch, locked, target)`: whether the vacuum may clean `target`: a latch stays on the pile it started on
	  (`locked`, nil until it finds one), so a clean pile ends it rather than moving on to the next one in reach.
	- `keepWithoutTarget(latch, hadTarget, elapsed, grace)`: whether the vacuum stays on while nothing is in reach (after
	  the aim's one-beat grace): always in hold mode; latched, only a fresh press still inside its grace.

	@class VacuumLatchRules
]=]

local VacuumLatchRules = {}

function VacuumLatchRules.press(latch: boolean, on: boolean): "begin" | "end"
	return if latch and on then "end" else "begin"
end

function VacuumLatchRules.release(latch: boolean): boolean
	return not latch
end

function VacuumLatchRules.allows(latch: boolean, locked: unknown?, target: unknown): boolean
	return not latch or locked == nil or locked == target
end

function VacuumLatchRules.keepWithoutTarget(latch: boolean, hadTarget: boolean, elapsed: number, grace: number): boolean
	if not latch then
		return true
	end
	return not hadTarget and elapsed < grace
end

return VacuumLatchRules
