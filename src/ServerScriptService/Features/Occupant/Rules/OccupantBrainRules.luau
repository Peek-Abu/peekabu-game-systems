--!strict
--[=[
	OccupantBrainRules: Mr. Harlow's decisions (Cleanup Crew spec §4 "Mr. Harlow"), as pure functions over his
	Mind and what he senses this think:

	- patrol: walk the authored loop from his random start, in his random direction;
	- investigate: walk to the last noise heard, look around LOOK_SECONDS, sigh, patrol;
	- chase: anyone within sightRange, inside the sightAngle cone, with a clear line of sight; a target he can
	  still see is kept over a nearer player; within CATCH_RANGE the intent is `attack` (the catch);
	- search: lost sight → run to where he last saw them, look around SEARCH_SECONDS, sigh, patrol;
	- rest: the shift's break → walk to the rest point and ignore everyone and everything;
	- catch: stand CATCH_HOLD seconds, then walk on to his next route point, ignoring the caught player for
	  GRACE_SECONDS.

	The truck's box (`zone`) is safe: nobody inside it is seen, no noise inside it is followed, so no goal is
	ever inside it (his kind's pathCosts also make it unwalkable). The loading bay around it (`bay`) is not: he
	patrols through it, chases, hears and catches there, but after BAY_LINGER_SECONDS in it with nobody in sight he
	walks out to the nearest route point outside it and keeps out (no bay noise, no bay route point) for
	BAY_COOLDOWN_SECONDS, so he never body-blocks the ramp. Investigate and search give up after GIVE_UP_SECONDS if he
	never gets there.

	A hidden player (Hide) he did not see go in is invisible to him; one he saw go in he sees wherever they are, even
	through the furniture (the hook for the hiding-spot behaviours to come).

	The line-of-sight ray is the caller's (OccupantServiceServer): each Glimpse says whether it was clear.
	Pure: nothing here yields or touches an Instance; it never changes the mind it is given. Times are
	os.clock() seconds (the NPC brain's `now`).

	@class OccupantBrainRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local NpcTypes = require(ServerScriptService.Features.Npc.Data.NpcTypes)
local NpcSenseRules = require(ServerScriptService.Features.Npc.Rules.NpcSenseRules)

type Mind = OccupantTypes.Mind
type Mode = OccupantTypes.Mode
type Cue = OccupantTypes.Cue
type Senses = OccupantTypes.Senses
type Glimpse = OccupantTypes.Glimpse

export type Step = {
	mind: Mind,
	intent: NpcTypes.Intent,
	cue: Cue?,
}

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- 1..count, wrapping both ways (Luau's % is floored, so -1 % 3 == 2).
local function wrap(index: number, count: number): number
	return (index - 1) % count + 1
end

-- A copy of `mind` in `mode`, begun `now`, not yet arrived anywhere.
local function enter(mind: Mind, mode: Mode, now: number): Mind
	local nextMind = table.clone(mind)
	nextMind.mode = mode
	nextMind.since = now
	nextMind.arrivedAt = nil
	return nextMind
end

local function forget(mind: Mind)
	mind.target = nil
	mind.lastSeen = nil
	mind.noise = nil
	mind.searchPoints = nil
	mind.searchIndex = nil
end

local function inBox(point: Vector3, zone: OccupantTypes.Zone?): boolean
	return zone ~= nil
		and point.X >= zone.min.X
		and point.X <= zone.max.X
		and point.Y >= zone.min.Y
		and point.Y <= zone.max.Y
		and point.Z >= zone.min.Z
		and point.Z <= zone.max.Z
end

-- Keeping out of the bay after lingering there.
local function barred(mind: Mind, senses: Senses): boolean
	local untilTime = mind.bayBarredUntil
	return untilTime ~= nil and senses.now < untilTime
end

-- Walks the route: on reaching the current point, heads for the next one in his direction (past a bay point while he
-- keeps out of the bay).
local function patrol(mind: Mind, senses: Senses, cue: Cue?): Step
	local route = senses.route
	if #route == 0 then
		return { mind = mind, intent = { kind = "idle" }, cue = cue }
	end
	local index = wrap(mind.routeIndex, #route)
	if flatDistance(senses.position, route[index]) <= OccupantConstants.REACHED_DISTANCE then
		index = wrap(index + mind.routeStep, #route)
	end
	if barred(mind, senses) then
		for _ = 1, #route do
			if not inBox(route[index], senses.bay) then
				break
			end
			index = wrap(index + mind.routeStep, #route)
		end
	end
	local nextMind = mind
	if index ~= mind.routeIndex then
		nextMind = table.clone(mind)
		nextMind.routeIndex = index
	end
	return { mind = nextMind, intent = { kind = "goTo", position = route[index], run = false }, cue = cue }
end

local function giveUp(mind: Mind, senses: Senses): Step
	local nextMind = enter(mind, "patrol", senses.now)
	forget(nextMind)
	return patrol(nextMind, senses, "giveUp")
end

local Reach = require(script.Parent.OccupantReachRules)
local OccupantBrainRules = {}

--[=[
	A fresh Harlow: patrolling toward route point `routeIndex`, walking the loop in `routeStep`'s direction.
]=]
function OccupantBrainRules.newMind(routeIndex: number, routeStep: number, now: number): Mind
	return {
		mode = "patrol",
		since = now,
		routeIndex = routeIndex,
		routeStep = if routeStep < 0 then -1 else 1,
		grace = {},
	}
end

function OccupantBrainRules.inZone(point: Vector3, zone: OccupantTypes.Zone): boolean
	return point.X >= zone.min.X
		and point.X <= zone.max.X
		and point.Y >= zone.min.Y
		and point.Y <= zone.max.Y
		and point.Z >= zone.min.Z
		and point.Z <= zone.max.Z
end

--[=[
	The players he sees this think, nearest first: a clear ray, in range and cone, outside the safe zone, not in
	their grace. A hidden player only if he saw them go in (then clear and all round, wherever they are).
]=]
function OccupantBrainRules.visible(mind: Mind, senses: Senses): { Glimpse }
	local list: { Glimpse } = {}
	for _, glimpse in senses.players do
		local graceUntil = mind.grace[glimpse.userId]
		local graced = graceUntil ~= nil and senses.now < graceUntil
		local known = glimpse.hidden == true and glimpse.seen == true
		if
			(glimpse.clear or known)
			and (glimpse.hidden ~= true or known)
			and not graced
			and (glimpse.position - senses.position).Magnitude <= senses.sightRange
			and not OccupantBrainRules.inZone(glimpse.position, senses.zone)
			and NpcSenseRules.inSight(
				senses.position,
				senses.look,
				Vector3.new(glimpse.position.X, senses.position.Y, glimpse.position.Z),
				senses.sightRange,
				if known or (glimpse.userId == mind.target and (mind.mode == "chase" or mind.mode == "search"))
					then 360
					else senses.sightAngle
			)
		then
			table.insert(list, glimpse)
		end
	end
	table.sort(list, function(a, b)
		local distanceA = (a.position - senses.position).Magnitude
		local distanceB = (b.position - senses.position).Magnitude
		if distanceA ~= distanceB then
			return distanceA < distanceB
		end
		return a.userId < b.userId
	end)
	return list
end

--[=[
	Whether he witnesses `userId` now (Hide asks as they go into a spot): he is chasing them, or sees them this think.
	Never on his break.
]=]
function OccupantBrainRules.witnessed(mind: Mind, senses: Senses, userId: number): boolean
	if senses.resting or mind.mode == "rest" then
		return false
	end
	if mind.mode == "chase" and mind.target == userId then
		return true
	end
	for _, glimpse in OccupantBrainRules.visible(mind, senses) do
		if glimpse.userId == userId then
			return true
		end
	end
	return false
end

--[=[
	The mind after he catches `userId`: standing over the catch (targeting them), that player in their grace.
]=]
function OccupantBrainRules.caught(mind: Mind, userId: number, now: number): Mind
	local nextMind = enter(mind, "catch", now)
	local grace = table.clone(mind.grace)
	grace[userId] = now + OccupantConstants.GRACE_SECONDS
	nextMind.grace = grace
	forget(nextMind)
	-- He stands over them: the client's heartbeat reads the target to stay quiet on the caught player's own screen.
	nextMind.target = userId
	return nextMind
end

--[=[
	How far (radians) to turn from his arrival heading while looking around, `elapsed` seconds in.
]=]
function OccupantBrainRules.lookYaw(elapsed: number): number
	return math.rad(OccupantConstants.LOOK_SWEEP) * math.sin(elapsed * OccupantConstants.LOOK_RATE)
end

-- Last-seen first, then at most two nearby authored route points. No hidden player sampling.
local function searchPoints(point: Vector3, senses: Senses): { Vector3 }
	local candidates: { Vector3 } = {}
	for _, candidate in senses.route do
		local distance = flatDistance(point, candidate)
		if
			distance > OccupantConstants.REACHED_DISTANCE
			and distance <= OccupantConstants.SEARCH_RADIUS
			and not OccupantBrainRules.inZone(candidate, senses.zone)
		then
			table.insert(candidates, candidate)
		end
	end
	table.sort(candidates, function(a, b)
		local da, db = flatDistance(point, a), flatDistance(point, b)
		if da ~= db then
			return da < db
		end
		if a.X ~= b.X then
			return a.X < b.X
		end
		return a.Z < b.Z
	end)
	local points = { point }
	for _, candidate in candidates do
		local duplicate = false
		for _, existing in points do
			if flatDistance(existing, candidate) <= OccupantConstants.REACHED_DISTANCE then
				duplicate = true
			end
		end
		if not duplicate then
			table.insert(points, candidate)
		end
		if #points >= OccupantConstants.SEARCH_PROBES + 1 then
			break
		end
	end
	return points
end

-- Lingered in the bay with nobody in sight: out to the nearest route point outside it, and keep out a while.
local function leaveBay(mind: Mind, senses: Senses): Step
	local nextMind = enter(mind, "patrol", senses.now)
	forget(nextMind)
	nextMind.bayBarredUntil = senses.now + OccupantConstants.BAY_COOLDOWN_SECONDS
	local best: number? = nil
	for index, point in senses.route do
		if
			not inBox(point, senses.bay)
			and (
				best == nil
				or flatDistance(senses.position, point) < flatDistance(senses.position, senses.route[best])
			)
		then
			best = index
		end
	end
	if best == nil then
		return { mind = nextMind, intent = { kind = "idle" }, cue = "giveUp" }
	end
	nextMind.routeIndex = best
	return { mind = nextMind, intent = { kind = "goTo", position = senses.route[best], run = false }, cue = "giveUp" }
end

local think: (mind: Mind, senses: Senses) -> Step

--[=[
	One think: the next mind, the NPC intent, and a cue worth a speech bubble (or nil). Also keeps when he walked into
	the loading bay.
]=]
function OccupantBrainRules.step(mind: Mind, senses: Senses): Step
	local result = think(mind, senses)
	local here = inBox(senses.position, senses.bay)
	local bayAt = if here then (result.mind.bayAt or senses.now) else nil
	if result.mind.bayAt ~= bayAt then
		local nextMind = table.clone(result.mind)
		nextMind.bayAt = bayAt
		return { mind = nextMind, intent = result.intent, cue = result.cue }
	end
	return result
end

think = function(mind: Mind, senses: Senses): Step
	local now = senses.now

	-- The shift's break overrides everything.
	if senses.resting then
		local nextMind = mind
		local cue: Cue? = nil
		if mind.mode ~= "rest" then
			nextMind = enter(mind, "rest", now)
			forget(nextMind)
			cue = "resting"
		end
		if flatDistance(senses.position, senses.restPoint) <= OccupantConstants.REACHED_DISTANCE then
			return { mind = nextMind, intent = { kind = "idle" }, cue = cue }
		end
		return { mind = nextMind, intent = { kind = "goTo", position = senses.restPoint, run = false }, cue = cue }
	end

	-- Standing over a catch, then walking away (toward his next route point); back from the break.
	local current = mind
	if mind.mode == "catch" then
		if now - mind.since < OccupantConstants.CATCH_HOLD then
			return { mind = mind, intent = { kind = "idle" } }
		end
		current = enter(mind, "patrol", now)
		current.target = nil
		if #senses.route > 0 then
			current.routeIndex = wrap(mind.routeIndex + mind.routeStep, #senses.route)
		end
	elseif mind.mode == "rest" then
		current = enter(mind, "patrol", now)
	end

	-- Sight beats everything else.
	local seen = OccupantBrainRules.visible(current, senses)
	if #seen > 0 then
		local pick = seen[1]
		for _, glimpse in seen do
			if glimpse.userId == current.target then
				pick = glimpse
			end
		end
		local chasing = current.mode == "chase"
		local nextMind: Mind = if chasing then table.clone(current) else enter(current, "chase", now)
		nextMind.target = pick.userId
		nextMind.lastSeen = pick.position
		nextMind.noise = nil
		nextMind.searchPoints = nil
		nextMind.searchIndex = nil
		local cue: Cue? = if chasing then nil else "spotted"
		if
			Reach.canReach(
				senses.position,
				pick.position,
				pick.feetY or pick.position.Y - 3,
				senses.reachTopY or senses.position.Y + 2.5,
				OccupantConstants.CATCH_RANGE
			)
		then
			return { mind = nextMind, intent = { kind = "attack", target = pick.userId, verticalReach = 8 }, cue = cue }
		end
		return { mind = nextMind, intent = { kind = "goTo", position = pick.position, run = true }, cue = cue }
	end

	-- Lingered in the bay with nobody in sight: out, and keep out a while.
	local bayAt = current.bayAt
	if bayAt ~= nil and inBox(senses.position, senses.bay) and now - bayAt >= OccupantConstants.BAY_LINGER_SECONDS then
		return leaveBay(current, senses)
	end

	-- Lost them: search where he last saw them.
	if current.mode == "chase" then
		local nextMind = enter(current, "search", now)
		local lastSeen = nextMind.lastSeen
		if lastSeen == nil then
			return giveUp(nextMind, senses)
		end
		nextMind.searchPoints = searchPoints(lastSeen, senses)
		nextMind.searchIndex = 1
		return { mind = nextMind, intent = { kind = "goTo", position = lastSeen, run = true } }
	end

	-- Continuous noise cannot renew a lost-target search indefinitely.
	if current.mode == "search" and now - current.since >= OccupantConstants.SEARCH_MAX_SECONDS then
		return giveUp(current, senses)
	end

	-- A noise (outside the safe zone).
	local heard = senses.heard
	if
		heard ~= nil
		and not OccupantBrainRules.inZone(heard, senses.zone)
		and not (barred(current, senses) and inBox(heard, senses.bay))
	then
		if current.mode == "search" then
			local nextMind = table.clone(current)
			nextMind.searchPoints = searchPoints(heard, senses)
			nextMind.searchIndex = 1
			nextMind.arrivedAt = nil
			return { mind = nextMind, intent = { kind = "goTo", position = heard, run = true } }
		end
		local nextMind = enter(current, "investigate", now)
		nextMind.noise = heard
		local cue: Cue? = if current.mode == "investigate" then nil else "curious"
		return { mind = nextMind, intent = { kind = "goTo", position = heard, run = false }, cue = cue }
	end

	-- Walking to the noise / last-seen point, looking around, giving up.
	if current.mode == "investigate" or current.mode == "search" then
		local searching: boolean = current.mode == "search"
		local points = current.searchPoints
		local point = if searching and points ~= nil
			then points[current.searchIndex or 1]
			elseif searching then current.lastSeen
			else current.noise
		local hold = if searching then OccupantConstants.SEARCH_SECONDS else OccupantConstants.LOOK_SECONDS
		if point == nil or (not searching and now - current.since >= OccupantConstants.GIVE_UP_SECONDS) then
			return giveUp(current, senses)
		end
		local arrivedAt = current.arrivedAt
		if arrivedAt == nil then
			if flatDistance(senses.position, point) <= OccupantConstants.REACHED_DISTANCE then
				local nextMind = table.clone(current)
				nextMind.arrivedAt = now
				return { mind = nextMind, intent = { kind = "idle" } }
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
			return giveUp(current, senses)
		end
		return { mind = current, intent = { kind = "idle" } }
	end

	return patrol(current, senses, nil)
end

return OccupantBrainRules
