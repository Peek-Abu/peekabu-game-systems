--!strict
--[=[
	DepotClerkRules: the Supply Counter clerk's decisions (owner 11-11, "Stamp & Stack"; DepotSpotConstants.CLERK).
	Which employee clerks today (one a day, from the server's day number, so every client shows the same one), when the
	clerk waves at a player, how tall the parcel on the counter is, and the parcel's hop after each stamp.

	@class DepotClerkRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)

local CLERK = DepotSpotConstants.CLERK
local HOP = CLERK.HOP

local DepotClerkRules = {}

--[=[
	The day number of `serverTime` (seconds, Workspace:GetServerTimeNow()).
]=]
function DepotClerkRules.dayOf(serverTime: number): number
	return math.floor(serverTime / CLERK.DAY_SECONDS)
end

--[=[
	Today's clerk: the employees (`names`, sorted, EmployeeRegistry.names) in turn, one a day; nil without any.
]=]
function DepotClerkRules.clerkFor(day: number, names: { string }): string?
	if #names == 0 then
		return nil
	end
	return names[(day % #names) + 1]
end

--[=[
	Whether the clerk waves at a player `distance` studs away at `now`, the last wave at `lastAt` (nil: none yet).
]=]
function DepotClerkRules.greets(distance: number, lastAt: number?, now: number): boolean
	if distance > CLERK.GREET.RADIUS then
		return false
	end
	return lastAt == nil or now - lastAt >= CLERK.GREET.COOLDOWN
end

--[=[
	The parcel's height: from the counter top (`counterY`) up to the stamp's face at the contact (`faceY`), so the stamp
	lands on it whoever the clerk is, kept within the parcel's limits.
]=]
function DepotClerkRules.parcelHeight(faceY: number, counterY: number): number
	return math.clamp(faceY - counterY, CLERK.PARCEL.MIN_HEIGHT, CLERK.PARCEL.MAX_HEIGHT)
end

--[=[
	The parcel's hop `t` seconds after the stamp lifts off: how far it is off the counter (studs) and its height scale
	(a squash when it lands).
]=]
function DepotClerkRules.hop(t: number): (number, number)
	local u = t - HOP.DELAY
	if u <= 0 then
		return 0, 1
	elseif u < HOP.SECONDS then
		return HOP.APEX * math.sin(math.pi * u / HOP.SECONDS), 1
	elseif u < HOP.SECONDS + HOP.SQUASH_SECONDS then
		return 0, HOP.SQUASH
	end
	return 0, 1
end

--[=[
	Whether the hop `t` seconds after the lift is over (the parcel has settled).
]=]
function DepotClerkRules.hopDone(t: number): boolean
	return t > HOP.DELAY + HOP.SECONDS + HOP.SQUASH_SECONDS
end

return DepotClerkRules
