local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotContractUtils = require(script.Parent.DepotContractUtils)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

local CONTRACTS = {
	{ id = "a", client = "Alpha Ltd.", job = "Clear it.", note = "Quiet." },
	{ id = "b", client = "Beta Ltd.", job = "Clear more.", note = "Loud." },
	{ id = "c", client = "Gamma Ltd.", job = "Clear all.", note = "Odd." },
}
local DAY = 86400

return function()
	describe("tonight", function()
		it("keeps one contract for a whole UTC day", function()
			expect(DepotContractUtils.tonight(CONTRACTS, 0).id).to.equal("a")
			expect(DepotContractUtils.tonight(CONTRACTS, DAY - 1).id).to.equal("a")
		end)

		it("moves to the next contract each day and wraps around", function()
			expect(DepotContractUtils.tonight(CONTRACTS, DAY).id).to.equal("b")
			expect(DepotContractUtils.tonight(CONTRACTS, 2 * DAY + 5).id).to.equal("c")
			expect(DepotContractUtils.tonight(CONTRACTS, 3 * DAY).id).to.equal("a")
		end)

		it("always finds a contract in the authored list", function()
			local contract = DepotContractUtils.tonight(DepotConstants.CONTRACTS, os.time())
			expect(type(contract.id)).to.equal("string")
			expect(#DepotConstants.CONTRACTS >= 1).to.equal(true)
		end)

		it("refuses an empty list", function()
			expect(function()
				DepotContractUtils.tonight({}, 0)
			end).to.throw()
		end)
	end)

	describe("resolve", function()
		it("finds a contract by id", function()
			expect(DepotContractUtils.resolve(CONTRACTS, "b").id).to.equal("b")
		end)

		it("falls back to the first contract for a missing, unknown or malformed id", function()
			expect(DepotContractUtils.resolve(CONTRACTS, nil).id).to.equal("a")
			for _, bad in { "zzz", 42, true, string.rep("b", 5000) } do
				expect(DepotContractUtils.resolve(CONTRACTS, bad).id).to.equal("a")
			end
		end)
	end)

	describe("words", function()
		it("puts tonight's contract on the board's attributes", function()
			local keys = DepotConstants.CONTRACT_KEYS
			local attributes = DepotContractUtils.boardAttributes(CONTRACTS[2])
			expect(attributes[keys.id]).to.equal("b")
			expect(attributes[keys.client]).to.equal("Beta Ltd.")
			expect(attributes[keys.job]).to.equal("Clear more.")
		end)

		it("builds the drive card with the departing truck", function()
			local card = DepotContractUtils.driveCard(CONTRACTS[1], 3)
			expect(card.kind).to.equal("drive")
			expect(card.client).to.equal("Alpha Ltd.")
			expect(card.job).to.equal("Clear it.")
			expect(card.note).to.equal("Quiet.")
			expect(card.quota).to.equal(0)
			expect(card.truck).to.equal(3)
			expect(DepotContractUtils.driveCard(CONTRACTS[1]).truck).to.equal(0)
		end)

		it("builds the arrival card with the quota and the truck", function()
			local card = DepotContractUtils.arrivalCard(CONTRACTS[3], 350, 2)
			expect(card.kind).to.equal("arrival")
			expect(card.client).to.equal("Gamma Ltd.")
			expect(card.job).to.equal("Clear all.")
			expect(card.note).to.equal("Odd.")
			expect(card.quota).to.equal(350)
			expect(card.truck).to.equal(2)
			expect(DepotContractUtils.arrivalCard(CONTRACTS[3], 350).truck).to.equal(0)
		end)
	end)

	describe("truckOf", function()
		it("accepts only a whole truck number on the layout", function()
			expect(DepotContractUtils.truckOf(2, 4)).to.equal(2)
			expect(DepotContractUtils.truckOf(4, 4)).to.equal(4)
			expect(DepotContractUtils.truckOf(9, 4)).to.equal(nil)
			expect(DepotContractUtils.truckOf(0, 4)).to.equal(nil)
			expect(DepotContractUtils.truckOf(2.5, 4)).to.equal(nil)
			expect(DepotContractUtils.truckOf("2", 4)).to.equal(nil)
			expect(DepotContractUtils.truckOf(0 / 0, 4)).to.equal(nil)
			expect(DepotContractUtils.truckOf(nil, 4)).to.equal(nil)
		end)
	end)
end
