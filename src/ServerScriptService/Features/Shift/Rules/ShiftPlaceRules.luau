--!strict
--[=[
	ShiftPlaceRules: which Shift servers are stranded. A live public server of the shift place (someone reached it
	without a party; reserved party servers are Queue's) has no crew to serve, so every player there is sent to the
	hub. Studio (local mode), the hub and a place with no role are never stranded. Pure.

	@class ShiftPlaceRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)

local ShiftPlaceRules = {}

-- True only for a live, public (not reserved) server whose place role is the shift.
function ShiftPlaceRules.isStrandedServer(mode: QueueTypes.Mode, role: string?, reserved: boolean): boolean
	return mode == "live" and role == DepotConstants.ROLE_SHIFT and not reserved
end

return ShiftPlaceRules
