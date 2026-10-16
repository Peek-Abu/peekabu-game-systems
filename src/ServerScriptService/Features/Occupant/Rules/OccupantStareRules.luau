--!strict
--[=[
	OccupantStareRules: how the Manager's stare-down, sit-in and desk ambush end (docs/superpowers/specs/
	2026-10-15-cleanup-crew-manager-behaviours-design.md §1–§3). Learnable and fair:

	- A stare lasts STARE_SECONDS (he saw you go in) or SUSPECT_SECONDS (he only heard a noise near the spots).
	- Whether he then bends down and looks: CHECK_BASE + CHECK_PER_SECOND per second he had eyes on you, + CHECK_CLOSE
	  when you went in within CHECK_CLOSE_RADIUS of him, capped at CHECK_MAX. A noise near the spot meanwhile makes it
	  certain. So break line of sight early and far, and keep the crew quiet around you.
	- A sit-in (he sits at the desk you hide under) is rare: SIT_IN_CHANCE, at most SIT_IN_MAX a shift, SIT_IN_GAP
	  apart, only at a desk with someone under it whose chair is on the knee-hole side. At its end he catches you on
	  SIT_IN_CATCH (certain after a noise).
	- The ambush while he sits: a noise he hears, a player he sees, or a player within AMBUSH_RADIUS.

	`think` runs the stare mode: walk to the spot's stand point (in a hurry after a chase), plant there facing it (the
	camping push-out held), hold still; then check (bend down, CHECK_SECONDS, then the catch), sit in (the desk's work
	break, OccupantMindUtils.beginWork), or walk on (forgetting the hider, the spot left alone CLEARED_SECONDS). A hider
	who bolts startles him (STARTLE_SECONDS) into a chase if he sees them, else he searches from the spot. `known` is
	the nearest hider he saw go in; `suspect` the spot by a noise he walked up to.

	`roll`s are uniform 0..1. Pure.

	@class OccupantStareRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantServer = ServerScriptService.Features.Occupant
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantDeskUtils = require(OccupantServer.Utils.OccupantDeskUtils)
local M = require(OccupantServer.Utils.OccupantMindUtils)

type Mind = OccupantTypes.Mind
type Senses = OccupantTypes.Senses
type Glimpse = OccupantTypes.Glimpse
type Hider = OccupantTypes.Hider
type Spot = OccupantTypes.Spot
type Step = M.Step

local IDLE = M.IDLE

export type CheckInput = {
	watched: number,
	close: boolean,
	noisy: boolean,
	roll: number,
}

export type SitInInput = {
	roll: number,
	sitIns: number,
	lastSitInAt: number?,
	now: number,
	front: boolean,
	occupied: boolean,
}

export type AmbushInput = {
	heard: boolean,
	seen: boolean,
	-- Flat studs to the nearest crew member he could notice (nil = nobody).
	nearest: number?,
}

local OccupantStareRules = {}

function OccupantStareRules.duration(suspect: boolean, roll: number): number
	local range = if suspect then OccupantConstants.SUSPECT_SECONDS else OccupantConstants.STARE_SECONDS
	return range.min + (range.max - range.min) * math.clamp(roll, 0, 1)
end

function OccupantStareRules.checkChance(watched: number, close: boolean): number
	local chance = OccupantConstants.CHECK_BASE
		+ OccupantConstants.CHECK_PER_SECOND * math.max(watched, 0)
		+ (if close then OccupantConstants.CHECK_CLOSE else 0)
	return math.min(chance, OccupantConstants.CHECK_MAX)
end

function OccupantStareRules.checks(input: CheckInput): boolean
	if input.noisy then
		return true
	end
	return input.roll < OccupantStareRules.checkChance(input.watched, input.close)
end

function OccupantStareRules.sitsIn(input: SitInInput): boolean
	if not input.occupied or not input.front or input.sitIns >= OccupantConstants.SIT_IN_MAX then
		return false
	end
	local last = input.lastSitInAt
	if last ~= nil and input.now - last < OccupantConstants.SIT_IN_GAP then
		return false
	end
	return input.roll < OccupantConstants.SIT_IN_CHANCE
end

function OccupantStareRules.sitInCatches(noisy: boolean, roll: number): boolean
	return noisy or roll < OccupantConstants.SIT_IN_CATCH
end

function OccupantStareRules.ambushes(input: AmbushInput): boolean
	local nearest = input.nearest
	return input.heard or input.seen or (nearest ~= nil and nearest <= OccupantConstants.AMBUSH_RADIUS)
end

-- He walks away from the spot: the hider forgotten, the spot left alone a while.
local function leave(current: Mind, senses: Senses, spot: Spot): Step
	local nextMind = table.clone(current)
	local cleared = table.clone(current.cleared)
	cleared[spot.id] = senses.now + OccupantConstants.CLEARED_SECONDS
	nextMind.cleared = cleared
	local step = M.walkOn(nextMind, senses, nil)
	local quarry = current.quarry
	if quarry ~= nil then
		step = M.addEffect(step, { kind = "seen", userId = quarry, seen = false })
	end
	return step
end

