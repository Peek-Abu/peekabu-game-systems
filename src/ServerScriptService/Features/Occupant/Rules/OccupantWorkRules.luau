--!strict
--[=[
	OccupantWorkRules: the Manager at a desk (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-design.md
	§1, §3). Desk work is part of his routine:

	- `due`: on patrol, when a work break is due (WORK_FIRST after he clocks in, then WORK_GAP after the last), a desk
	  from OccupantDeskUtils.pick (near the crew PICK_NEAR_CHANCE of the time, elsewhere otherwise and on a breather);
	  no desk = try again in 10 s.
	- `think`, phase by phase: walk to the chair (a sighting or a noise on the way is handled like on patrol: nil);
	  sit (a `sit` effect: the service anchors him there) and type WORK_SECONDS; then stand and walk on.
	- The ambush (OccupantStareRules.ambushes): a noise, a sighting or a player within AMBUSH_RADIUS while he sits stops
	  the typing dead and swivels his head to the point (the swivel lasts until he is up); after AMBUSH_HOLD he stands
	  (faster) and chases whoever he sees, or investigates the point.
	- A sit-in (he sat at the desk `quarry` hides under, OccupantStareRules.sitsIn): SIT_IN_BACK further back, typing
	  SIT_IN_TYPE (the camping push-out held meanwhile); his head tips down under the desk (TIP_SECONDS), holds TIP_HOLD,
	  and he catches them (OccupantStareRules.sitInCatches; a noise near the spot meanwhile makes it certain) or tips
	  back up (TIP_BACK), types TYPE_MORE, stands and walks on, forgetting them and leaving that spot alone
	  CLEARED_SECONDS. A noise elsewhere, a passer-by or the hider bolting is an ambush.

	Pure (see OccupantMindUtils).

	@class OccupantWorkRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantServer = ServerScriptService.Features.Occupant
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantStareRules = require(OccupantServer.Rules.OccupantStareRules)
local OccupantDeskUtils = require(OccupantServer.Utils.OccupantDeskUtils)
local M = require(OccupantServer.Utils.OccupantMindUtils)

type Mind = OccupantTypes.Mind
type Senses = OccupantTypes.Senses
type Glimpse = OccupantTypes.Glimpse
type Step = M.Step

local IDLE = M.IDLE

-- The work break is over: walk on, with the next one scheduled.
local function done(current: Mind, senses: Senses): Step
	local nextMind = table.clone(current)
	nextMind.nextWorkAt = senses.now + M.within(OccupantConstants.WORK_GAP, M.roll(senses, 2))
	return M.walkOn(nextMind, senses, nil)
end

local function toDesk(current: Mind, senses: Senses, seen: { Glimpse }, heard: Vector3?): Step?
	local now = senses.now
	local desk = current.desk
	if desk == nil then
		return M.walkOn(current, senses, nil)
	end
	if #seen > 0 or heard ~= nil then
		return nil
	end
	local quarry = current.quarry
	if current.sitIn and (current.spot == nil or quarry == nil or M.hiderOf(senses, quarry) == nil) then
		return M.walkOn(current, senses, nil)
	end
	if M.flat(senses.position, desk.seat.Position) <= M.ARRIVE_SEAT then
		-- Someone under this desk: the sit-in's hider, or one who crawled in while he walked here (he does not know
		-- them: an ordinary break, no tip). Either way he sits back so his knees stay out of their huddle, and their
		-- camping push-out waits until he has walked off.
		local unaware = if not current.sitIn and desk.spotId ~= nil then M.hiderIn(senses, desk.spotId) else nil
		local under: number? = if current.sitIn then quarry elseif unaware ~= nil then unaware.userId else nil
		local seat = if under ~= nil
			then OccupantDeskUtils.sitBack(desk.seat, OccupantConstants.SIT_IN_BACK)
			else desk.seat
		local hold = M.within(
			if current.sitIn then OccupantConstants.SIT_IN_TYPE else OccupantConstants.WORK_SECONDS,
			M.roll(senses, 1)
		)
		local nextMind = M.inPhase(current, "type", now, hold)
		nextMind.seated = true
		local step: Step = { mind = nextMind, intent = IDLE, cue = if current.sitIn then "sitIn" else nil }
		step = M.addEffect(step, { kind = "sit", seat = seat, desk = desk.frame, deskSize = desk.size })
		if under ~= nil then
			-- Held until he has stood up and walked off, so being cramped never throws them into his lap.
			local tail = OccupantConstants.STAND_SECONDS + 5
			if current.sitIn then
				tail += OccupantConstants.TIP_SECONDS + OccupantConstants.TIP_HOLD + OccupantConstants.TIP_BACK + OccupantConstants.TYPE_MORE
			end
			step = M.addEffect(step, { kind = "holdCamp", userId = under, untilTime = now + hold + tail })
		end
		return step
	end
	if M.elapsed(current, now) >= OccupantConstants.GIVE_UP_SECONDS then
		return done(current, senses)
	end
	return { mind = current, intent = { kind = "goTo", position = desk.seat.Position, run = false } }
end

-- The ambush is over: up, and after whoever he sees, else to the point.
local function rise(current: Mind, senses: Senses, seen: { Glimpse }): Step
	local now = senses.now
	local target: Glimpse? = nil
	for _, glimpse in seen do
		if glimpse.userId == current.target or target == nil then
			target = glimpse
		end
	end
	local step: Step
	if target ~= nil then
		step = M.chase(current, senses, target, false)
	else
		local nextMind = M.enter(current, "investigate", now)
		M.forget(nextMind)
		nextMind.noise = current.point or senses.position
		step = { mind = nextMind, intent = IDLE, cue = "curious" }
	end
	-- His head stays turned to the point while he stands up.
	local nextMind = table.clone(step.mind)
	nextMind.point = current.point
	nextMind.swivelUntil = now + OccupantConstants.STAND_SECONDS / OccupantConstants.AMBUSH_STAND_SPEED
	return { mind = nextMind, intent = IDLE, cue = step.cue, effects = step.effects }
end

-- The sit-in's end: he gets up and walks on, and forgets them.
local function leaveSitIn(current: Mind, senses: Senses): Step
	local nextMind = table.clone(current)
	local spot = current.spot
	if spot ~= nil then
		local cleared = table.clone(current.cleared)
		cleared[spot.id] = senses.now + OccupantConstants.CLEARED_SECONDS
		nextMind.cleared = cleared
	end
	local step = done(nextMind, senses)
	local quarry = current.quarry
	if quarry ~= nil then
		step = M.addEffect(step, { kind = "seen", userId = quarry, seen = false })
	end
	return step
end

local function seated(current: Mind, senses: Senses, seen: { Glimpse }, heard: Vector3?): Step
	local now = senses.now
	local phase = current.phase
	-- A noise near the spot during a sit-in is the hider's undoing, not an ambush.
	local spot = current.spot
	if
		current.sitIn
		and heard ~= nil
		and spot ~= nil
		and M.flat(heard, spot.center) <= OccupantConstants.STARE_NOISE_RADIUS
	then
		local noisy = table.clone(current)
		noisy.noisy = true
		current = noisy
		heard = nil
	end
	if phase ~= "ambush" then
		local nearest, who = M.nearestNoticed(current, senses)
		if OccupantStareRules.ambushes({ heard = heard ~= nil, seen = #seen > 0, nearest = nearest }) then
			local nextMind = M.inPhase(current, "ambush", now, OccupantConstants.AMBUSH_HOLD)
			if #seen > 0 then
				nextMind.point = seen[1].position
				nextMind.target = seen[1].userId
			elseif heard ~= nil then
				nextMind.point = heard
			elseif who ~= nil then
				nextMind.point = who.position
				nextMind.target = who.userId
			end
			nextMind.swivelUntil = math.huge
			return { mind = nextMind, intent = IDLE, cue = "ambush" }
		end
	end
	local seconds = M.elapsed(current, now)
	if phase == "ambush" then
		return if seconds < OccupantConstants.AMBUSH_HOLD
			then { mind = current, intent = IDLE }
			else rise(current, senses, seen)
	elseif phase == "type" then
		if seconds < (current.hold or 0) then
			return { mind = current, intent = IDLE }
		end
		if current.sitIn then
			return { mind = M.inPhase(current, "tip", now, OccupantConstants.TIP_SECONDS), intent = IDLE }
		end
		return done(current, senses)
	elseif phase == "tip" then
		if seconds < OccupantConstants.TIP_SECONDS then
			return { mind = current, intent = IDLE }
		end
		return { mind = M.inPhase(current, "tipHold", now, OccupantConstants.TIP_HOLD), intent = IDLE }
	elseif phase == "tipHold" then
		if seconds < OccupantConstants.TIP_HOLD then
			return { mind = current, intent = IDLE }
		end
		local step: Step = { mind = M.inPhase(current, "tipBack", now, OccupantConstants.TIP_BACK), intent = IDLE }
		local quarry = current.quarry
		if
			quarry ~= nil
			and M.hiderOf(senses, quarry) ~= nil
			and OccupantStareRules.sitInCatches(current.noisy == true, M.roll(senses, 3))
		then
			step = M.addEffect(step, { kind = "seen", userId = quarry, seen = true })
			step = M.addEffect(step, { kind = "catch", userId = quarry })
		end
		return step
	elseif phase == "tipBack" then
		if seconds < OccupantConstants.TIP_BACK then
			return { mind = current, intent = IDLE }
		end
		return { mind = M.inPhase(current, "typeMore", now, OccupantConstants.TYPE_MORE), intent = IDLE }
	end
	if seconds < OccupantConstants.TYPE_MORE then
		return { mind = current, intent = IDLE }
	end
	return leaveSitIn(current, senses)
end

local OccupantWorkRules = {}

--[=[
	A work break, when one is due and a desk fits (nil otherwise; the patrol goes on).
]=]
function OccupantWorkRules.due(current: Mind, senses: Senses): Step?
	local desks = senses.desks
	if current.mode ~= "patrol" or desks == nil or senses.now < current.nextWorkAt or current.steer ~= nil then
		return nil
	end
	local occupied: { [string]: boolean } = {}
	for _, hider in M.hiders(senses) do
		occupied[hider.spotId] = true
	end
	local desk = OccupantDeskUtils.pick(desks, {
		crew = M.positions(M.crew(senses)),
		occupied = occupied,
		last = current.lastDesk,
		near = not M.breathing(current, senses.now) and M.roll(senses, 1) < OccupantConstants.PICK_NEAR_CHANCE,
		roll = M.roll(senses, 2),
		bay = senses.bay,
	})
	if desk == nil then
		local nextMind = table.clone(current)
		nextMind.nextWorkAt = senses.now + 10
		return M.patrol(nextMind, senses, nil)
	end
	return M.beginWork(current, senses, desk, nil, nil)
end

--[=[
	One think in work mode. Nil while walking to the desk when a sighting or a noise needs the usual handling.
]=]
function OccupantWorkRules.think(current: Mind, senses: Senses, seen: { Glimpse }): Step?
	local heard = M.audible(current, senses)
	if current.phase == "toDesk" or current.phase == nil then
		return toDesk(current, senses, seen, heard)
	end
	return seated(current, senses, seen, heard)
end

return OccupantWorkRules
