--!strict
--[=[
	DepotContractUtils: tonight's contract and the words around it (Cleanup Crew spec §2, §3 steps 1-3).
	`tonight` picks the contract for the current UTC day, so every depot server shows the same job all day;
	`resolve` turns a contract id that rode a teleport (untrusted: teleport data travels through the client)
	back into a contract, falling back to the first; the rest build the contract board's attributes and the drive
	and arrival cards. Pure.

	@class DepotContractUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)

type Contract = DepotTypes.Contract

local DAY_SECONDS = 86400

local DepotContractUtils = {}

function DepotContractUtils.tonight(contracts: { Contract }, epochSeconds: number): Contract
	assert(#contracts > 0, "DepotContractUtils.tonight: no contracts")
	local day = math.floor(epochSeconds / DAY_SECONDS)
	return contracts[day % #contracts + 1]
end

function DepotContractUtils.resolve(contracts: { Contract }, id: unknown): Contract
	assert(#contracts > 0, "DepotContractUtils.resolve: no contracts")
	if type(id) == "string" then
		for _, contract in contracts do
			if contract.id == id then
				return contract
			end
		end
	end
	return contracts[1]
end

--[=[
	A truck number that rode a teleport (untrusted): a whole number 1..max, else nil.
]=]
function DepotContractUtils.truckOf(value: unknown, max: number): number?
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 then
		return nil
	end
	if value < 1 or value > max then
		return nil
	end
	return value
end

-- The contract board's shell attributes (M3b world UI): the client draws the work order from them.
function DepotContractUtils.boardAttributes(contract: Contract): { [string]: string }
	local keys = DepotConstants.CONTRACT_KEYS
	return {
		[keys.id] = contract.id,
		[keys.client] = contract.client,
		[keys.job] = contract.job,
	}
end

-- The drive card: tonight's contract and the truck that left (nil: unknown, sent as 0).
function DepotContractUtils.driveCard(contract: Contract, truck: number?): DepotTypes.CardMessage
	return {
		kind = "drive",
		client = contract.client,
		job = contract.job,
		note = contract.note,
		quota = 0,
		truck = truck or 0,
	}
end

-- The arrival card: the crew's contract, the quota to clear and the truck they rode (nil: unknown, sent as 0).
function DepotContractUtils.arrivalCard(contract: Contract, quota: number, truck: number?): DepotTypes.CardMessage
	return {
		kind = "arrival",
		client = contract.client,
		job = contract.job,
		note = contract.note,
		quota = quota,
		truck = truck or 0,
	}
end

return DepotContractUtils