local function approach(current: Mind, senses: Senses, spot: Spot): Step
	local now = senses.now
	if M.flat(senses.position, spot.stand) > M.ARRIVE then
		if M.elapsed(current, now) >= OccupantConstants.GIVE_UP_SECONDS then
			return M.walkOn(current, senses, nil)
		end
		return { mind = current, intent = { kind = "goTo", position = spot.stand, run = current.target ~= nil } }
	end
	local hold = OccupantStareRules.duration(current.quarry == nil, M.roll(senses, 1))
	local nextMind = M.inPhase(current, "hold", now, hold)
	nextMind.planted = true
	local frame = OccupantDeskUtils.facing(Vector3.new(spot.stand.X, senses.position.Y, spot.stand.Z), spot.center)
	local plant: OccupantTypes.Effect = { kind = "plant", frame = frame }
	local step: Step = { mind = nextMind, intent = IDLE, effects = { plant } }
	local hider = M.hiderIn(senses, spot.id)
	if hider ~= nil then
		local untilTime = now + hold + OccupantConstants.CHECK_SECONDS + 6
		step = M.addEffect(step, { kind = "holdCamp", userId = hider.userId, untilTime = untilTime })
	end
	return step
end

-- The stare is over: look, sit in, or walk on.
local function decide(current: Mind, senses: Senses, spot: Spot): Step
	local now = senses.now
	local hider = M.hiderIn(senses, spot.id)
	local quarry = current.quarry
	if quarry == nil and hider ~= nil and current.noisy then
		-- A noise from the very spot he suspected: now he knows.
		quarry = hider.userId
	end
	if
		quarry ~= nil
		and OccupantStareRules.checks({
			watched = current.watched[quarry] or 0,
			close = current.close[quarry] == true,
			noisy = current.noisy == true,
			roll = M.roll(senses, 2),
		})
	then
		local nextMind = M.inPhase(current, "check", now, OccupantConstants.CHECK_SECONDS)
		nextMind.quarry = quarry
		local step: Step = { mind = nextMind, intent = IDLE }
		step = M.addEffect(step, { kind = "seen", userId = quarry, seen = true })
		local untilTime = now + OccupantConstants.CHECK_SECONDS + 4
		return M.addEffect(step, { kind = "holdCamp", userId = quarry, untilTime = untilTime })
	end
	-- He did not look. Sometimes he sits down at that very desk instead of leaving.
	local desk = M.findDesk(senses, spot.deskId)
	if
		hider ~= nil
		and desk ~= nil
		and OccupantStareRules.sitsIn({
			roll = M.roll(senses, 3),
			sitIns = current.sitIns,
			lastSitInAt = current.lastSitInAt,
			now = now,
			front = desk.front,
			occupied = true,
		})
	then
		return M.beginWork(current, senses, desk, hider.userId, spot)
	end
	return leave(current, senses, spot)
end

--[=[
	One think in stare mode. Nil when someone else is in sight (the chase) before he bends down to look.
]=]
function OccupantStareRules.think(current: Mind, senses: Senses, seen: { Glimpse }): Step?
	local now = senses.now
	local spot = current.spot
	if spot == nil then
		return M.walkOn(current, senses, nil)
	end
	local quarry = current.quarry
	if quarry ~= nil and M.hiderOf(senses, quarry) == nil then
		-- They bolted: if he can see them, a startled beat, then the chase; else he searches from the spot.
		for _, glimpse in seen do
			if glimpse.userId == quarry then
				return M.chase(current, senses, glimpse, true)
			end
		end
		local nextMind = M.enter(current, "search", now)
		nextMind.target = quarry
		nextMind.lastSeen = spot.stand
		nextMind.searchPoints = M.searchPoints(spot.stand, senses)
		nextMind.searchIndex = 1
		return { mind = nextMind, intent = IDLE }
	end
	if #seen > 0 and current.phase ~= "check" then
		return nil
	end
	local heard = senses.heard
	if heard ~= nil and M.flat(heard, spot.center) <= OccupantConstants.STARE_NOISE_RADIUS then
		local noisy = table.clone(current)
		noisy.noisy = true
		current = noisy
	end
	local phase = current.phase
	if phase == "approach" then
		return approach(current, senses, spot)
	elseif phase == "hold" then
		if M.elapsed(current, now) < (current.hold or 0) then
			return { mind = current, intent = IDLE }
		end
		return decide(current, senses, spot)
	end
	-- check: bent down looking under; then the catch.
	if M.elapsed(current, now) < OccupantConstants.CHECK_SECONDS then
		return { mind = current, intent = IDLE }
	end
	local step = M.walkOn(current, senses, nil)
	if quarry ~= nil then
		step = M.addEffect(step, { kind = "catch", userId = quarry })
	end
	return step
end

--[=[
	The nearest hider he knows of (saw go in, or tracked there), with their spot.
]=]
function OccupantStareRules.known(mind: Mind, senses: Senses): (Hider?, Spot?)
	local best: Hider? = nil
	local bestSpot: Spot? = nil
	local bestDistance = math.huge
	for _, hider in M.hiders(senses) do
		local spot = M.spotById(senses, hider.spotId)
		if hider.seen and spot ~= nil and not M.graced(mind, hider.userId, senses.now) then
			local distance = M.flat(senses.position, spot.center)
			if distance < bestDistance then
				best = hider
				bestSpot = spot
				bestDistance = distance
			end
		end
	end
	return best, bestSpot
end

--[=[
	The hiding spot within SUSPECT_RADIUS of a noise he walked up to (nearest; not one he left alone lately).
]=]
function OccupantStareRules.suspect(mind: Mind, senses: Senses, point: Vector3): Spot?
	local best: Spot? = nil
	local bestDistance = math.huge
	for _, spot in M.spots(senses) do
		local clearedUntil = mind.cleared[spot.id]
		local distance = M.flat(point, spot.center)
		if
			distance <= OccupantConstants.SUSPECT_RADIUS
			and distance < bestDistance
			and not (clearedUntil ~= nil and senses.now < clearedUntil)
		then
			best = spot
			bestDistance = distance
		end
	end
	return best
end

return OccupantStareRules
