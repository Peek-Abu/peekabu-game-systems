--!strict
--[=[
	TrailEasingUtils: the pure step function behind `useEasedTrail` — one frame of exponential easing toward
	a target, with separate rates for moving up vs down.

	A bar's fill and its trail are BOTH this same easing, at different rates. Health drains its fill
	smoothly while the trail lags behind (slow down-rate) → a dark "lost" chunk. XP tweens its fill up
	slowly while the trail (a lead) races ahead (fast up-rate) → a bright "gaining" chunk. Same maths,
	swapped rates — so it lives here once, tested, and both HUD widgets configure it.

	Pure (no React, no RunService) so the easing is unit-testable; the React/Heartbeat glue is the exempt
	`useEasedTrail` hook.

	@class TrailEasingUtils
]=]

local TrailEasingUtils = {}

-- Within this fraction of the target, snap exactly onto it (kills the asymptotic tail of the ease).
local EPSILON = 0.001

--[=[
	Advances `current` toward `target` by one frame. The rate is picked by direction — `upRate` when the
	target is above (or equal to) the current value, `downRate` when below — so a bar can, say, drain
	slowly but fill quickly. The step is `(target - current) * clamp(dt * rate, 0, 1)`, an exponential
	ease that never overshoots; within `EPSILON` of the target it snaps exactly on.

	@param current number -- the current eased value (0..1)
	@param target number -- the value being approached (0..1)
	@param upRate number -- easing rate when moving up toward the target (per second; higher = faster)
	@param downRate number -- easing rate when moving down toward the target
	@param deltaTime number -- seconds since the last step
	@return number -- the value after one step
]=]
function TrailEasingUtils.approach(
	current: number,
	target: number,
	upRate: number,
	downRate: number,
	deltaTime: number
): number
	if current == target then
		return target
	end
	local rate = if target >= current then upRate else downRate
	local factor = math.clamp(deltaTime * rate, 0, 1)
	local eased = current + (target - current) * factor
	if math.abs(eased - target) < EPSILON then
		return target
	end
	return eased
end

return TrailEasingUtils
