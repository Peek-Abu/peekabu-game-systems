--!strict
--[=[
	OccupantTurnRules: the Manager's slow head turns, the rare variants of the head turn (docs/superpowers/specs/
	2026-10-15-cleanup-crew-manager-behaviours-design.md §11):

	- `pick`: which turn a head turn is. The snap (the common case) unless he is `certain` of the turn's player (not
	  hidden, a clear line, within CERTAIN_RANGE or seen CERTAIN_WATCHED a moment ago), off a breather, the last turn a
	  snap and SLOW_GAP since the last slow one: then the staring contest (once a shift for the crew, menace within
	  STARE_MENACE, roll 5 under STARE_CHANCE), else the knowing turn (once a shift per player, menace up to
	  KNOWING_MENACE_MAX, roll 6 under KNOWING_CHANCE). A developer's forced variant (`Mind.forceTurn`) beats it all.
	- `begin`: the slow turn (phase `slowTurn`, standing in `alert` or seated in `work`): stopped dead, his head turning
	  to them over SLOW_TURN_SECONDS, booked for the shift.
	- `think`: while he turns, their `moved`ing (after SLOW_SETTLE) is the jerk at once; the full turn ends in the jerk
	  (knowing) or the stare (phase `staring`, STARE_CONTEST_SECONDS), where the target or anyone he sees down his
	  head's cone moving is the jerk at them, and the stare running out is the jerk anyway. Hidden or out of his line,
	  the target is searched for.
	- The jerk: straight into the chase (mode `chase`, phase `jerk`, his head held on them for JERK_SECONDS, plus the
	  fast stand-up from a chair); `settle` ends the phase.

	Pure (see OccupantMindUtils).

	@class OccupantTurnRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local M = require(ServerScriptService.Features.Occupant.Utils.OccupantMindUtils)

type Mind = OccupantTypes.Mind
type Senses = OccupantTypes.Senses
type Glimpse = OccupantTypes.Glimpse
type TurnKind = OccupantTypes.TurnKind
type Step = M.Step

local IDLE = M.IDLE

-- The phases a slow turn watches in.
local WATCHING: { [string]: boolean } = { slowTurn = true, staring = true }

local OccupantTurnRules = {}

-- Seeable at all: a clear line, not hiding, not in their grace, not in the truck's box.
local function eligible(mind: Mind, senses: Senses, glimpse: Glimpse): boolean
	return glimpse.clear
		and glimpse.hidden ~= true
		and not M.graced(mind, glimpse.userId, senses.now)
		and not M.inZone(glimpse.position, senses.zone)
end

local function find(senses: Senses, userId: number?): Glimpse?
	for _, glimpse in senses.players do
		if glimpse.userId == userId then
			return glimpse
		end
	end
	return nil
end

