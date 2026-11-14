--!strict
--[=[
	OccupantWatchRules: who watches a "freezes while watched" monster, and its freeze (Bramble; the substitute spec's
	"Watched is decided on the server" and fairness sections). A crew member is a watcher only if all of these hold:

	- alive, not knocked down, not hidden (even peeking), not in the truck's box and not vacuuming (`eligible`; B1, owner
	  11-14: a running vacuum takes your eyes, so the crew cannot clean and freeze it at once);
	- their client's camera report is fresh: received under FREEZE_REPORT_FRESH (0.3 s) ago (`fresh`);
	- the reported camera sits within FREEZE_CAMERA_RANGE (16) studs of their head (`cameraNear`), with a clear line
	  from the head to the camera (`cameraClear`, the caller's ray): no camera forged far off or through a wall;
	- one of the monster's points (head, chest, knees) is inside the camera's FREEZE_CONE (35 degrees) look cone
	  (`inCone`), within FREEZE_RANGE (80) studs of the camera, with a clear server ray to it (the caller's
	  `sightlines`).

	The freeze (`advance`): any watcher freezes it at once; after the last one looks away it holds
	FREEZE_UNFREEZE_BEAT (0.4 s), then moves. `canCatch`: never while frozen, nor for FREEZE_CATCH_BLOCK (0.6 s) after
	unfreezing.

	The brain's side (OccupantBrainRules): `pause` moves the clocks of a frozen think, `frozenSeconds` says by how much,
	`catchBlocked` and `withoutCatch` keep a catch out while frozen and for the block after.

	Pure: the rays are the caller's (OccupantWatchSystem); nothing here touches an Instance, and no function changes
	the state it is given. Times are os.clock() seconds; a report's time is when the server received it.

	@class OccupantWatchRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantMindUtils = require(ServerScriptService.Features.Occupant.Utils.OccupantMindUtils)

type Mind = OccupantTypes.Mind
type Senses = OccupantTypes.Senses
type Effect = OccupantTypes.Effect
type Step = OccupantMindUtils.Step

-- A client's camera report, as the server received it.
export type Report = {
	position: Vector3,
	look: Vector3,
	receivedAt: number,
}

-- One server ray from the reported camera to a point on the monster: whether nothing blocked it.
export type Sightline = {
	point: Vector3,
	clear: boolean,
}

-- One crew member this check.
export type Viewer = {
	alive: boolean,
	downed: boolean,
	hidden: boolean,
	inTruck: boolean,
	-- Their vacuum is sucking now (VacuumMotionConstants.ACTIVE_ATTRIBUTE on the character).
	vacuuming: boolean,
	head: Vector3,
	report: Report?,
	-- The ray from their head to the reported camera hit nothing.
	cameraClear: boolean,
	sightlines: { Sightline },
}

-- The monster's freeze: whether it is frozen, since when, when someone last watched it, and when it last unfroze.
export type Freeze = {
	frozen: boolean,
	frozenAt: number?,
	lastWatchedAt: number?,
	unfrozenAt: number?,
}

local COS_CONE = math.cos(math.rad(OccupantConstants.FREEZE_CONE))

local OccupantWatchRules = {}

function OccupantWatchRules.eligible(viewer: Viewer): boolean
	return viewer.alive and not viewer.downed and not viewer.hidden and not viewer.inTruck and not viewer.vacuuming
end

function OccupantWatchRules.fresh(report: Report?, now: number): boolean
	return report ~= nil and now < report.receivedAt + OccupantConstants.FREEZE_REPORT_FRESH
end

function OccupantWatchRules.cameraNear(head: Vector3, camera: Vector3): boolean
	return (camera - head).Magnitude <= OccupantConstants.FREEZE_CAMERA_RANGE
end

--[=[
	Whether `point` is within FREEZE_CONE degrees of the camera's `look` (false for a zero look or a point at the
	camera).
]=]
function OccupantWatchRules.inCone(camera: Vector3, look: Vector3, point: Vector3): boolean
	local offset = point - camera
	if offset.Magnitude < 1e-3 or look.Magnitude < 1e-3 then
		return false
	end
	return offset.Unit:Dot(look.Unit) >= COS_CONE
end

--[=[
	Whether `point` is close enough to the camera to count (FREEZE_RANGE).
]=]
function OccupantWatchRules.inRange(camera: Vector3, point: Vector3): boolean
	return (point - camera).Magnitude <= OccupantConstants.FREEZE_RANGE
end

--[=[
	Whether `viewer` watches the monster at `now` (see the class doc).
]=]
function OccupantWatchRules.watching(viewer: Viewer, now: number): boolean
	local report = viewer.report
	if not OccupantWatchRules.eligible(viewer) or report == nil or not OccupantWatchRules.fresh(report, now) then
		return false
	end
	if not OccupantWatchRules.cameraNear(viewer.head, report.position) or not viewer.cameraClear then
		return false
	end
	for _, line in viewer.sightlines do
		if
			line.clear
			and OccupantWatchRules.inRange(report.position, line.point)
			and OccupantWatchRules.inCone(report.position, report.look, line.point)
		then
			return true
		end
	end
	return false
end

function OccupantWatchRules.newFreeze(): Freeze
	return { frozen = false }
end

--[=[
	The freeze after this check at `now`: `watched` freezes it (keeping when it began); otherwise it unfreezes once
	FREEZE_UNFREEZE_BEAT has passed since the last watcher.
]=]
function OccupantWatchRules.advance(state: Freeze, watched: boolean, now: number): Freeze
	if watched then
		return {
			frozen = true,
			frozenAt = if state.frozen then state.frozenAt or now else now,
			lastWatchedAt = now,
			unfrozenAt = state.unfrozenAt,
		}
	end
	local last = state.lastWatchedAt
	if state.frozen and (last == nil or now >= last + OccupantConstants.FREEZE_UNFREEZE_BEAT) then
		return { frozen = false, unfrozenAt = now }
	end
	return table.clone(state)
end

--[=[
	Whether a catch is allowed at `now`: not frozen, and FREEZE_CATCH_BLOCK past its last unfreeze.
]=]
function OccupantWatchRules.canCatch(state: Freeze, now: number): boolean
	local unfrozenAt = state.unfrozenAt
	return not state.frozen and (unfrozenAt == nil or now >= unfrozenAt + OccupantConstants.FREEZE_CATCH_BLOCK)
end

--[=[
	Fills in a copy: every clock that times what he is doing (his mode, a phase, the look-around, the chase's give-up,
	the bay linger, standing up, a startle, a swivelled head) moved `seconds` later, so time spent frozen never counts
	toward any of them. Grace, the director's steer and work breaks run on real time.
]=]
function OccupantWatchRules.pause(mind: Mind, seconds: number)
	if seconds <= 0 then
		return
	end
	local function shift(value: number?): number?
		return if value ~= nil then value + seconds else nil
	end
	mind.since += seconds
	mind.chaseAt = shift(mind.chaseAt)
	mind.arrivedAt = shift(mind.arrivedAt)
	mind.phaseAt = shift(mind.phaseAt)
	mind.nearAt = shift(mind.nearAt)
	mind.bayAt = shift(mind.bayAt)
	mind.standUntil = shift(mind.standUntil)
	mind.reactUntil = shift(mind.reactUntil)
	mind.swivelUntil = shift(mind.swivelUntil)
end

--[=[
	How long he has been frozen since his last think (or since the freeze began, if later): the time to pause.
]=]
function OccupantWatchRules.frozenSeconds(mind: Mind, senses: Senses): number
	local from = mind.lastThink or senses.now
	local frozenAt = senses.frozenAt
	if frozenAt ~= nil and frozenAt > from then
		from = frozenAt
	end
	return math.max(0, senses.now - from)
end

--[=[
	Whether a catch is barred now: while frozen, and FREEZE_CATCH_BLOCK after the last unfreeze (never for Harlow,
	whose senses carry neither).
]=]
function OccupantWatchRules.catchBlocked(senses: Senses): boolean
	if senses.frozen == true then
		return true
	end
	local unfrozenAt = senses.unfrozenAt
	return unfrozenAt ~= nil and senses.now < unfrozenAt + OccupantConstants.FREEZE_CATCH_BLOCK
end

--[=[
	`step` with no catch in it: a grab becomes a run at them (idle when they are not in his senses), and a catch
	effect is dropped (as if the server refused it).
]=]
function OccupantWatchRules.withoutCatch(step: Step, senses: Senses): Step
	local intent = step.intent
	if intent.kind == "attack" then
		local target = intent.target
		intent = OccupantMindUtils.IDLE
		for _, glimpse in senses.players do
			if glimpse.userId == target then
				intent = { kind = "goTo", position = glimpse.position, run = true }
			end
		end
	end
	local effects: { Effect }? = nil
	if step.effects ~= nil then
		local kept: { Effect } = {}
		for _, effect in step.effects do
			if effect.kind ~= "catch" then
				table.insert(kept, effect)
			end
		end
		effects = if #kept > 0 then kept else nil
	end
	return { mind = step.mind, intent = intent, cue = step.cue, effects = effects }
end

--[=[
	The mind after the lunge (`Senses.lunge`: the kid its head held as the watching stopped, OccupantHeadRules.lunge):
	a chase of that kid, run at where they are, even out of sight (it knew whom it was after). Unchanged without a lunge,
	while frozen, during a catch, seated (the brain stands him up first), when he already chases that kid, or when the kid
	is in grace, hidden, in the truck's box or not in his senses (out, or being caught).
]=]
function OccupantWatchRules.lunge(mind: Mind, senses: Senses): Mind
	local userId = senses.lunge
	if userId == nil or senses.frozen == true or mind.mode == "catch" or mind.seated == true then
		return mind
	end
	if mind.mode == "chase" and mind.target == userId then
		return mind
	end
	local graceUntil = mind.grace[userId]
	if graceUntil ~= nil and senses.now < graceUntil then
		return mind
	end
	for _, glimpse in senses.players do
		if glimpse.userId == userId then
			if glimpse.hidden == true or OccupantMindUtils.inZone(glimpse.position, senses.zone) then
				return mind
			end
			return OccupantMindUtils.chase(mind, senses, glimpse, false).mind
		end
	end
	return mind
end

return OccupantWatchRules
