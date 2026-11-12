--!strict
--[=[
	DepotClerkRules: the Supply Counter clerk's decisions (owner 11-11, "Stamp & Stack"; DepotSpotConstants.CLERK).
	The clerk is always Pippa (she ran the front desk before night shifts). When she breaks from her idle into a fidget
	and which one (the stamp most of the time), when she waves at a player, how tall the parcel on the counter is, and
	the parcel's hop after each stamp.

	@class DepotClerkRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)

local CLERK = DepotSpotConstants.CLERK
local HOP = CLERK.HOP

local DepotClerkRules = {}

--[=[
	When the clerk next breaks from the idle into a fidget: `roll` (0..1) of the way from FIDGET_MIN to FIDGET_MAX
	seconds after `now`.
]=]
function DepotClerkRules.nextFidgetAt(now: number, roll: number): number
	return now + CLERK.FIDGET_MIN + (CLERK.FIDGET_MAX - CLERK.FIDGET_MIN) * math.clamp(roll, 0, 1)
end

--[=[
	Which fidget the clerk plays (CLERK.FIDGETS by weight, `roll` 0..1), never a one-off (`again` false) twice in a row
	after `last`: then the next one in the list instead.
]=]
function DepotClerkRules.pickFidget(roll: number, last: string?): string
	local fidgets = CLERK.FIDGETS
	local total = 0
	for _, entry in fidgets do
		total += entry.weight
	end
	local at = math.clamp(roll, 0, 0.999999) * total
	local index = #fidgets
	for i, entry in fidgets do
		if at < entry.weight then
			index = i
			break
		end
		at -= entry.weight
	end
	local picked = fidgets[index]
	if picked.name == last and not picked.again then
		picked = fidgets[(index % #fidgets) + 1]
	end
	return picked.name
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
