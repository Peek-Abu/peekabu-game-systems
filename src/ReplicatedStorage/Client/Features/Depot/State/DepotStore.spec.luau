local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotStore = require(script.Parent.DepotStore)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

local DRIVE = DepotConstants.DRIVE_CARD_SECONDS
local ARRIVAL = DepotConstants.ARRIVAL_CARD_SECONDS

local function message(kind, client)
	return {
		kind = kind,
		client = client or "Harlow & Finch Ltd.",
		job = "Clear it.",
		note = "Quiet.",
		quota = if kind == "arrival" then 350 else 0,
		truck = 2,
	}
end

return function()
	afterEach(function()
		DepotStore.clear()
	end)

	it("shows a card for its kind's time, with every field the server sent", function()
		expect(DepotStore.show(message("drive"), 10)).to.equal(true)
		local card = DepotStore.card()
		expect(card.kind).to.equal("drive")
		expect(card.client).to.equal("Harlow & Finch Ltd.")
		expect(card.job).to.equal("Clear it.")
		expect(card.note).to.equal("Quiet.")
		expect(card.quota).to.equal(0)
		expect(card.truck).to.equal(2)
		expect(card.expiresAt).to.equal(10 + DRIVE)
	end)

	it("ignores an unknown kind", function()
		expect(DepotStore.show(message("party"), 0)).to.equal(false)
		expect(DepotStore.card()).to.equal(nil)
	end)

	it("keeps the card until its time is up, then clears it", function()
		DepotStore.show(message("arrival"), 10)
		DepotStore.expire(10 + ARRIVAL - 0.1)
		expect(DepotStore.card() ~= nil).to.equal(true)
		DepotStore.expire(10 + ARRIVAL)
		expect(DepotStore.card()).to.equal(nil)
	end)

	it("queues a card that arrives while another shows, then shows it in full", function()
		DepotStore.show(message("drive"), 10)
		DepotStore.show(message("arrival"), 11)
		expect(DepotStore.card().kind).to.equal("drive")
		DepotStore.expire(10 + DRIVE)
		local card = DepotStore.card()
		expect(card.kind).to.equal("arrival")
		expect(card.quota).to.equal(350)
		expect(card.expiresAt).to.equal(10 + DRIVE + ARRIVAL)
	end)

	it("drops the oldest queued card past the limit", function()
		DepotStore.show(message("drive", "first"), 0)
		for index = 1, DepotConstants.MAX_QUEUED_CARDS + 1 do
			DepotStore.show(message("arrival", tostring(index)), 1)
		end
		DepotStore.expire(DRIVE)
		expect(DepotStore.card().client).to.equal("2")
	end)

	it("replaces a card whose time has passed without waiting", function()
		DepotStore.show(message("drive", "old"), 0)
		DepotStore.show(message("arrival", "new"), DRIVE + 1)
		expect(DepotStore.card().client).to.equal("new")
	end)

	describe("board and last shift", function()
		it("opens the board on a known contract and falls back to the first for an unknown one", function()
			local id = DepotConstants.CONTRACTS[2].id
			expect(DepotStore.openBoard(id)).to.equal(id)
			expect(DepotStore.board()).to.equal(id)
			expect(DepotStore.openBoard("nope")).to.equal(DepotConstants.CONTRACTS[1].id)
		end)

		it("closes the board without forgetting the last shift", function()
			DepotStore.openBoard(DepotConstants.CONTRACTS[1].id)
			DepotStore.setLastShift({
				cleared = 1,
				quota = 350,
				bonus = 0,
				catches = 0,
				salvage = 0,
				offered = 0,
				quotaMet = false,
				rating = "needsImprovement",
				truck = 1,
			})
			DepotStore.closeBoard()
			expect(DepotStore.board()).to.equal(nil)
			expect(DepotStore.lastShift().cleared).to.equal(1)
			DepotStore.clear()
		end)

		it("keeps the last shift until cleared", function()
			local last = {
				cleared = 362,
				quota = 350,
				bonus = 215,
				catches = 2,
				salvage = 6,
				offered = 9,
				quotaMet = true,
				rating = "exceeds",
				truck = 2,
			}
			DepotStore.setLastShift(last)
			expect(DepotStore.lastShift().cleared).to.equal(362)
			DepotStore.clear()
			expect(DepotStore.lastShift()).to.equal(nil)
			expect(DepotStore.board()).to.equal(nil)
		end)
	end)
end
