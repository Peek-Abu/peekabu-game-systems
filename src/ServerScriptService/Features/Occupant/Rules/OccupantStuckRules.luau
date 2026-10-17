--!strict
--[=[
	OccupantStuckRules: the Manager never freezes on a walk that goes nowhere (2026-10-17 audit). His NPC kind is costed
	(the truck's box), and a costed mover never steers without a path, so a goal no path reaches, or a root wedged where
	no path starts (pushed behind a desk, inside a filing cabinet), left him standing still for good: patrol legs and
	the director's steer had no give-up at all.

	`watch` runs after every think. While the intent is a `goTo` and he has not moved STUCK_MOVE flat studs for
	STUCK_SECONDS:

	- the first time he drops that goal (`abandon`): on patrol the next route point (a steer dropped), a stare's spot
	  left alone with its hider forgotten (or `known` sends him straight back), a desk walk ends its break, anything
	  else gives up with a sigh;
	- if he is still stuck STUCK_SECONDS later, the `unstick` effect also lifts him to the nearest route point that is
	  not where he stands (OccupantSeatSystem), from where a path exists.

	Any progress, or any other intent, starts the count again. Pure (see OccupantMindUtils).

	@class OccupantStuckRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantServer = ServerScriptService.Features.Occupant
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local M = require(OccupantServer.Utils.OccupantMindUtils)

type Mind = OccupantTypes.Mind
type Senses = OccupantTypes.Senses
type Step = M.Step

local OccupantStuckRules = {}

--[=[
	`step` with the goal he is stuck on dropped (see the class doc); the mind keeps its stuck count.
]=]
function OccupantStuckRules.abandon(step: Step, senses: Senses): Step
	local mind = step.mind
	local now = senses.now
	if mind.mode == "patrol" then
		local nextMind = table.clone(mind)
		if nextMind.steer ~= nil then
			nextMind.steer = nil
			M.rejoin(nextMind, senses)
		end
		if #senses.route > 0 then
			nextMind.routeIndex = M.wrap(nextMind.routeIndex + nextMind.routeStep, #senses.route)
		end
		return M.patrol(nextMind, senses, nil)
	elseif mind.mode == "stare" then
		local nextMind = table.clone(mind)
		local spot = mind.spot
		if spot ~= nil then
			local cleared = table.clone(mind.cleared)
			cleared[spot.id] = now + OccupantConstants.CLEARED_SECONDS
			nextMind.cleared = cleared
		end
		local walked = M.walkOn(nextMind, senses, nil)
		local quarry = mind.quarry
		if quarry ~= nil then
			walked = M.addEffect(walked, { kind = "seen", userId = quarry, seen = false })
		end
		return walked
	elseif mind.mode == "work" then
		local nextMind = table.clone(mind)
		nextMind.nextWorkAt = now + M.within(OccupantConstants.WORK_GAP, M.roll(senses, 2))
		return M.walkOn(nextMind, senses, nil)
	end
	return M.giveUp(mind, senses)
end

-- The route point nearest `position` that is more than REACHED_DISTANCE from it (nil: none).
function OccupantStuckRules.refuge(position: Vector3, route: { Vector3 }): Vector3?
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, point in route do
		local distance = M.flat(position, point)
		if distance > OccupantConstants.REACHED_DISTANCE and distance < bestDistance then
			best = point
			bestDistance = distance
		end
	end
	return best
end

--[=[
	`step` (this think's result; `before` the mind it began with) with his progress on a `goTo` tracked, and the goal
	abandoned (then also the `unstick` effect) when he has stood still on it too long. Never on the shift's break.
]=]
function OccupantStuckRules.watch(before: Mind, step: Step, senses: Senses): Step
	local now = senses.now
	local mind = table.clone(step.mind)
	local result: Step = { mind = mind, intent = step.intent, cue = step.cue, effects = step.effects }
	local from = before.stuckFrom
	local at = before.stuckAt
	local walking = step.intent.kind == "goTo" and mind.mode ~= "rest"
	if not walking then
		-- Standing still on purpose (looking round, seated, on his break): nothing to time.
		mind.stuckFrom = nil
		mind.stuckAt = nil
		mind.stuckCount = nil
		return result
	end
	if from == nil or at == nil or mind.mode ~= before.mode then
		-- A walk begins (or this think chose a new one): time it from now.
		mind.stuckFrom = senses.position
		mind.stuckAt = now
		mind.stuckCount = if mind.mode == before.mode then before.stuckCount else nil
		return result
	end
	if M.flat(senses.position, from) >= OccupantConstants.STUCK_MOVE then
		mind.stuckFrom = senses.position
		mind.stuckAt = now
		mind.stuckCount = nil
		return result
	end
	if now - at < OccupantConstants.STUCK_SECONDS then
		return result
	end
	local count = (before.stuckCount or 0) + 1
	local abandoned = OccupantStuckRules.abandon(result, senses)
	local nextMind = table.clone(abandoned.mind)
	nextMind.stuckFrom = senses.position
	nextMind.stuckAt = now
	nextMind.stuckCount = count
	abandoned = { mind = nextMind, intent = abandoned.intent, cue = abandoned.cue, effects = abandoned.effects }
	if count >= 2 then
		local refuge = OccupantStuckRules.refuge(senses.position, senses.route)
		if refuge ~= nil then
			abandoned = M.addEffect(abandoned, { kind = "unstick", position = refuge })
			abandoned.mind.stuckCount = nil
		end
	end
	return abandoned
end

return OccupantStuckRules
