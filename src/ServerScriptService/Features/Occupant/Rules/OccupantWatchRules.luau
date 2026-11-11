--!strict
--[=[
	OccupantWatchRules: who watches a "freezes while watched" monster, and its freeze (Bramble; the substitute spec's
	"Watched is decided on the server" and fairness sections). A crew member is a watcher only if all of these hold:

	- alive, not knocked down, not hidden (even peeking) and not in the truck's box (`eligible`);
	- their client's camera report is fresh: received under FREEZE_REPORT_FRESH (0.3 s) ago (`fresh`);
	- the reported camera sits within FREEZE_CAMERA_RANGE (16) studs of their head (`cameraNear`), with a clear line
	  from the head to the camera (`cameraClear`, the caller's ray): no camera forged far off or through a wall;
	- one of the monster's points (head, chest, knees) is inside the camera's FREEZE_CONE (35 degrees) look cone
	  (`inCone`), within FREEZE_RANGE (80) studs of the camera, with a clear server ray to it (the caller's
	  `sightlines`).

	The freeze (`advance`): any watcher freezes it at once; after the last one looks away it holds
	FREEZE_UNFREEZE_BEAT (0.4 s), then moves. `canCatch`: never while frozen, nor for FREEZE_CATCH_BLOCK (0.6 s) after
	unfreezing.

	Pure: the rays are the caller's (OccupantWatchSystem); nothing here touches an Instance, and no function changes
	the state it is given. Times are os.clock() seconds; a report's time is when the server received it.

	@class OccupantWatchRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

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
	return viewer.alive and not viewer.downed and not viewer.hidden and not viewer.inTruck
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

return OccupantWatchRules
