--!strict
--[=[
	VacuumFeedbackFormulas: the vacuum's feel maths (Cleanup Crew spec §7 "Vacuuming", "Canister full"). The
	whine's pitch and volume rise with the pile's progress; a pile that vanished was cleared (pop + sparkle) only
	if it was vacuumed past POP_PROGRESS within POP_WINDOW seconds, judged on its peak progress because the
	Interaction system clears the progress attribute in the same frame it completes the pile; the canister ticks
	when the crew's Gloom rises, never outside a running shift; the vacuumer is the nearest hand within range; the
	backpack's gauge is a live Gloom gauge (docs/superpowers/specs/2026-10-16-cleanup-crew-gloom-gleam-economy-design.md
	§3.1): it eases toward the crew's Gloom removed as a share of the contract, full once it is met. Pure.

	@class VacuumFeedbackFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

local VacuumFeedbackFormulas = {}

--[=[
	The whine's PlaybackSpeed and volume factor at `progress` (clamped to 0..1).
]=]
function VacuumFeedbackFormulas.whine(progress: number): (number, number)
	local fraction = math.clamp(progress, 0, 1)
	local pitch = VacuumConstants.WHINE_PITCH_MIN
		+ (VacuumConstants.WHINE_PITCH_MAX - VacuumConstants.WHINE_PITCH_MIN) * fraction
	local volume = VacuumConstants.WHINE_VOLUME_MIN
		+ (VacuumConstants.WHINE_VOLUME_MAX - VacuumConstants.WHINE_VOLUME_MIN) * fraction
	return pitch, volume
end

--[=[
	Whether a pile that just disappeared was vacuumed away (true) or removed some other way.
]=]
function VacuumFeedbackFormulas.cleared(peakProgress: number, secondsSinceActive: number): boolean
	return peakProgress >= VacuumConstants.POP_PROGRESS and secondsSinceActive <= VacuumConstants.POP_WINDOW
end

--[=[
	Whether the canister ticks: the crew's Gloom rose from `before` to `after` during a running shift, and the last
	tick (at `lastTick`) was at least GLOOM_TICK_GAP seconds before `now`.
]=]
function VacuumFeedbackFormulas.gloomTick(
	before: number,
	after: number,
	running: boolean,
	now: number,
	lastTick: number
): boolean
	return running and after > before and now - lastTick >= VacuumConstants.GLOOM_TICK_GAP
end

--[=[
	The gauge's fill fraction: `gloom` removed of the `contract` (0 without a contract), full once it is met.
]=]
function VacuumFeedbackFormulas.gaugeTarget(gloom: number, contract: number): number
	if contract <= 0 then
		return 0
	end
	return math.clamp(gloom / contract, 0, 1)
end

--[=[
	The shown fraction eased from `shown` toward `target` over `deltaTime` at `rate` (1/s); snaps when close.
]=]
function VacuumFeedbackFormulas.gaugeStep(shown: number, target: number, deltaTime: number, rate: number): number
	local nextShown = target + (shown - target) * math.exp(-rate * deltaTime)
	if math.abs(nextShown - target) < 0.002 then
		return target
	end
	return nextShown
end

--[=[
	The dust insert's height for a gauge `fullHeight` tall at `fraction` (clamped), and how far its centre drops
	from the full insert's so its bottom stays put.
]=]
function VacuumFeedbackFormulas.gaugeFill(fullHeight: number, fraction: number): (number, number)
	local height = fullHeight * math.clamp(fraction, 0, 1)
	return height, (fullHeight - height) / 2
end

--[=[
	The index of the point nearest `origin` within `range`, or nil.
]=]
function VacuumFeedbackFormulas.nearest(origin: Vector3, positions: { Vector3 }, range: number): number?
	local best: number? = nil
	local bestDistance = math.huge
	for index, position in positions do
		local distance = (position - origin).Magnitude
		if distance <= range and distance < bestDistance then
			best = index
			bestDistance = distance
		end
	end
	return best
end

--[=[
	How hard a pile is being sucked (0..1) for its particles: from 0.45 at the start to 0.85 near clearing, plus 0.075
	per extra vacuumer; 0 with nobody on it.
]=]
function VacuumFeedbackFormulas.suctionStrength(progress: number, count: number): number
	if count <= 0 then
		return 0
	end
	local helpers = math.min(count, 3) - 1
	return math.clamp(0.45 + 0.4 * math.clamp(progress, 0, 1) + 0.075 * helpers, 0, 1)
end

--[=[
	Whether progress rising from `before` to `after` crossed a multiple of `step` (a pile puffs as it shrinks).
]=]
function VacuumFeedbackFormulas.pastStep(before: number, after: number, step: number): boolean
	if step <= 0 or after <= before then
		return false
	end
	return math.floor(after / step) > math.floor(before / step)
end

--[=[
	A pile's pop scale: its size over the size the pop is drawn for, within `low`..`high`.
]=]
function VacuumFeedbackFormulas.popScale(size: number, reference: number, low: number, high: number): number
	if reference <= 0 then
		return 1
	end
	return math.clamp(size / reference, low, high)
end

return VacuumFeedbackFormulas
