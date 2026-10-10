--!strict
--[=[
	DepotContractUtils: tonight's contract and the words around it (Cleanup Crew spec §2, §3 steps 1-3).
	`tonight` picks the contract for the current UTC day, so every depot server shows the same job all day;
	`resolve` turns a contract id that rode a teleport (untrusted: teleport data travels through the client)
	back into a contract, falling back to the first; the rest build the contract board's lines and the drive
	and arrival cards. Pure.

	@class DepotContractUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

function DepotContractUtils.boardLines(contract: Contract, quota: number): { string }
	return {
		"TONIGHT'S CONTRACT",
		contract.client,
		contract.job,
		`Load {quota} of trash on the truck. Salvage earns a finder's fee.`,
		contract.note,
		"Stand in a truck bed to join a crew (1-4 players).",
	}
end

function DepotContractUtils.driveCard(contract: Contract): DepotTypes.CardMessage
	return { kind = "drive", title = "On the road", body = `Heading to {contract.client}` }
end

function DepotContractUtils.arrivalCard(contract: Contract, quota: number): DepotTypes.CardMessage
	return {
		kind = "arrival",
		title = contract.client,
		body = `{contract.job} Clear {quota} of trash. {contract.note}`,
	}
end

return DepotContractUtils
