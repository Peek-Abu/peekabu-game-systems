--!strict
--[=[
	ShiftCueUtils: which shift moments just happened, for the sounds and kicks (Cleanup Crew spec §7 table: quota
	met, tier up, overtime, clock out (a crew member's punch, the truck's countdown); the shift's start and end). Compares two snapshots of the `shift` world
	entry: the first snapshot a client sees (a late joiner's included) cues nothing, so nobody arrives to a burst
	of horns. Also the clock-out countdown's whole second and whether the overtime ticking layer plays. Pure.

	@class ShiftCueUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type ShiftSnapshot = ShiftTypes.ShiftSnapshot

export type Cue = "shiftStart" | "quotaMet" | "tierUp" | "warning" | "overtime" | "punch" | "clockOut" | "shiftEnd"

-- The performance review's jingle (ShiftAssets.JINGLE_SOUNDS).
export type Jingle = "met" | "overtime" | "missed"

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
	if #after.punched > #before.punched then
		table.insert(list, "punch")
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
	The volume scale of the countdown's tick at `second` left (ShiftCueUtils.countdown): only the last COUNTDOWN_TICKS
	seconds tick (30 s of ticks would drown the shift), the last COUNTDOWN_LOUD louder; nil for no tick.
]=]
function ShiftCueUtils.tickScale(second: number?): number?
	if second == nil or second <= 0 or second > ShiftConstants.COUNTDOWN_TICKS then
		return nil
	end
	return if second <= ShiftConstants.COUNTDOWN_LOUD then ShiftConstants.COUNTDOWN_LOUD_SCALE else 1
end

--[=[
	The results jingle to play as the performance review arrives (`after` shows it, `before` did not): "overtime" when
	the contract was met and the crew banked salvage in overtime (the overtime pay), "met" when it was met, "missed"
	otherwise. Nil on the first snapshot a client sees and while the review stays up.
]=]
function ShiftCueUtils.jingle(before: ShiftSnapshot?, after: ShiftSnapshot?): Jingle?
	if before == nil or after == nil or after.phase ~= "results" then
		return nil
	end
	local results = after.results
	if results == nil or (before.phase == "results" and before.results ~= nil) then
		return nil
	end
	if not results.quotaMet then
		return "missed"
	end
	for _, line in results.crew do
		if (line.overtimeSalvage or 0) > 0 then
			return "overtime"
		end
	end
	return "met"
end

--[=[
	Whether the overtime ticking layer plays (spec §7 "Overtime: … ticking music layer").
]=]
function ShiftCueUtils.ticking(snapshot: ShiftSnapshot?): boolean
	return snapshot ~= nil and snapshot.phase == "running" and snapshot.stage == "overtime"
end

return ShiftCueUtils
