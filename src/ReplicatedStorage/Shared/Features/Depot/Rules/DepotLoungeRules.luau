--!strict
--[=[
	DepotLoungeRules: when the break room's sleepy employee wakes up to wave (owner 11-11, ideas sheet #4: Cappy dozing
	on the sofa; DepotSpotConstants.LOUNGE).

	@class DepotLoungeRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)

local LOUNGE = DepotSpotConstants.LOUNGE

local DepotLoungeRules = {}

--[=[
	Whether he wakes and waves now: the player (`distance` studs away) just walked up (`wasNear`: already near last
	frame) and the last wave (`lastAt`, nil: none yet) is at least COOLDOWN seconds before `now`.
]=]
function DepotLoungeRules.wakes(distance: number, wasNear: boolean, lastAt: number?, now: number): boolean
	if distance > LOUNGE.WAKE_RADIUS or wasNear then
		return false
	end
	return lastAt == nil or now - lastAt >= LOUNGE.COOLDOWN
end

return DepotLoungeRules
