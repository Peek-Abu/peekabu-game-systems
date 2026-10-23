--!strict
--[=[
	OccupantSightUtils: what the Manager sees (docs/superpowers/specs/2026-10-16-cleanup-crew-manager-chase-tuning-
	design.md §2). Near: a clear ray within sightRange in the sightAngle cone (his chase or search target all round).
	Far: a clear ray out to longRange in the narrow longAngle cone straight ahead, noticed over a beat that grows with
	the distance (`noticeDelay`) unless it is his target. Never someone hiding, in their grace or in the truck's box.
	Beside him (behaviours design §10.1): `peripheral`, a clear ray within PERIPHERAL_RANGE outside the front cone but
	within PERIPHERAL_ANGLE, noticed over `glanceDelay`. Behind him (§11.7): `behind`, a clear ray within FELT_RANGE
	past the peripheral zone (his blind back), felt over `feltDelay`. His head turned (§10.2): `toward`, who he sees
	down the cone his head looks along; `beside`, whether a point is outside his front cone (a noise there turns his
	head).

	The rays are the caller's (each Glimpse says whether its line was clear). Pure.

	@class OccupantSightUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local NpcSenseRules = require(ServerScriptService.Features.Npc.Rules.NpcSenseRules)
local OccupantMenaceFormulas = require(ServerScriptService.Features.Occupant.Utils.OccupantMenaceFormulas)

type Mind = OccupantTypes.Mind
type Senses = OccupantTypes.Senses
type Glimpse = OccupantTypes.Glimpse

local Sight = {}

local function graced(mind: Mind, userId: number, now: number): boolean
	local untilTime = mind.grace[userId]
	return untilTime ~= nil and now < untilTime
end

local function inBox(point: Vector3, box: OccupantTypes.Zone): boolean
	return point.X >= box.min.X
		and point.X <= box.max.X
		and point.Y >= box.min.Y
		and point.Y <= box.max.Y
		and point.Z >= box.min.Z
		and point.Z <= box.max.Z
end

--[=[
	Whether `point` is in `zone`'s box or any of its `more` boxes (the yard and car park); false without a zone. The one
	zone test of all his senses (OccupantMindUtils.inZone is this).
]=]
function Sight.inZone(point: Vector3, zone: OccupantTypes.Zone?): boolean
	if zone == nil then
		return false
	end
	if inBox(point, zone) then
		return true
	end
	if zone.more ~= nil then
		for _, box in zone.more do
			if inBox(point, box) then
				return true
			end
		end
	end
	return false
end

export type Sight = "near" | "far"

-- His chase or search target: seen all round (near), and down his long cone without a notice beat (far).
local function tracked(mind: Mind, userId: number): boolean
	return userId == mind.target and (mind.mode == "chase" or mind.mode == "search")
end

--[=[
	How he sees `glimpse` this think: "near" (a clear ray within sightRange in the sightAngle cone; his chase or search
	target all round), "far" (a clear ray out to longRange in the narrow longAngle cone straight ahead), or nil. Never
	someone hiding, in their grace or in the safe zone.
]=]
function Sight.sightOf(mind: Mind, senses: Senses, glimpse: Glimpse): Sight?
	if
		not glimpse.clear
		or glimpse.hidden == true
		or graced(mind, glimpse.userId, senses.now)
		or Sight.inZone(glimpse.position, senses.zone)
	then
		return nil
	end
	local distance = (glimpse.position - senses.position).Magnitude
	local level = Vector3.new(glimpse.position.X, senses.position.Y, glimpse.position.Z)
	local angle = if tracked(mind, glimpse.userId) then 360 else senses.sightAngle
	if
		distance <= senses.sightRange
		and NpcSenseRules.inSight(senses.position, senses.look, level, senses.sightRange, angle)
	then
		return "near"
	end
	local longRange = senses.longRange
	local longAngle = senses.longAngle
	if
		longRange ~= nil
		and longAngle ~= nil
		and distance <= longRange
		and NpcSenseRules.inSight(senses.position, senses.look, level, longRange, longAngle)
	then
		return "far"
	end
	return nil
end

local function nearestFirst(list: { Glimpse }, senses: Senses)
	table.sort(list, function(a, b)
		local distanceA = (a.position - senses.position).Magnitude
		local distanceB = (b.position - senses.position).Magnitude
		if distanceA ~= distanceB then
			return distanceA < distanceB
		end
		return a.userId < b.userId
	end)
end

--[=[
	The players he sees this think, nearest first (`sightOf`): near, or far when it is his chase or search target (a
	hider he saw go in is stared at instead: Senses.hiders).
]=]
function Sight.visible(mind: Mind, senses: Senses): { Glimpse }
	local list: { Glimpse } = {}
	for _, glimpse in senses.players do
		local sight = Sight.sightOf(mind, senses, glimpse)
		if sight == "near" or (sight == "far" and tracked(mind, glimpse.userId)) then
			table.insert(list, glimpse)
		end
	end
	nearestFirst(list, senses)
	return list
end

--[=[
	The players far down his long cone he has yet to notice (not his target), nearest first.
]=]
function Sight.distant(mind: Mind, senses: Senses): { Glimpse }
	local list: { Glimpse } = {}
	for _, glimpse in senses.players do
		if Sight.sightOf(mind, senses, glimpse) == "far" and not tracked(mind, glimpse.userId) then
			table.insert(list, glimpse)
		end
	end
	nearestFirst(list, senses)
	return list
end

--[=[
	Whether he sees `userId` at all this think, near or far (Hide's witness).
]=]
function Sight.sees(mind: Mind, senses: Senses, userId: number): boolean
	for _, glimpse in senses.players do
		if glimpse.userId == userId and Sight.sightOf(mind, senses, glimpse) ~= nil then
			return true
		end
	end
	return false
end

-- Eligible to be seen at all: a clear ray, not hiding, not in their grace, not in the truck's box.
local function eligible(mind: Mind, senses: Senses, glimpse: Glimpse): boolean
	return glimpse.clear
		and glimpse.hidden ~= true
		and not graced(mind, glimpse.userId, senses.now)
		and not Sight.inZone(glimpse.position, senses.zone)
end

local function level(senses: Senses, point: Vector3): Vector3
	return Vector3.new(point.X, senses.position.Y, point.Z)
end

--[=[
	The players in his peripheral zone this think, nearest first: a clear ray within PERIPHERAL_RANGE, inside
	PERIPHERAL_ANGLE of his heading but not seen in his front cone (`sightOf` is not "near"). Never someone hiding, in
	their grace or in the safe zone.
]=]
function Sight.peripheral(mind: Mind, senses: Senses): { Glimpse }
	local list: { Glimpse } = {}
	for _, glimpse in senses.players do
		if
			eligible(mind, senses, glimpse)
			and Sight.sightOf(mind, senses, glimpse) ~= "near"
			and (glimpse.position - senses.position).Magnitude <= OccupantConstants.PERIPHERAL_RANGE
			and NpcSenseRules.inSight(
				senses.position,
				senses.look,
				level(senses, glimpse.position),
				OccupantConstants.PERIPHERAL_RANGE,
				OccupantConstants.PERIPHERAL_ANGLE
			)
		then
			table.insert(list, glimpse)
		end
	end
	nearestFirst(list, senses)
	return list
end

--[=[
	The players right behind him this think, nearest first (the felt presence, behaviours design §11.7): a clear ray
	within FELT_RANGE, past PERIPHERAL_ANGLE of his heading (his blind back). Never someone hiding, in their grace or in
	the safe zone.
]=]
function Sight.behind(mind: Mind, senses: Senses): { Glimpse }
	local list: { Glimpse } = {}
	for _, glimpse in senses.players do
		if
			eligible(mind, senses, glimpse)
			and Sight.sightOf(mind, senses, glimpse) == nil
			and (glimpse.position - senses.position).Magnitude <= OccupantConstants.FELT_RANGE
			and not NpcSenseRules.inSight(
				senses.position,
				senses.look,
				level(senses, glimpse.position),
				math.huge,
				OccupantConstants.PERIPHERAL_ANGLE
			)
		then
			table.insert(list, glimpse)
		end
	end
	nearestFirst(list, senses)
	return list
end

--[=[
	Seconds someone must linger behind him before he feels them: FELT_SECONDS, GLANCE_CROUCH times that `crouched`.
]=]
function Sight.feltDelay(crouched: boolean): number
	return if crouched
		then OccupantConstants.FELT_SECONDS * OccupantConstants.GLANCE_CROUCH
		else OccupantConstants.FELT_SECONDS
end

--[=[
	Seconds in his peripheral zone before he notices someone `distance` studs away: GLANCE_SECONDS.min at his side,
	rising to GLANCE_SECONDS.max at PERIPHERAL_RANGE; GLANCE_CROUCH times that `crouched`.
]=]
function Sight.glanceDelay(distance: number, crouched: boolean): number
	local t = math.clamp(distance / OccupantConstants.PERIPHERAL_RANGE, 0, 1)
	local seconds = OccupantMenaceFormulas.within(OccupantConstants.GLANCE_SECONDS, t)
	return if crouched then seconds * OccupantConstants.GLANCE_CROUCH else seconds
end

--[=[
	Whether `point` is outside his front cone (beside or behind him): a noise from there turns his head.
]=]
function Sight.beside(senses: Senses, point: Vector3): boolean
	return not NpcSenseRules.inSight(senses.position, senses.look, level(senses, point), math.huge, senses.sightAngle)
end

--[=[
	The players he sees down the cone his head is turned to (toward `point`), nearest first: a clear ray within
	sightRange, inside sightAngle of the direction to `point`. Never someone hiding, in their grace or in the safe zone.
]=]
function Sight.toward(mind: Mind, senses: Senses, point: Vector3): { Glimpse }
	local flat = level(senses, point) - senses.position
	local look = if flat.Magnitude > 1e-3 then flat.Unit else senses.look
	local list: { Glimpse } = {}
	for _, glimpse in senses.players do
		if
			eligible(mind, senses, glimpse)
			and (glimpse.position - senses.position).Magnitude <= senses.sightRange
			and NpcSenseRules.inSight(
				senses.position,
				look,
				level(senses, glimpse.position),
				senses.sightRange,
				senses.sightAngle
			)
		then
			table.insert(list, glimpse)
		end
	end
	nearestFirst(list, senses)
	return list
end

--[=[
	Seconds of steady sight he needs to notice someone `distance` studs away down his long cone: NOTICE_SECONDS.min at
	his near sight's edge, rising to NOTICE_SECONDS.max at LONG_SIGHT_RANGE.
]=]
function Sight.noticeDelay(distance: number): number
	local span = OccupantConstants.LONG_SIGHT_RANGE - OccupantConstants.SIGHT_RANGE
	local t = if span > 0 then math.clamp((distance - OccupantConstants.SIGHT_RANGE) / span, 0, 1) else 1
	return OccupantMenaceFormulas.within(OccupantConstants.NOTICE_SECONDS, t)
end

return Sight
