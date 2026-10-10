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
		it("puts the client, the job, the quota and the note on the board", function()
			local lines = DepotContractUtils.boardLines(CONTRACTS[2], 350)
			expect(lines[1]).to.equal("TONIGHT'S CONTRACT")
			expect(lines[2]).to.equal("Beta Ltd.")
			expect(lines[3]).to.equal("Clear more.")
			expect(lines[4]).to.equal("Load 350 of trash on the truck. Salvage earns a finder's fee.")
			expect(lines[5]).to.equal("Loud.")
			expect(lines[6]).to.equal("Stand in a truck bed to join a crew (1-4 players).")
		end)

		it("builds the drive card", function()
			local card = DepotContractUtils.driveCard(CONTRACTS[1])
			expect(card.kind).to.equal("drive")
			expect(card.title).to.equal("On the road")
			expect(card.body).to.equal("Heading to Alpha Ltd.")
		end)

		it("builds the arrival card", function()
			local card = DepotContractUtils.arrivalCard(CONTRACTS[3], 350)
			expect(card.kind).to.equal("arrival")
			expect(card.title).to.equal("Gamma Ltd.")
			expect(card.body).to.equal("Clear all. Clear 350 of trash. Odd.")
		end)
	end)
end
