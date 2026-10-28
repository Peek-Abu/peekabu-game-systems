--!strict
--[=[
	DepotPlaceUtils: the place-role table and who places spawning players. `roles`: the depot and shift PlaceIds
	as a frozen role table for Queue's registry; while either id is unknown (0) both stay placeholders, so the one
	server plays both roles. `depotOwnsSpawns`: true only in a hub-only server, where the depot (not Shift's trip)
	picks the spawn point. Pure.

	@class DepotPlaceUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)

local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

local DepotPlaceUtils = {}

function DepotPlaceUtils.roles(hubPlaceId: number, shiftPlaceId: number): { [string]: number }
	local placeholder = QueueConstants.PLACEHOLDER_PLACE_ID
	if hubPlaceId == placeholder or shiftPlaceId == placeholder then
		return table.freeze({
			[DepotConstants.ROLE_DEPOT] = placeholder,
			[DepotConstants.ROLE_SHIFT] = placeholder,
		})
	end
	if hubPlaceId == shiftPlaceId then
		error("HUB_PLACE_ID and SHIFT_PLACE_ID must be two different places (both are " .. tostring(hubPlaceId) .. ")")
	end
	return table.freeze({
		[DepotConstants.ROLE_DEPOT] = hubPlaceId,
		[DepotConstants.ROLE_SHIFT] = shiftPlaceId,
	})
end

-- True only when this server runs the depot and not the shift; otherwise Shift's trip owns the spawn resolver.
function DepotPlaceUtils.depotOwnsSpawns(runsDepot: boolean, runsShift: boolean): boolean
	return runsDepot and not runsShift
end

-- Local servers host both roles; native position separates hub bystanders from the active crew.
function DepotPlaceUtils.canPunchTimecard(
	runsDepot: boolean,
	phase: ShiftTypes.ShiftPhase,
	departed: boolean,
	position: Vector3?,
	floor: DepotTypes.Rect,
	height: number
): boolean
	if not runsDepot or position == nil or (phase ~= "lobby" and departed) then
		return false
	end
	return position.X >= floor.minX
		and position.X <= floor.maxX
		and position.Z >= floor.minZ
		and position.Z <= floor.maxZ
		and position.Y >= 0
		and position.Y <= height
end
return DepotPlaceUtils
