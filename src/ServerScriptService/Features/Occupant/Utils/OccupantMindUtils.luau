--!strict
--[=[
	OccupantMindUtils: the shared pieces of the Manager's thinking (OccupantBrainRules, OccupantWorkRules,
	OccupantStareRules, OccupantDirectorRules; docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-
	design.md): copying a Mind into a new mode or phase, the lookups over the Senses, what he sees (`visible`), walking
	his route (`patrol`, or the director's steer point), going into a chase, a stare or a work break.

	Pure: nothing here yields or touches an Instance; no function changes a mind it is given, except the ones that
	say they fill in a copy (`settle`, `forget`, `rejoin`). Distances are flat (X/Z) unless named otherwise.

	@class OccupantMindUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantServer = ServerScriptService.Features.Occupant
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local NpcTypes = require(ServerScriptService.Features.Npc.Data.NpcTypes)
local Reach = require(OccupantServer.Rules.OccupantReachRules)
local Sight = require(OccupantServer.Utils.OccupantSightUtils)
local OccupantDirectorUtils = require(OccupantServer.Utils.OccupantDirectorUtils)
local OccupantMenaceFormulas = require(OccupantServer.Utils.OccupantMenaceFormulas)

type Mind = OccupantTypes.Mind
type Mode = OccupantTypes.Mode
type Phase = OccupantTypes.Phase
type Cue = OccupantTypes.Cue
type Senses = OccupantTypes.Senses
type Glimpse = OccupantTypes.Glimpse
type Effect = OccupantTypes.Effect
type Desk = OccupantTypes.Desk
type Spot = OccupantTypes.Spot
type Hider = OccupantTypes.Hider

export type Step = {
	mind: Mind,
	intent: NpcTypes.Intent,
	cue: Cue?,
	effects: { Effect }?,
}

local IDLE: NpcTypes.Intent = { kind = "idle" }

local M = {
	IDLE = IDLE,
	-- Close enough to a stare's stand point, or to a chair (the path often ends short of it, beside the desk), to settle
	-- there; the service slides him the rest.
	ARRIVE = 3.5,
	ARRIVE_SEAT = 5,
}

function M.flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- 1..count, wrapping both ways (Luau's % is floored, so -1 % 3 == 2).
function M.wrap(index: number, count: number): number
	return (index - 1) % count + 1
end

--[=[
	This think's `index`th roll (Senses.rolls), 0.5 when absent.
]=]
function M.roll(senses: Senses, index: number): number
	local rolls = senses.rolls
	local value = if rolls ~= nil then rolls[index] else nil
	return if value ~= nil then math.clamp(value, 0, 1) else 0.5
end

function M.within(range: OccupantConstants.Range, value: number): number
	return OccupantMenaceFormulas.within(range, value)
end

-- Fills in a copy: forgets the work / stare state (the desk, the spot, the phase).
function M.settle(mind: Mind)
	mind.phase = nil
	mind.phaseAt = nil
	mind.hold = nil
	mind.desk = nil
	mind.spot = nil
	mind.quarry = nil
	mind.sitIn = nil
	mind.noisy = nil
	mind.point = nil
	mind.hunch = nil
	mind.nearAt = nil
	mind.turn = nil
	mind.anchors = nil
end

-- Fills in a copy: forgets who he chased and what he heard.
function M.forget(mind: Mind)
	mind.target = nil
	mind.lastSeen = nil
	mind.noise = nil
	mind.searchPoints = nil
	mind.searchIndex = nil
end

--[=[
	A copy of `mind` in `mode`, begun `now`, not yet arrived anywhere, out of any work or stare.
]=]
function M.enter(mind: Mind, mode: Mode, now: number): Mind
	local nextMind = table.clone(mind)
	nextMind.mode = mode
	nextMind.since = now
	nextMind.arrivedAt = nil
	M.settle(nextMind)
	return nextMind
end

function M.inPhase(mind: Mind, phase: Phase, now: number, hold: number?): Mind
	local nextMind = table.clone(mind)
	nextMind.phase = phase
	nextMind.phaseAt = now
	nextMind.hold = hold
	return nextMind
end

function M.elapsed(mind: Mind, now: number): number
	return now - (mind.phaseAt or now)
end

function M.inZone(point: Vector3, zone: OccupantTypes.Zone?): boolean
	return zone ~= nil
		and point.X >= zone.min.X
		and point.X <= zone.max.X
		and point.Y >= zone.min.Y
		and point.Y <= zone.max.Y
		and point.Z >= zone.min.Z
		and point.Z <= zone.max.Z
end

-- Keeping out of the bay after lingering there.
function M.barred(mind: Mind, now: number): boolean
	local untilTime = mind.bayBarredUntil
	return untilTime ~= nil and now < untilTime
end

-- On a breather (the director's calm phase).
function M.breathing(mind: Mind, now: number): boolean
	local untilTime = mind.breatherUntil
	return untilTime ~= nil and now < untilTime
end

function M.graced(mind: Mind, userId: number, now: number): boolean
	local untilTime = mind.grace[userId]
	return untilTime ~= nil and now < untilTime
end

function M.addEffect(step: Step, effect: Effect): Step
	local effects = if step.effects ~= nil then table.clone(step.effects) else {}
	table.insert(effects, effect)
	return { mind = step.mind, intent = step.intent, cue = step.cue, effects = effects }
end

-- The lists the Senses may carry (empty when absent).
function M.hiders(senses: Senses): { Hider }
	local list: { Hider } = senses.hiders or {}
	return list
end

function M.spots(senses: Senses): { Spot }
	local list: { Spot } = senses.spots or {}
	return list
end

function M.desks(senses: Senses): { Desk }
	local list: { Desk } = senses.desks or {}
	return list
end

function M.findDesk(senses: Senses, id: string?): Desk?
	for _, desk in M.desks(senses) do
		if id ~= nil and desk.id == id then
			return desk
		end
	end
	return nil
end

function M.hiderIn(senses: Senses, spotId: string): Hider?
	for _, hider in M.hiders(senses) do
		if hider.spotId == spotId then
			return hider
		end
	end
	return nil
end

function M.hiderOf(senses: Senses, userId: number?): Hider?
	for _, hider in M.hiders(senses) do
		if hider.userId == userId then
			return hider
		end
	end
	return nil
end

function M.spotById(senses: Senses, id: string): Spot?
	for _, spot in M.spots(senses) do
		if spot.id == id then
			return spot
		end
	end
	return nil
end

--[=[
	The crew as the director knows them: everyone outside the truck's box (hidden or not), and where they are.
]=]
function M.crew(senses: Senses): { OccupantDirectorUtils.Member }
	local list: { OccupantDirectorUtils.Member } = {}
	for _, glimpse in senses.players do
		if not M.inZone(glimpse.position, senses.zone) then
			table.insert(list, { userId = glimpse.userId, position = glimpse.position })
		end
	end
	return list
end

function M.positions(members: { OccupantDirectorUtils.Member }): { Vector3 }
	local list: { Vector3 } = {}
	for _, member in members do
		table.insert(list, member.position)
	end
	return list
end

--[=[
	What the debugger shows of his mind: his mode, phase, target, route point, menace gauge, breather and sit-ins.
]=]
function M.summary(mind: Mind): { [string]: string | number }
	return {
		mode = mind.mode,
		phase = mind.phase or "",
		target = mind.target or 0,
		routeIndex = mind.routeIndex,
		menace = mind.menace,
		breatherUntil = mind.breatherUntil or 0,
		sitIns = mind.sitIns,
	}
end

-- Fills in a copy: back on his route at its nearest point.
function M.rejoin(mind: Mind, senses: Senses)
	local index = OccupantDirectorUtils.nearestIndex(senses.route, senses.position)
	if index ~= nil then
		mind.routeIndex = index
	end
end

export type Sight = Sight.Sight

-- What he sees (OccupantSightUtils): near and far, the players he sees, those far off to notice, the notice delay.
M.sightOf = Sight.sightOf
M.visible = Sight.visible
M.distant = Sight.distant
M.sees = Sight.sees
M.noticeDelay = Sight.noticeDelay
-- Beside him and where his head turns (behaviours design section 10): the peripheral zone, its notice delay, whether a
-- point is outside his front cone, and who he sees down a turned head's cone.
M.peripheral = Sight.peripheral
M.glanceDelay = Sight.glanceDelay
M.beside = Sight.beside
M.toward = Sight.toward

--[=[
	The nearest crew member he could notice from where he is, seen or not (not hiding, not in the box, not in their
	grace): the distance and who. `clear`: only one he has a clear line of sight to (the desk ambush: never through a
	wall).
]=]
function M.nearestNoticed(mind: Mind, senses: Senses, clear: boolean?): (number?, Glimpse?)
	local best: number? = nil
	local who: Glimpse? = nil
	for _, glimpse in senses.players do
		if
			glimpse.hidden ~= true
			and (clear ~= true or glimpse.clear)
			and not M.graced(mind, glimpse.userId, senses.now)
			and not M.inZone(glimpse.position, senses.zone)
		then
			local distance = M.flat(senses.position, glimpse.position)
			if best == nil or distance < best then
				best = distance
				who = glimpse
			end
		end
	end
	return best, who
end

--[=[
	The noise he follows: heard outside the box, not in the bay while he keeps out of it, and close to him on a
	breather.
]=]
function M.audible(mind: Mind, senses: Senses): Vector3?
	local heard = senses.heard
	if heard == nil or M.inZone(heard, senses.zone) then
		return nil
	end
	if M.barred(mind, senses.now) and M.inZone(heard, senses.bay) then
		return nil
	end
	if M.breathing(mind, senses.now) and M.flat(heard, senses.position) > OccupantConstants.BREATHER_HEARING then
		return nil
	end
	return heard
end

--[=[
	Walks the route (or to the director's steer point first): on reaching the current point, heads for the next one in
	his direction (past a bay point while he keeps out of the bay).
]=]
function M.patrol(mind: Mind, senses: Senses, cue: Cue?): Step
	local route = senses.route
	local steer = mind.steer
	if steer ~= nil then
		if M.flat(senses.position, steer) > OccupantConstants.REACHED_DISTANCE then
			return { mind = mind, intent = { kind = "goTo", position = steer, run = false }, cue = cue }
		end
		local arrived = table.clone(mind)
		arrived.steer = nil
		M.rejoin(arrived, senses)
		mind = arrived
	end
	if #route == 0 then
		return { mind = mind, intent = IDLE, cue = cue }
	end
	local index = M.wrap(mind.routeIndex, #route)
	if M.flat(senses.position, route[index]) <= OccupantConstants.REACHED_DISTANCE then
		index = M.wrap(index + mind.routeStep, #route)
	end
	if M.barred(mind, senses.now) then
		for _ = 1, #route do
			if not M.inZone(route[index], senses.bay) then
				break
			end
			index = M.wrap(index + mind.routeStep, #route)
		end
	end
	local nextMind = mind
	if index ~= mind.routeIndex then
		nextMind = table.clone(mind)
		nextMind.routeIndex = index
	end
	return { mind = nextMind, intent = { kind = "goTo", position = route[index], run = false }, cue = cue }
end

-- Gave up: patrol, with a sigh.
function M.giveUp(mind: Mind, senses: Senses): Step
	local nextMind = M.enter(mind, "patrol", senses.now)
	M.forget(nextMind)
	return M.patrol(nextMind, senses, "giveUp")
end

-- Back to his route at its nearest point after a desk or a spot (no sigh: he just walks on).
function M.walkOn(mind: Mind, senses: Senses, cue: Cue?): Step
	local nextMind = M.enter(mind, "patrol", senses.now)
	M.forget(nextMind)
	M.rejoin(nextMind, senses)
	return M.patrol(nextMind, senses, cue)
end

--[=[
	Last-seen first, then at most SEARCH_PROBES nearby authored route points. No hidden player sampling.
]=]
function M.searchPoints(point: Vector3, senses: Senses): { Vector3 }
	local candidates: { Vector3 } = {}
	for _, candidate in senses.route do
		local distance = M.flat(point, candidate)
		if
			distance > OccupantConstants.REACHED_DISTANCE
			and distance <= OccupantConstants.SEARCH_RADIUS
			and not M.inZone(candidate, senses.zone)
		then
			table.insert(candidates, candidate)
		end
	end
	table.sort(candidates, function(a, b)
		local da, db = M.flat(point, a), M.flat(point, b)
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
			if M.flat(existing, candidate) <= OccupantConstants.REACHED_DISTANCE then
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

--[=[
	Into (or on with) a chase of `glimpse`; `startled`: a hider bolting, so a STARTLE_SECONDS beat before he moves.
	Within reach the intent is the catch.
]=]
function M.chase(current: Mind, senses: Senses, glimpse: Glimpse, startled: boolean): Step
	local now = senses.now
	local chasing = current.mode == "chase"
	local nextMind: Mind = if chasing then table.clone(current) else M.enter(current, "chase", now)
	nextMind.target = glimpse.userId
	nextMind.lastSeen = glimpse.position
	nextMind.noise = nil
	nextMind.searchPoints = nil
	nextMind.searchIndex = nil
	nextMind.steer = nil
	local cue: Cue? = if chasing then nil else "spotted"
	if not chasing then
		nextMind.menace = OccupantMenaceFormulas.bump(current.menace, OccupantConstants.MENACE_SPOTTED)
	end
	if startled then
		nextMind.reactUntil = now + OccupantConstants.STARTLE_SECONDS
		return { mind = nextMind, intent = IDLE, cue = cue }
	end
	if
		Reach.canReach(
			senses.position,
			glimpse.position,
			glimpse.feetY or glimpse.position.Y - 3,
			senses.reachTopY or senses.position.Y + 2.5,
			OccupantConstants.CATCH_RANGE
		)
	then
		return { mind = nextMind, intent = { kind = "attack", target = glimpse.userId, verticalReach = 8 }, cue = cue }
	end
	return { mind = nextMind, intent = { kind = "goTo", position = glimpse.position, run = true }, cue = cue }
end

--[=[
	To `spot` to stare at it: `quarry` is the hider he knows is there (nil: he only suspects). Remembers how far from him
	they went in.
]=]
function M.beginStare(current: Mind, senses: Senses, spot: Spot, quarry: number?): Step
	local nextMind = M.enter(current, "stare", senses.now)
	M.forget(nextMind)
	nextMind.steer = nil
	nextMind.phase = "approach"
	nextMind.phaseAt = senses.now
	nextMind.spot = spot
	nextMind.quarry = quarry
	nextMind.noisy = false
	if quarry ~= nil then
		-- Who he stares for: the chase target he lost under there (the stand point is walked in a hurry).
		nextMind.target = if current.mode == "chase" or current.mode == "search" then quarry else nil
		-- How far away he was as they went in (this think follows Hide's witness by a beat at most).
		local entered = table.clone(current.entered)
		if entered[quarry] == nil then
			entered[quarry] = M.flat(senses.position, spot.center)
		end
		nextMind.entered = entered
	end
	return { mind = nextMind, intent = { kind = "goTo", position = spot.stand, run = nextMind.target ~= nil } }
end

--[=[
	To `desk` for a work break, or (`quarry` set) to sit at the desk they hide under (`spot`): a sit-in, counted.
]=]
function M.beginWork(current: Mind, senses: Senses, desk: Desk, quarry: number?, spot: Spot?): Step
	local nextMind = M.enter(current, "work", senses.now)
	M.forget(nextMind)
	nextMind.steer = nil
	nextMind.phase = "toDesk"
	nextMind.phaseAt = senses.now
	nextMind.desk = desk
	nextMind.lastDesk = desk.id
	if quarry ~= nil then
		nextMind.sitIn = true
		nextMind.quarry = quarry
		nextMind.spot = spot
		nextMind.sitIns = current.sitIns + 1
		nextMind.lastSitInAt = senses.now
	end
	return { mind = nextMind, intent = { kind = "goTo", position = desk.seat.Position, run = false } }
end

return M
