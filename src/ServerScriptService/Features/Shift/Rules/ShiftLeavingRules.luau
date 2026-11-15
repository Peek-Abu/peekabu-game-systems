--!strict
--[=[
	ShiftLeavingRules: what the load screen shows in the place being left, from the teleport Queue decided
	(QueueServiceServer.leaving: the destination role and the trip's payload). A trip to anything but the shift role is a
	trip home (the welcome card's look). A trip to the shift names the contract's client (the payload's contract id among
	its map's jobs, DepotContractUtils.resolve: an unknown id is the first job), the truck (DepotContractUtils.truckOf:
	nil unless a real truck number) and the map (DepotMapRules.parse); a training trip names the training room on the
	Office, as its arrival slip does. The payload is untrusted (it rides the teleport) and only ever drawn. Pure.

	@class ShiftLeavingRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotMapRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotMapRules)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local DepotContractUtils = require(ServerScriptService.Features.Depot.Utils.DepotContractUtils)

local ShiftLeavingRules = {}

function ShiftLeavingRules.view(role: string, payload: QueueTypes.QueuePayload): ShiftTypes.TransitLeaving
	if role ~= DepotConstants.ROLE_SHIFT then
		return { home = true }
	end
	local truck = DepotContractUtils.truckOf(payload.truck, DepotConstants.MAX_TRUCKS)
	if payload[TrainingConstants.MODE_KEY] == TrainingConstants.MODE then
		return {
			home = false,
			client = TrainingConstants.CONTRACT.client,
			truck = truck,
			map = DepotMapRules.parse(nil),
		}
	end
	local map: ShiftTypes.MapId = DepotMapRules.parse(payload.map)
	local contract = DepotContractUtils.resolve(DepotMapRules.contractsOf(map), payload.contract)
	return { home = false, client = contract.client, truck = truck, map = map }
end

return ShiftLeavingRules
