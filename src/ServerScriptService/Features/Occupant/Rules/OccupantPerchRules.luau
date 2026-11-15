--!strict
--[=[
	OccupantPerchRules: the perch (B4, owner 11-14), for a freeze kind whose twist has `perch` (Bramble). He's never
	where you left him.

	- `ready`: he may perch when he is patrolling, investigating or searching; nobody has watched him for
	  PERCH_UNSEEN_SECONDS (and that long has passed since the run began, `Mind.perchReadyAt`); the cooldown after his
	  last drop is over; and no crew member is within PERCH_CREW_MIN studs of him.
	- A perch is a prop's side face he clings to (owner pick 11-14, "cling to locker side"): `faces` lists a box's four
	  side faces; OccupantWatchSystem measures which are clear and their landing, headroom and height over the floor.
	- `fits`: his head clears the ceiling over the edge and his hanging body clears the floor (Senses.perchHeight).
	- `pick`: of the faces no crew camera sees (Senses.perches) that he `fits`, the one nearest a crew member who is
	  out (not hidden), but no nearer than PERCH_NEAR and no farther than PERCH_FAR.
	- `begin`: up he goes, unseen and in a lights-out blackout (the `perch` effect: OccupantSeatSystem hangs him on the
	  face, facing out from it), still (mode "perch").
	- `think`, up there: he stays still until someone watched him there and looked away (an unfreeze after he went up),
	  someone comes within PERCH_DROP_RANGE, or PERCH_HOLD_MAX passes; then he drops to the face's checked landing (the
	  `drop` effect, `floorFor`, along `fallAt`) and patrols on, not to perch again for PERCH_COOLDOWN. A watched
	  think never gets here: frozen, the brain holds (OccupantBrainRules.hold).

	Distances are flat (studs across the floor). Pure (see OccupantMindUtils).

	@class OccupantPerchRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantMindUtils = require(ServerScriptService.Features.Occupant.Utils.OccupantMindUtils)

type Mind = OccupantTypes.Mind
type Senses = OccupantTypes.Senses
type Perch = OccupantTypes.Perch
type Glimpse = OccupantTypes.Glimpse
type Step = OccupantMindUtils.Step

local M = OccupantMindUtils

local READY_MODES: { [string]: boolean } = { patrol = true, investigate = true, search = true }

local OccupantPerchRules = {}

-- The crew members who are out (not hidden, outside the truck's box).
local function outCrew(senses: Senses): { Glimpse }
	local out = {}
	for _, glimpse in senses.players do
		if glimpse.hidden ~= true and not M.inZone(glimpse.position, senses.zone) then
			table.insert(out, glimpse)
		end
	end
	return out
end

-- The crew member out nearest `point`, and how far (flat); nil and math.huge with nobody out.
local function nearestOut(senses: Senses, point: Vector3): (Glimpse?, number)
	local best: Glimpse? = nil
	local bestDistance = math.huge
	for _, glimpse in outCrew(senses) do
		local distance = M.flat(glimpse.position, point)
		if distance < bestDistance then
			best = glimpse
			bestDistance = distance
		end
	end
	return best, bestDistance
end

--[=[
	Where the drop off `perch` lands: its face's checked landing.
]=]
function OccupantPerchRules.floorFor(perch: Perch): Vector3
	return perch.landing
end

--[=[
	Whether he fits clinging to `perch` (owner play-check 11-14): with his highest point PERCH_CLING_PEEK over the edge
	there is PERCH_HEAD_CLEAR left under the ceiling, and his hanging body, `height` studs from its lowest to its highest
	point (Senses.perchHeight; nil: unknown, only the ceiling is checked), keeps PERCH_FLOOR_CLEAR over the floor.
]=]
function OccupantPerchRules.fits(perch: Perch, height: number?): boolean
	if perch.headroom < OccupantConstants.PERCH_CLING_PEEK + OccupantConstants.PERCH_HEAD_CLEAR then
		return false
	end
	if height == nil then
		return true
	end
	return perch.floorDrop + OccupantConstants.PERCH_CLING_PEEK - height >= OccupantConstants.PERCH_FLOOR_CLEAR
end

export type Face = { edge: Vector3, normal: Vector3 }

--[=[
	The four side faces of a box (its `frame` and `size`, a prop's visible art): each one's top-edge centre and its
	outward normal, flat (OccupantWatchSystem measures which can be clung to).
]=]
function OccupantPerchRules.faces(frame: CFrame, size: Vector3): { Face }
	local half = size / 2
	local result: { Face } = {}
	for _, side in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local edge = frame * Vector3.new(side.X * half.X, half.Y, side.Z * half.Z)
		local normal = frame:VectorToWorldSpace(side)
		local flat = Vector3.new(normal.X, 0, normal.Z)
		if flat.Magnitude > 1e-6 then
			table.insert(result, { edge = edge, normal = flat.Unit })
		end
	end
	return result
end

--[=[
	Where the drop puts him `t` (0..1, clamped) of the way from `from` (on the perch) to `to` (the landing): out past
	the edge first (easing out across the floor plan), a `hop` studs hop up off the top, and a fall that gets faster
	and faster.
]=]
function OccupantPerchRules.fallAt(from: Vector3, to: Vector3, t: number, hop: number): Vector3
	local x = math.clamp(t, 0, 1)
	local out = 1 - (1 - x) * (1 - x)
	local across = from:Lerp(to, out)
	local height = from.Y + (to.Y - from.Y) * x * x + hop * 4 * x * (1 - x) * (1 - x)
	return Vector3.new(across.X, height, across.Z)
end

function OccupantPerchRules.ready(mind: Mind, senses: Senses): boolean
	local now = senses.now
	if senses.perches == nil or not READY_MODES[mind.mode] or mind.seated == true or mind.planted == true then
		return false
	end
	local readyAt = mind.perchReadyAt
	if readyAt ~= nil and now < readyAt then
		return false
	end
	local watchedAt = senses.watchedAt
	if watchedAt ~= nil and now - watchedAt < OccupantConstants.PERCH_UNSEEN_SECONDS then
		return false
	end
	for _, glimpse in senses.players do
		if M.flat(glimpse.position, senses.position) < OccupantConstants.PERCH_CREW_MIN then
			return false
		end
	end
	return true
end

function OccupantPerchRules.pick(senses: Senses): Perch?
	local best: Perch? = nil
	local bestDistance = math.huge
	local views: { OccupantTypes.PerchView } = senses.perches or {}
	for _, view in views do
		if view.seen or not OccupantPerchRules.fits(view.perch, senses.perchHeight) then
			continue
		end
		local _, distance = nearestOut(senses, view.perch.at)
		if
			distance >= OccupantConstants.PERCH_NEAR
			and distance <= OccupantConstants.PERCH_FAR
			and distance < bestDistance
		then
			best = view.perch
			bestDistance = distance
		end
	end
	return best
end

function OccupantPerchRules.begin(mind: Mind, senses: Senses): Step?
	if not OccupantPerchRules.ready(mind, senses) then
		return nil
	end
	local perch = OccupantPerchRules.pick(senses)
	if perch == nil then
		return nil
	end
	local nextMind = M.enter(mind, "perch", senses.now)
	M.forget(nextMind)
	nextMind.steer = nil
	nextMind.perch = perch
	nextMind.perchedAt = senses.now
	return M.addEffect(
		{ mind = nextMind, intent = M.IDLE },
		{ kind = "perch", edge = perch.edge, normal = perch.normal, at = perch.at }
	)
end

function OccupantPerchRules.think(mind: Mind, senses: Senses): Step
	local now = senses.now
	local perch = mind.perch
	local perchedAt = mind.perchedAt or mind.since
	local unfrozenAt = senses.unfrozenAt
	local nearest = math.huge
	if perch ~= nil then
		local _, distance = nearestOut(senses, perch.at)
		nearest = distance
	end
	local drop = perch == nil
		or (unfrozenAt ~= nil and unfrozenAt > perchedAt)
		or nearest < OccupantConstants.PERCH_DROP_RANGE
		or now - perchedAt >= OccupantConstants.PERCH_HOLD_MAX
	if not drop then
		return { mind = mind, intent = M.IDLE }
	end
	local nextMind = M.enter(mind, "patrol", now)
	nextMind.perch = nil
	nextMind.perchedAt = nil
	nextMind.perchReadyAt = now + OccupantConstants.PERCH_COOLDOWN
	nextMind.droppedAt = now
	local floor = if perch ~= nil then OccupantPerchRules.floorFor(perch) else senses.position
	return M.addEffect({ mind = nextMind, intent = M.IDLE }, { kind = "drop", position = floor })
end

return OccupantPerchRules
