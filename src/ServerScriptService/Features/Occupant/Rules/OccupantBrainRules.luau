--!strict
--[=[
	OccupantBrainRules: Mr. Harlow's decisions (Cleanup Crew spec §4 "Mr. Harlow"; the behaviour set,
	docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-design.md), as pure functions over his Mind and
	what he senses this think:

	- patrol: walk the authored loop from his random start, in his random direction (or to the director's steer point,
	  OccupantDirectorRules), with work breaks at desks (OccupantWorkRules);
	- investigate: walk to the last noise heard, look around LOOK_SECONDS, sigh, patrol; a noise by the hiding spots
	  ends in a short suspicion stare at the nearest (OccupantStareRules);
	- chase: anyone within sightRange, inside the sightAngle cone, with a clear line of sight; a target he can
	  still see is kept over a nearer player; within CATCH_RANGE the intent is `attack` (the catch). Far down a clear
	  line (longRange, the narrow longAngle cone) he first stops and turns his head to look for a notice beat that
	  grows with the distance (OccupantMindUtils.noticeDelay), then chases; his target stays seen down that cone;
	- search: lost sight → run to where he last saw them, look around SEARCH_SECONDS, sigh, patrol; a hiding spot
	  right there gets a short hunch stare (he did not see where they went: OccupantStareRules, HUNCH_CHECK);
	- rest: the shift's break → walk to the rest point and ignore everyone and everything;
	- catch: stand CATCH_HOLD seconds, then walk on to his next route point, ignoring the caught player for
	  GRACE_SECONDS;
	- work: at a desk (OccupantWorkRules: typing, the ambush, the sit-in at the desk someone hides under);
	- stare: at a hiding spot he saw someone go into, or suspects (OccupantStareRules: still, then he looks or leaves).

	The truck's box (`zone`) is safe: nobody inside it is seen, no noise inside it is followed, so no goal is
	ever inside it (his kind's pathCosts also make it unwalkable). The loading bay around it (`bay`) is not: he
	patrols through it, chases, hears and catches there, but after BAY_LINGER_SECONDS in it with nobody in sight he
	walks out to the nearest route point outside it and keeps out (no bay noise, no bay route point) for
	BAY_COOLDOWN_SECONDS, so he never body-blocks the ramp. Investigate and search give up after GIVE_UP_SECONDS if he
	never gets there.

	A hidden player (Hide) is never chased: one he did not see go in is invisible to him; one he did (Senses.hiders,
	seen) is stared at. Each step also settles his body (`settleBody`: off the chair, released from a spot) and
	remembers what he saw and the menace gauge (OccupantDirectorRules.track); no move while he stands up or is
	startled. The service carries out each step's effects.

	The line-of-sight ray is the caller's (OccupantServiceServer): each Glimpse says whether it was clear.
	Pure: nothing here yields or touches an Instance; it never changes the mind it is given. Times are
	os.clock() seconds (the NPC brain's `now`).

	@class OccupantBrainRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantServer = ServerScriptService.Features.Occupant
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantDirectorRules = require(OccupantServer.Rules.OccupantDirectorRules)
local OccupantStareRules = require(OccupantServer.Rules.OccupantStareRules)
local OccupantWorkRules = require(OccupantServer.Rules.OccupantWorkRules)
local OccupantMenaceFormulas = require(OccupantServer.Utils.OccupantMenaceFormulas)
local M = require(OccupantServer.Utils.OccupantMindUtils)

type Mind = OccupantTypes.Mind
type Cue = OccupantTypes.Cue
type Senses = OccupantTypes.Senses
type Glimpse = OccupantTypes.Glimpse

export type Step = M.Step

local IDLE = M.IDLE

local OccupantBrainRules = {}

--[=[
	A fresh Harlow: patrolling toward route point `routeIndex`, walking the loop in `routeStep`'s direction. `roll`
	(0..1, default 0.5) times his first work break and first steer.
]=]
function OccupantBrainRules.newMind(routeIndex: number, routeStep: number, now: number, roll: number?): Mind
	local value = roll or 0.5
	return {
		mode = "patrol",
		since = now,
		routeIndex = routeIndex,
		routeStep = if routeStep < 0 then -1 else 1,
		grace = {},
		watched = {},
		entered = {},
		cleared = {},
		nextWorkAt = now + M.within(OccupantConstants.WORK_FIRST, value),
		nextSteerAt = now + M.within(OccupantConstants.STEER_FIRST, value),
		menace = 0,
		sitIns = 0,
	}
end

function OccupantBrainRules.inZone(point: Vector3, zone: OccupantTypes.Zone): boolean
	return M.inZone(point, zone)
end

--[=[
	The players he sees this think, nearest first (OccupantMindUtils.visible): never a hidden one.
]=]
function OccupantBrainRules.visible(mind: Mind, senses: Senses): { Glimpse }
	return M.visible(mind, senses)
end

--[=[
	Whether his root sits on a chair in this mind's phase (work: typing, the ambush, the head tipping down).
]=]
function OccupantBrainRules.seatedPhase(mind: Mind): boolean
	local phase = mind.phase
	return mind.mode == "work" and phase ~= nil and phase ~= "toDesk"
end

--[=[
	His body after a think: off the chair (a `stand` effect, faster into a chase or an investigation; no move for
	STAND_SECONDS / speed) or released from a spot, before anything moves him. Kept through a catch.
]=]
function OccupantBrainRules.settleBody(result: Step, now: number): Step
	local mind = result.mind
	local keepSeat = OccupantBrainRules.seatedPhase(mind) or mind.mode == "catch"
	local keepPlant = (mind.mode == "stare" and mind.phase ~= "approach") or mind.mode == "catch"
	if mind.seated == true and not keepSeat then
		local nextMind = table.clone(mind)
		nextMind.seated = false
		local hurried = mind.mode == "chase" or mind.mode == "investigate"
		local speed = if hurried then OccupantConstants.AMBUSH_STAND_SPEED else 1
		nextMind.standUntil = now + OccupantConstants.STAND_SECONDS / speed
		return M.addEffect(
			{ mind = nextMind, intent = IDLE, cue = result.cue, effects = result.effects },
			{ kind = "stand", speed = speed }
		)
	end
	if mind.planted == true and not keepPlant then
		local nextMind = table.clone(mind)
		nextMind.planted = false
		return M.addEffect(
			{ mind = nextMind, intent = result.intent, cue = result.cue, effects = result.effects },
			{ kind = "release" }
		)
	end
	return result
end

--[=[
	Whether he witnesses `userId` now (Hide asks as they go into a spot): he sees them right then, near or far down his
	long cone (a chase alone is not enough: break his line of sight first and he did not see where you went). Never on
	his break.
]=]
function OccupantBrainRules.witnessed(mind: Mind, senses: Senses, userId: number): boolean
	if senses.resting or mind.mode == "rest" then
		return false
	end
	return M.sees(mind, senses, userId)
end

--[=[
	The mind after he catches `userId`: standing over the catch (targeting them), that player in their grace. A catch
	made from a sit-in or a stare (`from`, the mind of the think that asked for it; default `mind`) keeps that, so the
	gesture holds through the jumpscare; the menace gauge jumps.
]=]
function OccupantBrainRules.caught(mind: Mind, userId: number, now: number, from: Mind?): Mind
	local nextMind = M.enter(mind, "catch", now)
	local grace = table.clone(mind.grace)
	grace[userId] = now + OccupantConstants.GRACE_SECONDS
	nextMind.grace = grace
	M.forget(nextMind)
	local origin = from or mind
	nextMind.sitIn = origin.sitIn
	nextMind.spot = origin.spot
	nextMind.menace = OccupantMenaceFormulas.bump(mind.menace, OccupantConstants.MENACE_CATCH)
	-- He stands over them: the client's heartbeat reads the target to stay quiet on the caught player's own screen.
	nextMind.target = userId
	return nextMind
end

--[=[
	How far (radians) to turn from his arrival heading while looking around, `seconds` in.
]=]
function OccupantBrainRules.lookYaw(seconds: number): number
	return math.rad(OccupantConstants.LOOK_SWEEP) * math.sin(seconds * OccupantConstants.LOOK_RATE)
end

-- Lingered in the bay with nobody in sight: out to the nearest route point outside it, and keep out a while.
local function leaveBay(mind: Mind, senses: Senses): Step
	local nextMind = M.enter(mind, "patrol", senses.now)
	M.forget(nextMind)
	nextMind.steer = nil
	nextMind.bayBarredUntil = senses.now + OccupantConstants.BAY_COOLDOWN_SECONDS
	local best: number? = nil
	for index, point in senses.route do
		if
			not M.inZone(point, senses.bay)
			and (best == nil or M.flat(senses.position, point) < M.flat(senses.position, senses.route[best]))
		then
			best = index
		end
	end
	if best == nil then
		return { mind = nextMind, intent = IDLE, cue = "giveUp" }
	end
	nextMind.routeIndex = best
	return { mind = nextMind, intent = { kind = "goTo", position = senses.route[best], run = false }, cue = "giveUp" }
end

-- Walking to the noise / last-seen point, looking around, giving up; a noise by the spots ends in a stare.
local function lookAround(current: Mind, senses: Senses): Step
	local now = senses.now
	local searching: boolean = current.mode == "search"
	local points = current.searchPoints
	local point = if searching and points ~= nil
		then points[current.searchIndex or 1]
		elseif searching then current.lastSeen
		else current.noise
	local hold = if searching then OccupantConstants.SEARCH_SECONDS else OccupantConstants.LOOK_SECONDS
	if point == nil or (not searching and now - current.since >= OccupantConstants.GIVE_UP_SECONDS) then
		return M.giveUp(current, senses)
	end
	local arrivedAt = current.arrivedAt
	if arrivedAt == nil then
		if M.flat(senses.position, point) <= OccupantConstants.REACHED_DISTANCE then
			-- A noise by the spots, or the place he lost his chase: a moment's stare at the nearest spot there.
			local firstProbe = searching and (current.searchIndex or 1) == 1
			local spot = if not searching or firstProbe then OccupantStareRules.suspect(current, senses, point) else nil
			if spot ~= nil then
				local step = M.beginStare(current, senses, spot, nil)
				step.mind.hunch = searching
				return step
			end
			local nextMind = table.clone(current)
			nextMind.arrivedAt = now
			return { mind = nextMind, intent = IDLE }
		end
		if searching then
			return { mind = current, intent = { kind = "goTo", position = point, run = true } }
		end
		return { mind = current, intent = { kind = "goTo", position = point, run = false } }
	end
	if now - arrivedAt >= hold then
		local index = (current.searchIndex or 1) + 1
		if searching and points ~= nil and index <= #points then
			local nextMind = table.clone(current)
			nextMind.searchIndex = index
			nextMind.arrivedAt = nil
			return { mind = nextMind, intent = { kind = "goTo", position = points[index], run = true } }
		end
		return M.giveUp(current, senses)
	end
	return { mind = current, intent = IDLE }
end

-- The modes in which he looks down his long cone (not at a desk, at a spot, on his break or over a catch).
local LOOKING_FAR: { [string]: boolean } = { patrol = true, investigate = true, search = true }

-- Seconds since the last think (the notice beat's clock), like the director's.
local function tick(mind: Mind, senses: Senses): number
	return math.clamp(senses.now - (mind.lastThink or senses.now), 0, 0.5)
end

-- Someone far down his long cone: count the beat up (a step that stops him, head turned to them) or, once it is long
-- enough for the distance, chase them. Nil when there is no one there (or he is busy).
local function notice(current: Mind, senses: Senses): Step?
	if not LOOKING_FAR[current.mode] then
		return nil
	end
	local glimpse = M.distant(current, senses)[1]
	if glimpse == nil then
		return nil
	end
	local carried = if current.noticeId == glimpse.userId then current.noticeSeconds or 0 else 0
	local seconds = carried + tick(current, senses)
	if seconds >= M.noticeDelay((glimpse.position - senses.position).Magnitude) then
		local step = M.chase(current, senses, glimpse, false)
		step.mind.noticeId = nil
		step.mind.noticeSeconds = nil
		return step
	end
	local nextMind = table.clone(current)
	nextMind.noticeId = glimpse.userId
	nextMind.noticeSeconds = seconds
	nextMind.point = glimpse.position
	nextMind.swivelUntil = senses.now + 0.3
	return { mind = nextMind, intent = IDLE }
end

-- Nobody far down his cone this think: a noticing in progress falls back (NOTICE_DECAY a second) and is dropped at 0.
local function fade(current: Mind, senses: Senses): Mind
	local seconds = current.noticeSeconds
	if seconds == nil then
		return current
	end
	local nextMind = table.clone(current)
	local left = seconds - tick(current, senses) * OccupantConstants.NOTICE_DECAY
	nextMind.noticeSeconds = if left > 0 then left else 0
	if left <= 0 then
		nextMind.noticeId = nil
	end
	return nextMind
end

local function think(mind: Mind, senses: Senses): Step
	local now = senses.now

	-- The shift's break overrides everything.
	if senses.resting then
		local nextMind = mind
		local cue: Cue? = nil
		if mind.mode ~= "rest" then
			nextMind = M.enter(mind, "rest", now)
			M.forget(nextMind)
			nextMind.steer = nil
			cue = "resting"
		end
		if M.flat(senses.position, senses.restPoint) <= OccupantConstants.REACHED_DISTANCE then
			return { mind = nextMind, intent = IDLE, cue = cue }
		end
		return { mind = nextMind, intent = { kind = "goTo", position = senses.restPoint, run = false }, cue = cue }
	end

	-- Standing over a catch, then walking away (toward his next route point); back from the break.
	local current = mind
	if mind.mode == "catch" then
		if now - mind.since < OccupantConstants.CATCH_HOLD then
			return { mind = mind, intent = IDLE }
		end
		current = M.enter(mind, "patrol", now)
		current.target = nil
		if #senses.route > 0 then
			current.routeIndex = M.wrap(mind.routeIndex + mind.routeStep, #senses.route)
		end
	elseif mind.mode == "rest" then
		current = M.enter(mind, "patrol", now)
	end

	local seen = M.visible(current, senses)
	local staring = current.mode == "stare"

	-- At a desk, or at a spot: their own thinks (nil = carry on below).
	if current.mode == "work" then
		local step = OccupantWorkRules.think(current, senses, seen)
		if step ~= nil then
			return step
		end
	elseif current.mode == "stare" then
		local step = OccupantStareRules.think(current, senses, seen)
		if step ~= nil then
			return step
		end
	end

	-- Sight beats everything else.
	if #seen > 0 then
		local pick = seen[1]
		for _, glimpse in seen do
			if glimpse.userId == current.target then
				pick = glimpse
			end
		end
		return M.chase(current, senses, pick, false)
	end

	-- Far down a clear line: a beat to notice (he stops, his head turned to them), then the chase.
	local noticing = notice(current, senses)
	if noticing ~= nil then
		return noticing
	end
	current = fade(current, senses)

	-- Someone he saw go into a hiding spot (or tracked there): the stare-down.
	local hider, hiderSpot = OccupantStareRules.known(current, senses)
	if hider ~= nil and hiderSpot ~= nil and not staring then
		return M.beginStare(current, senses, hiderSpot, hider.userId)
	end

	-- Lingered in the bay with nobody in sight: out, and keep out a while.
	local bayAt = current.bayAt
	if
		bayAt ~= nil
		and M.inZone(senses.position, senses.bay)
		and now - bayAt >= OccupantConstants.BAY_LINGER_SECONDS
	then
		return leaveBay(current, senses)
	end

	-- Lost them: search where he last saw them.
	if current.mode == "chase" then
		local nextMind = M.enter(current, "search", now)
		local lastSeen = nextMind.lastSeen
		if lastSeen == nil then
			return M.giveUp(nextMind, senses)
		end
		nextMind.searchPoints = M.searchPoints(lastSeen, senses)
		nextMind.searchIndex = 1
		return { mind = nextMind, intent = { kind = "goTo", position = lastSeen, run = true } }
	end

	-- Continuous noise cannot renew a lost-target search indefinitely.
	if current.mode == "search" and now - current.since >= OccupantConstants.SEARCH_MAX_SECONDS then
		return M.giveUp(current, senses)
	end

	-- A noise (outside the safe zone).
	local heard = M.audible(current, senses)
	if heard ~= nil and not staring then
		if current.mode == "search" then
			local nextMind = table.clone(current)
			nextMind.searchPoints = M.searchPoints(heard, senses)
			nextMind.searchIndex = 1
			nextMind.arrivedAt = nil
			return { mind = nextMind, intent = { kind = "goTo", position = heard, run = true } }
		end
		local nextMind = M.enter(current, "investigate", now)
		nextMind.noise = heard
		nextMind.steer = nil
		local cue: Cue? = if current.mode == "investigate" then nil else "curious"
		return { mind = nextMind, intent = { kind = "goTo", position = heard, run = false }, cue = cue }
	end

	if current.mode == "investigate" or current.mode == "search" then
		return lookAround(current, senses)
	end

	-- A stare or a desk walk that fell through (someone in sight was handled above): back to the route.
	if current.mode == "stare" or current.mode == "work" then
		return M.walkOn(current, senses, nil)
	end

	return OccupantDirectorRules.direct(current, senses)
		or OccupantWorkRules.due(current, senses)
		or M.patrol(current, senses, nil)
end

--[=[
	One think: the next mind, the NPC intent, a cue worth a speech bubble (or nil) and the effects for the service.
	Also keeps when he walked into the loading bay, what he has seen, the menace gauge and his body (standing up,
	startled: no move until then).
]=]
function OccupantBrainRules.step(mind: Mind, senses: Senses): Step
	local result =
		OccupantDirectorRules.track(mind, OccupantBrainRules.settleBody(think(mind, senses), senses.now), senses)
	local nextMind = result.mind
	nextMind.bayAt = if M.inZone(senses.position, senses.bay) then (nextMind.bayAt or senses.now) else nil
	local intent = result.intent
	local standUntil = nextMind.standUntil
	local reactUntil = nextMind.reactUntil
	if (standUntil ~= nil and senses.now < standUntil) or (reactUntil ~= nil and senses.now < reactUntil) then
		intent = IDLE
	end
	return { mind = nextMind, intent = intent, cue = result.cue, effects = result.effects }
end

return OccupantBrainRules
