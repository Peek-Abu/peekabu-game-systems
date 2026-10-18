--!strict
--[=[
	VacuumFeedbackFormulas: the vacuum's feel maths (Cleanup Crew spec §7 "Vacuuming", "Canister full"). The
	whine's pitch and volume rise with the pile's progress; a pile that vanished was cleared (pop + sparkle) only
	if it was vacuumed past POP_PROGRESS within POP_WINDOW seconds, judged on its peak progress because the
	Interaction system clears the progress attribute in the same frame it completes the pile; the canister ticks
	as it fills and chimes when its last pile pops a dust bag, never outside a running shift (a reset empties it);
	the vacuumer is the nearest hand within range. Pure.

	@class VacuumFeedbackFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

export type CanisterCue = "fill" | "full"

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
	The canister sound for a fill change: "fill" when it rose, "full" when its last pile popped a dust bag
	(capacity - 1 → 0), nil otherwise or outside a running shift.
]=]
function VacuumFeedbackFormulas.canisterCue(
	before: number,
	after: number,
	capacity: number,
	running: boolean
): CanisterCue?
	if not running then
		return nil
	end
	if after > before then
		return "fill"
	end
	if after == 0 and before == capacity - 1 then
		return "full"
	end
	return nil
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

return VacuumFeedbackFormulas
