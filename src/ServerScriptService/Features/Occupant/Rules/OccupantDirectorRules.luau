--!strict
--[=[
	OccupantDirectorRules: what keeps the Manager present (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-
	behaviours-design.md §4, §5), like Alien: Isolation's director. Only when the Senses carry `pacing` (the service
	always passes it; bare rule specs do not), and only between patrol points:

	- `direct`: a breather when the menace gauge is full (MENACE_MAX: he walks to the route point farthest from the
	  crew, OccupantDirectorUtils.farPoint, and for OccupantMenaceFormulas.breather seconds neither steers nor follows a
	  noise further than BREATHER_HEARING; work breaks still happen, at the far desks); the PA call-out (CALLOUT_FIRST,
	  then CALLOUT_GAP: a `callout` effect naming the crew member farthest from him, whose area his next steer, in
	  CALLOUT_STEER_DELAY, aims at within STEER_FOCUS_SPREAD); and every steer interval
	  (OccupantMenaceFormulas.steerInterval) a steer toward a random crew member's general area (STEER_SPREAD off them,
	  never within STEER_MIN).
	- `track`: after every think, the seconds he had each player in sight (rising while seen, decaying WATCH_DECAY a
	  second otherwise, kept for whoever hides), whether each hider went in close to him (kept only while they hide),
	  and the menace gauge (OccupantMenaceFormulas.step: chasing, staring or sitting over a hider, someone within
	  MENACE_NEAR_RADIUS; it stays at 0 on a breather).

	Pure (see OccupantMindUtils).

	@class OccupantDirectorRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantServer = ServerScriptService.Features.Occupant
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantDirectorUtils = require(OccupantServer.Utils.OccupantDirectorUtils)
local OccupantMenaceFormulas = require(OccupantServer.Utils.OccupantMenaceFormulas)
local M = require(OccupantServer.Utils.OccupantMindUtils)

type Mind = OccupantTypes.Mind
type Senses = OccupantTypes.Senses
type Step = M.Step

-- A steer toward a crew member's area (the PA's called-out player when there is one).
local function steer(
	current: Mind,
	senses: Senses,
	pacing: OccupantTypes.Pacing,
	members: { OccupantDirectorUtils.Member }
): Step
	local nextMind = table.clone(current)
	nextMind.nextSteerAt = senses.now + OccupantMenaceFormulas.steerInterval(pacing)
	local target: OccupantDirectorUtils.Member? = nil
	for _, member in members do
		if member.userId == current.focus then
			target = member
		end
	end
	local spread = OccupantConstants.STEER_SPREAD
	if target ~= nil then
		spread = OccupantConstants.STEER_FOCUS_SPREAD
	else
		local index = OccupantDirectorUtils.pick(#members, M.roll(senses, 3))
		target = if index ~= nil then members[index] else nil
	end
	nextMind.focus = nil
	if target ~= nil then
		nextMind.steer = OccupantDirectorUtils.steerPoint(
			target.position,
			senses.route,
			spread,
			M.roll(senses, 1),
			M.roll(senses, 2),
			OccupantConstants.STEER_MIN
		)
	end
	return M.patrol(nextMind, senses, nil)
end

local OccupantDirectorRules = {}

--[=[
	The director's move for a patrolling Manager this think, or nil (nothing to do: his route, or a work break).
]=]
function OccupantDirectorRules.direct(current: Mind, senses: Senses): Step?
	local pacing = senses.pacing
	if pacing == nil or current.mode ~= "patrol" then
		return nil
	end
	local now = senses.now
	local members = M.crew(senses)
	if M.breathing(current, now) then
		-- No steering on a breather; once at the far point, work breaks happen as usual.
		if current.steer == nil then
			return nil
		end
		return M.patrol(current, senses, nil)
	end
	if OccupantMenaceFormulas.full(current.menace) then
		local nextMind = table.clone(current)
		nextMind.menace = 0
		nextMind.breatherUntil = now + OccupantMenaceFormulas.breather(pacing, M.roll(senses, 4))
		nextMind.steer = OccupantDirectorUtils.farPoint(senses.route, M.positions(members))
		nextMind.focus = nil
		return M.patrol(nextMind, senses, nil)
	end
	if #members == 0 then
		return nil
	end
	if now >= current.nextCalloutAt then
		local nextMind = table.clone(current)
		nextMind.nextCalloutAt = now + M.within(OccupantConstants.CALLOUT_GAP, M.roll(senses, 4))
		local userId = OccupantDirectorUtils.farthest(senses.position, members)
		if userId == nil then
			return M.patrol(nextMind, senses, nil)
		end
		nextMind.focus = userId
		nextMind.nextSteerAt = now + OccupantConstants.CALLOUT_STEER_DELAY
		return M.addEffect(M.patrol(nextMind, senses, nil), { kind = "callout", userId = userId })
	end
	if now >= current.nextSteerAt then
		return steer(current, senses, pacing, members)
	end
	return nil
end

--[=[
	`result` with what he saw this think remembered and the menace gauge moved (`before`: the mind the think began
	with).
]=]
function OccupantDirectorRules.track(before: Mind, result: Step, senses: Senses): Step
	local now = senses.now
	local dt = math.clamp(now - (before.lastThink or now), 0, 0.5)
	local mind = table.clone(result.mind)
	mind.lastThink = now
	local seenNow: { [number]: boolean } = {}
	for _, glimpse in M.visible(mind, senses) do
		seenNow[glimpse.userId] = true
	end
	local hiding: { [number]: boolean } = {}
	for _, hider in M.hiders(senses) do
		hiding[hider.userId] = true
	end
	local watched: { [number]: number } = {}
	for userId, seconds in before.watched do
		if hiding[userId] then
			watched[userId] = seconds
		elseif not seenNow[userId] then
			local left = seconds - dt * OccupantConstants.WATCH_DECAY
			if left > 0 then
				watched[userId] = left
			end
		end
	end
	for userId in seenNow do
		watched[userId] = (before.watched[userId] or 0) + dt
	end
	mind.watched = watched
	local close: { [number]: boolean } = {}
	for userId, value in mind.close do
		if hiding[userId] then
			close[userId] = value
		end
	end
	mind.close = close
	if senses.pacing ~= nil and M.breathing(mind, now) then
		-- A breather is a clean slate: even a catch on it does not fill the gauge back up.
		mind.menace = 0
	elseif senses.pacing ~= nil then
		local nearest = M.nearestNoticed(mind, senses)
		mind.menace = OccupantMenaceFormulas.step(mind.menace, dt, {
			chasing = mind.mode == "chase",
			engaged = mind.mode == "stare" or mind.sitIn == true,
			near = nearest ~= nil and nearest <= OccupantConstants.MENACE_NEAR_RADIUS,
		})
	end
	return { mind = mind, intent = result.intent, cue = result.cue, effects = result.effects }
end

return OccupantDirectorRules