--[=[
	Whether he is certain of `glimpse` (a slow turn's target): seeable, and within CERTAIN_RANGE flat studs or seen at
	least CERTAIN_WATCHED seconds a moment ago.
]=]
function OccupantTurnRules.certain(mind: Mind, senses: Senses, glimpse: Glimpse): boolean
	if not eligible(mind, senses, glimpse) then
		return false
	end
	return M.flat(senses.position, glimpse.position) <= OccupantConstants.CERTAIN_RANGE
		or (mind.watched[glimpse.userId] or 0) >= OccupantConstants.CERTAIN_WATCHED
end

--[=[
	A head turn's player: `target` (the glance's, the ambush's) when seeable, else the nearest he sees down the cone
	toward `point` (a noise). Nil when there is none.
]=]
function OccupantTurnRules.candidate(mind: Mind, senses: Senses, point: Vector3, target: number?): Glimpse?
	if target ~= nil then
		local glimpse = find(senses, target)
		return if glimpse ~= nil and eligible(mind, senses, glimpse) then glimpse else nil
	end
	return M.toward(mind, senses, point)[1]
end

--[=[
	Which turn a head turn at `who` (nil: nobody to turn to) is: "snap", "knowing" or "stare" (§11.1).
]=]
function OccupantTurnRules.pick(mind: Mind, senses: Senses, who: Glimpse?): TurnKind
	if who == nil then
		return "snap"
	end
	local forced: TurnKind? = mind.forceTurn
	if forced ~= nil then
		return forced
	end
	local now = senses.now
	local slowAt = mind.slowAt
	if
		not OccupantTurnRules.certain(mind, senses, who)
		or M.breathing(mind, now)
		or mind.lastTurn == "knowing"
		or mind.lastTurn == "stare"
		or (slowAt ~= nil and now - slowAt < OccupantConstants.SLOW_GAP)
	then
		return "snap"
	end
	local menace = mind.menace
	local band = OccupantConstants.STARE_MENACE
	if
		mind.stared ~= true
		and menace >= band.min
		and menace <= band.max
		and M.roll(senses, 5) < OccupantConstants.STARE_CHANCE
	then
		return "stare"
	end
	local had = mind.knowingFor
	if
		(had == nil or had[who.userId] ~= true)
		and menace <= OccupantConstants.KNOWING_MENACE_MAX
		and M.roll(senses, 6) < OccupantConstants.KNOWING_CHANCE
	then
		return "knowing"
	end
	return "snap"
end

--[=[
	Whether `kind` is a slow turn (the knowing turn or the staring contest), not the snap.
]=]
function OccupantTurnRules.slow(kind: TurnKind): boolean
	return kind ~= "snap"
end

--[=[
	Whether `mind` is in a slow turn or a stare (watching for movement).
]=]
function OccupantTurnRules.turning(mind: Mind): boolean
	local phase = mind.phase
	return phase ~= nil and WATCHING[phase] == true and (mind.mode == "alert" or mind.mode == "work")
end

--[=[
	Whether `glimpse` moved meaningfully from `anchor` (where they stood): a flat speed of STILL_SPEED or more, or a
	drift of STILL_DISTANCE (3D). Never a camera turn.
]=]
function OccupantTurnRules.moved(glimpse: Glimpse, anchor: Vector3?): boolean
	if (glimpse.speed or 0) >= OccupantConstants.STILL_SPEED then
		return true
	end
	return anchor ~= nil and (glimpse.position - anchor).Magnitude >= OccupantConstants.STILL_DISTANCE
end

--[=[
	The slow turn (`kind`: knowing or stare) at `who`: stopped dead (`seated`: still in his chair, in `work`), his head
	turning to them; the variant booked for the shift.
]=]
function OccupantTurnRules.begin(current: Mind, senses: Senses, who: Glimpse, kind: TurnKind, seated: boolean): Step
	local now = senses.now
	local nextMind: Mind
	if seated then
		nextMind = M.inPhase(current, "slowTurn", now, OccupantConstants.SLOW_TURN_SECONDS)
	else
		nextMind = M.enter(current, "alert", now)
		M.forget(nextMind)
		nextMind.steer = nil
		nextMind.phase = "slowTurn"
		nextMind.phaseAt = now
		nextMind.hold = OccupantConstants.SLOW_TURN_SECONDS
	end
	nextMind.turn = kind
	nextMind.target = who.userId
	nextMind.point = who.position
	nextMind.swivelUntil = math.huge
	nextMind.anchors = { [who.userId] = who.position }
	nextMind.lastTurn = kind
	nextMind.slowAt = now
	nextMind.forceTurn = nil
	if kind == "stare" then
		nextMind.stared = true
	else
		local had = if current.knowingFor ~= nil then table.clone(current.knowingFor) else {}
		had[who.userId] = true
		nextMind.knowingFor = had
	end
	nextMind.glanceId = nil
	nextMind.glanceSeconds = nil
	nextMind.noticeId = nil
	nextMind.noticeSeconds = nil
	return { mind = nextMind, intent = IDLE }
end

-- The jerk: straight into the chase of `glimpse`, his head held on them while his body snaps round (and, from a
-- chair, while he pops up).
local function jerk(current: Mind, senses: Senses, glimpse: Glimpse): Step
	local now = senses.now
	local step = M.chase(current, senses, glimpse, false)
	local nextMind = step.mind
	nextMind.phase = "jerk"
	nextMind.phaseAt = now
	nextMind.point = glimpse.position
	local rising = if current.seated == true
		then OccupantConstants.STAND_SECONDS / OccupantConstants.JERK_STAND_SPEED
		else 0
	nextMind.swivelUntil = now + OccupantConstants.JERK_SECONDS + rising
	return step
end

-- They hid or broke the line: he runs to search where they were.
local function lost(current: Mind, senses: Senses): Step
	local nextMind = M.enter(current, "search", senses.now)
	local point = current.point or senses.position
	nextMind.target = current.target
	nextMind.lastSeen = point
	nextMind.noise = nil
	nextMind.searchPoints = M.searchPoints(point, senses)
	nextMind.searchIndex = 1
	return { mind = nextMind, intent = { kind = "goTo", position = point, run = true } }
end

--[=[
	One think in a slow turn or a stare. Nil when someone is in his body's front cone (the brain's sight chases them).
]=]
function OccupantTurnRules.think(current: Mind, senses: Senses, seen: { Glimpse }): Step?
	if #seen > 0 then
		return nil
	end
	local now = senses.now
	local target = current.target
	local glimpse = find(senses, target)
	if target == nil or glimpse == nil or not eligible(current, senses, glimpse) then
		return lost(current, senses)
	end
	local anchors: { [number]: Vector3 } = if current.anchors ~= nil then table.clone(current.anchors) else {}
	local elapsed = M.elapsed(current, now)
	local nextMind = table.clone(current)
	nextMind.point = glimpse.position
	nextMind.anchors = anchors
	if current.phase == "slowTurn" then
		if elapsed < OccupantConstants.SLOW_SETTLE then
			-- Time to freeze at the creak: where they stand follows them.
			anchors[target] = glimpse.position
			return { mind = nextMind, intent = IDLE }
		end
		if OccupantTurnRules.moved(glimpse, anchors[target]) then
			return jerk(current, senses, glimpse)
		end
		if elapsed < (current.hold or OccupantConstants.SLOW_TURN_SECONDS) then
			return { mind = nextMind, intent = IDLE }
		end
		if current.turn ~= "stare" then
			return jerk(current, senses, glimpse)
		end
		local staring =
			M.inPhase(nextMind, "staring", now, M.within(OccupantConstants.STARE_CONTEST_SECONDS, M.roll(senses, 4)))
		return { mind = staring, intent = IDLE }
	end
	-- The stare: the target, or anyone he sees down his head's cone, moving is the jerk at them.
	if OccupantTurnRules.moved(glimpse, anchors[target]) then
		return jerk(current, senses, glimpse)
	end
	for _, other in M.toward(current, senses, glimpse.position) do
		local anchor: Vector3? = anchors[other.userId]
		if other.userId ~= target then
			if anchor ~= nil and OccupantTurnRules.moved(other, anchor) then
				return jerk(current, senses, other)
			elseif anchor == nil then
				if (other.speed or 0) >= OccupantConstants.STILL_SPEED then
					return jerk(current, senses, other)
				end
				anchors[other.userId] = other.position
			end
		end
	end
	if elapsed >= (current.hold or 0) then
		return jerk(current, senses, glimpse)
	end
	return { mind = nextMind, intent = IDLE }
