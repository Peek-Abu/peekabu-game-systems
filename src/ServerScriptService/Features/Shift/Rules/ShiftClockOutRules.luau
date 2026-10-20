--!strict
--[=[
	ShiftClockOutRules: clocking out, one card per crew member (approved 2026-10-17; spec §3 step 6). Each crew member
	punches their own card at the truck's time clock and then waits in the truck's box. The crew still in the shift is
	the crew in the server minus whoever is out right now (caught: dead and spectating until they are rehired); leavers
	are already gone from the crew. Then:

	- everyone still in has punched (a solo punch included): the truck leaves at once;
	- half or more of them have punched: the truck leaves TRUCK_LEAVES_SECONDS later, for everyone; anyone still inside
	  then is paid like the rest (a kids' game: no penalty). A countdown, once started, never stops or moves later: it
	  only ends sooner, when the last ones inside punch, are caught or leave;
	- fewer than half: nothing yet.

	The punched cards ride the state (`punched`, cleared by every new run, since ShiftPhaseRules.follow builds a fresh
	state), with `crewIn`, the crew still in (the HUD's "2/4 CLOCKED OUT"). The countdown is the state's `sub`
	"clockout" and `clockOutAt`, which ShiftPhaseRules.tick ends the run at (`countdownOver`). The pacing stage is
	untouched: overtime still pays x1.5 until the truck leaves. Pure: every function returns the NEXT state, or nil when
	nothing changes.

	@class ShiftClockOutRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type ShiftState = ShiftTypes.ShiftState

-- What the punches so far mean: nothing yet, the truck's countdown, or the truck leaves now.
export type Verdict = "none" | "countdown" | "leave"

local ShiftClockOutRules = {}

--[=[
	The crew still in the shift: `crew` (the crew in the server) minus `out` (caught, spectating), sorted, each once.
]=]
function ShiftClockOutRules.stillIn(crew: { number }, out: { number }): { number }
	local ids: { number } = {}
	for _, userId in crew do
		if not table.find(out, userId) and not table.find(ids, userId) then
			table.insert(ids, userId)
		end
	end
	table.sort(ids)
	return ids
end

function ShiftClockOutRules.isPunched(state: ShiftState, userId: number): boolean
	local cards = state.punched
	return cards ~= nil and table.find(cards, userId) ~= nil
end

--[=[
	`userId` punched their card. Nil outside a running shift or when they already punched.
]=]
function ShiftClockOutRules.punch(state: ShiftState, userId: number): ShiftState?
	if state.phase ~= "running" or ShiftClockOutRules.isPunched(state, userId) then
		return nil
	end
	local cards = if state.punched ~= nil then table.clone(state.punched) else {}
	table.insert(cards, userId)
	table.sort(cards)
	local nextState = table.clone(state)
	nextState.punched = cards
	return nextState
end

--[=[
	How many of `stillIn` have punched, and how many `stillIn` are.
]=]
function ShiftClockOutRules.tally(state: ShiftState, stillIn: { number }): (number, number)
	local count = 0
	for _, userId in stillIn do
		if ShiftClockOutRules.isPunched(state, userId) then
			count += 1
		end
	end
	return count, #stillIn
end

--[=[
	What `count` punched cards out of `total` crew still in mean (nobody still in: nothing).
]=]
function ShiftClockOutRules.verdict(count: number, total: number): Verdict
	if total <= 0 then
		return "none"
	end
	if count >= total then
		return "leave"
	end
	if count > 0 and count * 2 >= total then
		return "countdown"
	end
	return "none"
end

--[=[
	Brings the state up to date with the crew still in at `now`: records `crewIn`, starts the truck's countdown at half,
	and leaves now once everyone still in has punched. Nil when nothing changed or the shift is not running.

	`waiting`: crew members who are down but will be back (caught with lives left: dead only until they are rehired,
	not knocked out). They never block the countdown's start by the half rule, but while one of them has not punched the
	"leave now" verdict is withheld: nothing happens (no end, no new countdown) until they return and punch or are
	knocked out. A knocked-out member is not waiting: they are out for the shift and are simply not in `stillIn`.
]=]
function ShiftClockOutRules.settle(
	state: ShiftState,
	stillIn: { number },
	now: number,
	waiting: { number }?
): ShiftState?
	if state.phase ~= "running" then
		return nil
	end
	local count, total = ShiftClockOutRules.tally(state, stillIn)
	local verdict = ShiftClockOutRules.verdict(count, total)
	-- Everyone still in was knocked out after a card was punched: that card clocks the crew out.
	if total == 0 and state.punched ~= nil and #state.punched > 0 then
		verdict = "leave"
	end
	if verdict == "leave" and waiting ~= nil then
		for _, userId in waiting do
			if not ShiftClockOutRules.isPunched(state, userId) then
				verdict = "none"
				break
			end
		end
	end
	local sub: ShiftTypes.ShiftSub = state.sub
	local clockOutAt = state.clockOutAt
	if verdict == "leave" then
		sub = "clockout"
		clockOutAt = if clockOutAt ~= nil then math.min(clockOutAt, now) else now
	elseif verdict == "countdown" and sub ~= "clockout" then
		sub = "clockout"
		clockOutAt = now + ShiftConstants.TRUCK_LEAVES_SECONDS
	end
	if sub == state.sub and clockOutAt == state.clockOutAt and total == state.crewIn then
		return nil
	end
	local nextState = table.clone(state)
	nextState.sub = sub
	nextState.clockOutAt = clockOutAt
	nextState.crewIn = total
	return nextState
end

--[=[
	Whether the truck's countdown has run out (the run ends).
]=]
function ShiftClockOutRules.countdownOver(state: ShiftState, now: number): boolean
	local at = state.clockOutAt
	return state.phase == "running" and state.sub == "clockout" and at ~= nil and now >= at
end

--[=[
	Whether `point` (a punched member's root) is inside the truck's box, `low` to `high` (OfficeServiceServer.safeZone).
]=]
function ShiftClockOutRules.aboard(point: Vector3, low: Vector3, high: Vector3): boolean
	return point.X >= low.X
		and point.X <= high.X
		and point.Y >= low.Y
		and point.Y <= high.Y
		and point.Z >= low.Z
		and point.Z <= high.Z
end

return ShiftClockOutRules
