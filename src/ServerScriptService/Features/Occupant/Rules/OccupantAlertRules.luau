--!strict
--[=[
	OccupantAlertRules: the Manager's head turn, his "I noticed something" tell (docs/superpowers/specs/2026-10-15-
	cleanup-crew-manager-behaviours-design.md §10):

	- `glance`: the peripheral notice. The nearest crew member in his peripheral zone (OccupantSightUtils.peripheral:
	  outside the front cone, within PERIPHERAL_ANGLE and PERIPHERAL_RANGE, a clear line, never hidden) is counted up
	  each think while he walks on; at their glance delay (OccupantSightUtils.glanceDelay) he turns his head to them.
	  Out of the zone the count falls back NOTICE_DECAY a second and is dropped at 0. Patrol, investigate and search.
	  The felt presence (§11.7) shares the count: someone right behind him (OccupantSightUtils.behind, within
	  FELT_RANGE) is felt over OccupantSightUtils.feltDelay; the nearest of the two zones is counted.
	- `turns`: a noise he hears from outside his front cone, while he patrols or investigates, turns his head too.
	- `begin`: the head turn (mode `alert`): he stops dead and swivels only his head to the point (the desk ambush's
	  swivel), holding TURN_SWIVEL + TURN_HOLD (rolled).
	- `think`: the alert mode. While he holds, his head follows the player he turned to as long as he still sees them
	  that way; anyone in his front cone is chased at once (nil: the brain's sight does it); other noises are ignored.
	  At the check he chases whoever he sees down the cone his head looks along (OccupantSightUtils.toward: that player
	  first, else the nearest), else he walks over to investigate the point.

	- The slow turns (§11, OccupantTurnRules): `begin` picks the variant; a knowing turn or a staring contest runs its
	  own think. `force` is a developer's forced variant (the `occupantturn` command).

	Pure (see OccupantMindUtils).

	@class OccupantAlertRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantTurnRules = require(ServerScriptService.Features.Occupant.Rules.OccupantTurnRules)
local M = require(ServerScriptService.Features.Occupant.Utils.OccupantMindUtils)

type Mind = OccupantTypes.Mind
type Senses = OccupantTypes.Senses
type Glimpse = OccupantTypes.Glimpse
type TurnKind = OccupantTypes.TurnKind
type Step = M.Step

local IDLE = M.IDLE

-- The modes in which he notices someone beside him (as his long cone: not at a desk, a spot, a catch or his break).
local GLANCING: { [string]: boolean } = { patrol = true, investigate = true, search = true }
-- The modes in which a noise beside or behind him turns his head (a search runs straight at it instead).
local TURNING: { [string]: boolean } = { patrol = true, investigate = true }

-- Seconds since the last think (the glance's clock), as the brain's notice.
local function tick(mind: Mind, senses: Senses): number
	return math.clamp(senses.now - (mind.lastThink or senses.now), 0, 0.5)
end

local function find(list: { Glimpse }, userId: number?): Glimpse?
	for _, glimpse in list do
		if glimpse.userId == userId then
			return glimpse
		end
	end
	return nil
end

local OccupantAlertRules = {}

--[=[
	The head turn to `point` (`target`: the player he glimpsed, nil for a noise): stopped dead, his head swivelled there
	until the check, TURN_SWIVEL + TURN_HOLD (rolled) from now. Rarely a slow turn instead (OccupantTurnRules.pick).
]=]
function OccupantAlertRules.begin(current: Mind, senses: Senses, point: Vector3, target: number?): Step
	local who = OccupantTurnRules.candidate(current, senses, point, target)
	local kind: TurnKind = OccupantTurnRules.pick(current, senses, who)
	if OccupantTurnRules.slow(kind) and who ~= nil then
		return OccupantTurnRules.begin(current, senses, who, kind, false)
	end
	local now = senses.now
	local nextMind = M.enter(current, "alert", now)
	nextMind.turn = "snap"
	nextMind.lastTurn = "snap"
	nextMind.forceTurn = nil
	M.forget(nextMind)
	nextMind.steer = nil
	nextMind.target = target
	nextMind.point = point
	nextMind.phaseAt = now
	local hold = OccupantConstants.TURN_SWIVEL + M.within(OccupantConstants.TURN_HOLD, M.roll(senses, 4))
	nextMind.hold = hold
	nextMind.swivelUntil = now + hold
	nextMind.glanceId = nil
	nextMind.glanceSeconds = nil
	nextMind.noticeId = nil
	nextMind.noticeSeconds = nil
	return { mind = nextMind, intent = IDLE }
end

--[=[
	The peripheral notice this think: the mind with the count moved, and the head turn once it completes (nil before).
]=]
function OccupantAlertRules.glance(current: Mind, senses: Senses): (Mind, Step?)
	local side = if GLANCING[current.mode] then M.peripheral(current, senses)[1] else nil
	local back = if GLANCING[current.mode] then M.behind(current, senses)[1] else nil
	local glimpse = side
	if
		back ~= nil
		and (side == nil or (back.position - senses.position).Magnitude < (side.position - senses.position).Magnitude)
	then
		glimpse = back
	end
	if glimpse == nil then
		local seconds = current.glanceSeconds
		if seconds == nil then
			return current, nil
		end
		local nextMind = table.clone(current)
		local left = seconds - tick(current, senses) * OccupantConstants.NOTICE_DECAY
		nextMind.glanceSeconds = if left > 0 then left else nil
		nextMind.glanceId = if left > 0 then current.glanceId else nil
		return nextMind, nil
	end
	local carried = if current.glanceId == glimpse.userId then current.glanceSeconds or 0 else 0
	local seconds = carried + tick(current, senses)
	local distance = (glimpse.position - senses.position).Magnitude
	local delay = if glimpse == back
		then M.feltDelay(glimpse.crouched == true)
		else M.glanceDelay(distance, glimpse.crouched == true)
	if seconds >= delay then
		return current, OccupantAlertRules.begin(current, senses, glimpse.position, glimpse.userId)
	end
	local nextMind = table.clone(current)
	nextMind.glanceId = glimpse.userId
	nextMind.glanceSeconds = seconds
	return nextMind, nil
end

--[=[
	Whether the noise `heard` turns his head: from outside his front cone, while he patrols or investigates.
]=]
function OccupantAlertRules.turns(current: Mind, senses: Senses, heard: Vector3): boolean
	return TURNING[current.mode] == true and M.beside(senses, heard)
end

--[=[
	One think in alert mode. Nil when someone is in his front cone (the brain's sight chases them).
]=]
function OccupantAlertRules.think(current: Mind, senses: Senses, seen: { Glimpse }): Step?
	if OccupantTurnRules.turning(current) then
		return OccupantTurnRules.think(current, senses, seen)
	end
	if #seen > 0 then
		return nil
	end
	local now = senses.now
	local point = current.point or senses.position
	if M.elapsed(current, now) < (current.hold or 0) then
		-- His head follows the player he turned to while he still sees them beside him or down his head's cone.
		local target = current.target
		if target ~= nil then
			local glimpse = find(M.peripheral(current, senses), target)
				or find(M.toward(current, senses, point), target)
			if glimpse ~= nil and glimpse.position ~= point then
				local nextMind = table.clone(current)
				nextMind.point = glimpse.position
				return { mind = nextMind, intent = IDLE }
			end
		end
		return { mind = current, intent = IDLE }
	end
	local there = M.toward(current, senses, point)
	local pick = find(there, current.target) or there[1]
	if pick ~= nil then
		return M.chase(current, senses, pick, false)
	end
	local nextMind = M.enter(current, "investigate", now)
	M.forget(nextMind)
	nextMind.noise = point
	return { mind = nextMind, intent = { kind = "goTo", position = point, run = false }, cue = "curious" }
end

-- The modes he can be turned from at once by a developer's force (not at a desk, a spot, a catch or his break).
local FORCEABLE: { [string]: boolean } = { patrol = true, investigate = true, search = true, alert = true }

--[=[
	A developer's forced variant (the `occupantturn` command): `kind` (or "auto" to clear) for the next head turn. When he
	can see `userId` now (a clear line within his sight range, not hidden) and is free to, the turn starts at once at
	them; else it is armed for his next head turn. Returns the new mind.
]=]
function OccupantAlertRules.force(current: Mind, senses: Senses, kind: TurnKind | "auto", userId: number): Mind
	local nextMind = table.clone(current)
	if kind == "auto" then
		nextMind.forceTurn = nil
		return nextMind
	end
	nextMind.forceTurn = kind
	local glimpse = find(senses.players, userId)
	if
		glimpse == nil
		or not FORCEABLE[current.mode]
		or OccupantTurnRules.turning(current)
		or glimpse.hidden == true
		or not glimpse.clear
		or (glimpse.position - senses.position).Magnitude > senses.sightRange
	then
		return nextMind
	end
	return OccupantAlertRules.begin(nextMind, senses, glimpse.position, userId).mind
end

return OccupantAlertRules
