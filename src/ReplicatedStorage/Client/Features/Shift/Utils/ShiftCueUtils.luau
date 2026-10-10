--!strict
--[=[
	ShiftCueUtils: which shift moments just happened, for the sounds and kicks (Cleanup Crew spec §7 table: quota
	met, tier up, overtime, clock out; the shift's start and end). Compares two snapshots of the `shift` world
	entry: the first snapshot a client sees (a late joiner's included) cues nothing, so nobody arrives to a burst
	of horns. Also the clock-out countdown's whole second and whether the overtime ticking layer plays. Pure.

	@class ShiftCueUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type ShiftSnapshot = ShiftTypes.ShiftSnapshot

export type Cue = "shiftStart" | "quotaMet" | "tierUp" | "warning" | "overtime" | "clockOut" | "shiftEnd"

local ShiftCueUtils = {}

--[=[
	The moments between `before` and `after`, in the order they happen. None when either is nil.
]=]
function ShiftCueUtils.cues(before: ShiftSnapshot?, after: ShiftSnapshot?): { Cue }
	local list: { Cue } = {}
	if before == nil or after == nil then
		return list
	end
	local wasRunning = before.phase == "running"
	local isRunning = after.phase == "running"
	if isRunning and not wasRunning then
		table.insert(list, "shiftStart")
		return list
	end
	if wasRunning and not isRunning then
		table.insert(list, "shiftEnd")
		return list
	end
	if not isRunning then
		return list
	end
	if after.quotaMet and not before.quotaMet then
		table.insert(list, "quotaMet")
	end
	if after.stage == "warning" and before.stage ~= "warning" then
		table.insert(list, "warning")
	end
	if after.stage == "overtime" and before.stage ~= "overtime" then
		table.insert(list, "overtime")
	elseif after.tier > before.tier then
		table.insert(list, "tierUp")
	end
	if after.sub == "clockout" and before.sub ~= "clockout" then
		table.insert(list, "clockOut")
	end
	return list
end

--[=[
	Whole seconds left on a running clock-out countdown (rounded up, never negative); nil without one.
]=]
function ShiftCueUtils.countdown(snapshot: ShiftSnapshot?, now: number): number?
	if snapshot == nil or snapshot.phase ~= "running" or snapshot.sub ~= "clockout" then
		return nil
	end
	local at = snapshot.clockOutAt
	if at == nil then
		return nil
	end
	return math.max(0, math.ceil(at - now))
end

--[=[
	Whether the overtime ticking layer plays (spec §7 "Overtime: … ticking music layer").
]=]
function ShiftCueUtils.ticking(snapshot: ShiftSnapshot?): boolean
	return snapshot ~= nil and snapshot.phase == "running" and snapshot.stage == "overtime"
end

return ShiftCueUtils
