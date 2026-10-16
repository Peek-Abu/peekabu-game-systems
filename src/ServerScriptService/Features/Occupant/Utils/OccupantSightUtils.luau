--!strict
--[=[
	OccupantSightUtils: what the Manager sees (docs/superpowers/specs/2026-10-16-cleanup-crew-manager-chase-tuning-
	design.md §2). Near: a clear ray within sightRange in the sightAngle cone (his chase or search target all round).
	Far: a clear ray out to longRange in the narrow longAngle cone straight ahead, noticed over a beat that grows with
	the distance (`noticeDelay`) unless it is his target. Never someone hiding, in their grace or in the truck's box.

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

local function inZone(point: Vector3, zone: OccupantTypes.Zone): boolean
	return point.X >= zone.min.X
		and point.X <= zone.max.X
		and point.Y >= zone.min.Y
		and point.Y <= zone.max.Y
		and point.Z >= zone.min.Z
		and point.Z <= zone.max.Z
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
		or inZone(glimpse.position, senses.zone)
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
