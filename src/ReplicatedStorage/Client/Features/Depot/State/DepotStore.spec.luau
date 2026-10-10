local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotStore = require(script.Parent.DepotStore)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

local DRIVE = DepotConstants.DRIVE_CARD_SECONDS
local ARRIVAL = DepotConstants.ARRIVAL_CARD_SECONDS

return function()
	afterEach(function()
		DepotStore.clear()
	end)

	it("shows a card for its kind's time", function()
		expect(DepotStore.show("drive", "On the road", "Heading out", 10)).to.equal(true)
		local card = DepotStore.card()
		expect(card.kind).to.equal("drive")
		expect(card.title).to.equal("On the road")
		expect(card.body).to.equal("Heading out")
		expect(card.expiresAt).to.equal(10 + DRIVE)
	end)

	it("ignores an unknown kind", function()
		expect(DepotStore.show("party", "x", "y", 0)).to.equal(false)
		expect(DepotStore.card()).to.equal(nil)
	end)

	it("keeps the card until its time is up, then clears it", function()
		DepotStore.show("arrival", "Harlow & Finch Ltd.", "Clear it.", 10)
		DepotStore.expire(10 + ARRIVAL - 0.1)
		expect(DepotStore.card() ~= nil).to.equal(true)
		DepotStore.expire(10 + ARRIVAL)
		expect(DepotStore.card()).to.equal(nil)
	end)

	it("queues a card that arrives while another shows, then shows it in full", function()
		DepotStore.show("drive", "On the road", "Heading out", 10)
		DepotStore.show("arrival", "Harlow & Finch Ltd.", "Clear it.", 11)
		expect(DepotStore.card().kind).to.equal("drive")
		DepotStore.expire(10 + DRIVE)
		local card = DepotStore.card()
		expect(card.kind).to.equal("arrival")
		expect(card.expiresAt).to.equal(10 + DRIVE + ARRIVAL)
	end)

	it("drops the oldest queued card past the limit", function()
		DepotStore.show("drive", "first", "", 0)
		for index = 1, DepotConstants.MAX_QUEUED_CARDS + 1 do
			DepotStore.show("arrival", tostring(index), "", 1)
		end
		DepotStore.expire(DRIVE)
		expect(DepotStore.card().title).to.equal("2")
	end)

	it("replaces a card whose time has passed without waiting", function()
		DepotStore.show("drive", "old", "", 0)
		DepotStore.show("arrival", "new", "", DRIVE + 1)
		expect(DepotStore.card().title).to.equal("new")
	end)
end