end

--[=[
	`mind` with the jerk's phase over (an ordinary chase) once his head is no longer held on them.
]=]
function OccupantTurnRules.settle(mind: Mind, now: number): Mind
	if mind.mode ~= "chase" or mind.phase ~= "jerk" then
		return mind
	end
	local untilTime = mind.swivelUntil or ((mind.phaseAt or now) + OccupantConstants.JERK_SECONDS)
	if now < untilTime then
		return mind
	end
	local nextMind = table.clone(mind)
	nextMind.phase = nil
	nextMind.phaseAt = nil
	return nextMind
end

--[=[
	The heading (radians about up, as CFrame.Angles(0, yaw, 0)) that faces a flat `direction`.
]=]
function OccupantTurnRules.yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

--[=[
	His body's heading `elapsed` seconds into the jerk, from heading `from` to `to` the short way round, eased out over
	JERK_SECONDS; and whether it is done.
]=]
function OccupantTurnRules.jerkYaw(from: number, to: number, elapsed: number): (number, boolean)
	local t = math.clamp(elapsed / OccupantConstants.JERK_SECONDS, 0, 1)
	local delta = (to - from + math.pi) % (2 * math.pi) - math.pi
	return from + delta * (1 - (1 - t) * (1 - t)), t >= 1
end

return OccupantTurnRules
