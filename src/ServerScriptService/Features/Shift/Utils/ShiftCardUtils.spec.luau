local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftCardUtils = require(script.Parent.ShiftCardUtils)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueTeleportRules = require(ServerScriptService.Features.Queue.Rules.QueueTeleportRules)

local INFO = { client = "Harlow & Finch Ltd.", shift = 2 }

local function review(crewSize)
	local crew = {}
	for index = 1, crewSize or 2 do
		table.insert(crew, { name = `Crew{index}`, banked = 100 - index, piles = index, salvage = 0 })
	end
	return {
		outcome = "clockout",
		quota = 350,
		cleared = 380,
		bonus = 95,
		salvage = 3,
		piles = 12,
		catches = 1,
		offered = 9,
		quotaMet = true,
		crew = crew,
		awards = { { title = "Top Hauler", name = "Crew1" }, { title = "Dust Devil", name = "Crew2" } },
	}
end

-- What the depot sees: the payload after the teleport's JSON round trip.
local function wire(payload)
	return HttpService:JSONDecode(HttpService:JSONEncode(payload))
end

local function payload()
	return wire(ShiftCardUtils.encode(review(2), INFO))
end

return function()
	describe("encode", function()
		it("fits the Queue's payload limits", function()
			local clean, reason = QueueTeleportRules.payload(ShiftCardUtils.encode(review(4), INFO))
			expect(reason).to.equal(nil)
			expect(clean ~= nil).to.equal(true)
		end)

		it("keeps at most four crew lines and three awards", function()
			local big = review(6)
			table.insert(big.awards, { title = "Treasure Hunter", name = "Crew3" })
			table.insert(big.awards, { title = "Extra", name = "Crew4" })
			local card = ShiftCardUtils.decode(wire(ShiftCardUtils.encode(big, INFO)))
			expect(#card.crew).to.equal(4)
			expect(#card.awards).to.equal(3)
		end)
	end)

	describe("decode", function()
		it("round-trips a review through teleport data", function()
			local card = ShiftCardUtils.decode(payload())
			expect(card.client).to.equal("Harlow & Finch Ltd.")
			expect(card.shift).to.equal(2)
			expect(card.outcome).to.equal("clockout")
			expect(card.quota).to.equal(350)
			expect(card.cleared).to.equal(380)
			expect(card.bonus).to.equal(95)
			expect(card.salvage).to.equal(3)
			expect(card.piles).to.equal(12)
			expect(card.catches).to.equal(1)
			expect(card.quotaMet).to.equal(true)
			expect(#card.crew).to.equal(2)
			expect(card.crew[1].name).to.equal("Crew1")
			expect(card.crew[1].banked).to.equal(99)
			expect(card.awards[2].title).to.equal("Dust Devil")
			expect(card.awards[2].name).to.equal("Crew2")
		end)

		it("cuts a very long name", function()
			local long = review(1)
			long.crew[1].name = string.rep("x", 5000)
			local card = ShiftCardUtils.decode(wire(ShiftCardUtils.encode(long, INFO)))
			expect(#card.crew[1].name).to.equal(40)
		end)

		it("reads nothing from no payload, another version or a payload that is not a card", function()
			expect(ShiftCardUtils.decode(nil)).to.equal(nil)
			expect(ShiftCardUtils.decode({})).to.equal(nil)
			expect(ShiftCardUtils.decode({ contract = "harlow-finch-1" })).to.equal(nil)
			local other = payload()
			other.v = 2
			expect(ShiftCardUtils.decode(other)).to.equal(nil)
		end)

		it("rejects a field of the wrong type", function()
			local wrong = {
				client = 5,
				outcome = 5,
				shift = "two",
				quota = "lots",
				cleared = "lots",
				bonus = "lots",
				salvage = "lots",
				piles = "lots",
				catches = "lots",
				met = "yes",
				crew = "two",
				awards = "two",
				c1n = 7,
				c1b = "seven",
				a1t = false,
				a1n = 3,
			}
			for key, value in wrong do
				local broken = payload()
				broken[key] = value
				expect(ShiftCardUtils.decode(broken)).to.equal(nil)
			end
		end)

		it("rejects a crew count that doesn't match its lines", function()
			local short = payload()
			short.crew = 3
			expect(ShiftCardUtils.decode(short)).to.equal(nil)
			local huge = payload()
			huge.crew = 9
			expect(ShiftCardUtils.decode(huge)).to.equal(nil)
			local awards = payload()
			awards.awards = 4
			expect(ShiftCardUtils.decode(awards)).to.equal(nil)
		end)

		it("clamps negative, fractional and huge numbers", function()
			local odd = payload()
			odd.cleared = -5
			odd.bonus = 12.7
			odd.quota = 1e12
			local card = ShiftCardUtils.decode(odd)
			expect(card.cleared).to.equal(0)
			expect(card.bonus).to.equal(12)
			expect(card.quota).to.equal(1000000)
		end)

		it("rejects a number that is not a number", function()
			local nan = payload()
			nan.bonus = 0 / 0
			expect(ShiftCardUtils.decode(nan)).to.equal(nil)
		end)
	end)

	describe("attributes", function()
		local keys = DepotConstants.REVIEW_KEYS

		it("writes the card under the board's keys", function()
			local attributes = ShiftCardUtils.attributes(ShiftCardUtils.decode(payload()))
			expect(attributes[keys.client]).to.equal("Harlow & Finch Ltd.")
			expect(attributes[keys.cleared]).to.equal(380)
			expect(attributes[keys.quota]).to.equal(350)
			expect(attributes[keys.bonus]).to.equal(95)
			expect(attributes[keys.catches]).to.equal(1)
			expect(attributes[keys.salvage]).to.equal(3)
			expect(attributes[keys.offered]).to.equal(9)
			expect(attributes[keys.met]).to.equal(true)
			expect(attributes[keys.rating]).to.equal("satisfactory")
			expect(attributes[keys.truck]).to.equal(0)
		end)

		it("numbers the crew lines and the awards", function()
			local attributes = ShiftCardUtils.attributes(ShiftCardUtils.decode(payload()))
			expect(attributes[`{keys.crew}1`]).to.equal("Crew1")
			expect(attributes[`{keys.crew}2`]).to.equal("Crew2")
			expect(attributes[`{keys.crew}3`]).to.equal(nil)
			expect(attributes[`{keys.awardTitle}1`]).to.equal("Top Hauler")
			expect(attributes[`{keys.awardName}2`]).to.equal("Crew2")
			expect(attributes[`{keys.awardTitle}3`]).to.equal(nil)
		end)

		it("writes the truck when it is known", function()
			local card = ShiftCardUtils.decode(
				wire(ShiftCardUtils.encode(review(2), { client = INFO.client, shift = INFO.shift, truck = 3 }))
			)
			expect(ShiftCardUtils.attributes(card)[keys.truck]).to.equal(3)
		end)

		it("keeps only values an attribute can hold", function()
			for _, value in ShiftCardUtils.attributes(ShiftCardUtils.decode(payload())) do
				local kind = type(value)
				expect(kind == "string" or kind == "number" or kind == "boolean").to.equal(true)
			end
		end)
	end)

	describe("M3 UI fields", function()
		it("carries the salvage offered and derives the rating", function()
			local fixture = review(2)
			fixture.salvage = 6
			fixture.offered = 9
			fixture.quotaMet = true
			local card = ShiftCardUtils.decode(ShiftCardUtils.encode(fixture, INFO))
			expect(card.offered).to.equal(9)
			expect(card.rating).to.equal("exceeds")
		end)

		it("re-derives the rating instead of trusting the card", function()
			local card = ShiftCardUtils.encode(review(2), INFO)
			card.met = false
			card.rating = "exceeds"
			expect(ShiftCardUtils.decode(card).rating).to.equal("needsImprovement")
		end)

		it("reads an absent salvage-offered as 0 and rejects a wrong type", function()
			local card = ShiftCardUtils.encode(review(2), INFO)
			card.offered = nil
			expect(ShiftCardUtils.decode(card).offered).to.equal(0)
			card.offered = "nine"
			expect(ShiftCardUtils.decode(card)).to.equal(nil)
		end)

		it("hands the board the salvage found, the salvage offered and the rating", function()
			local fixture = review(2)
			fixture.salvage = 2
			fixture.offered = 9
			local keys = DepotConstants.REVIEW_KEYS
			local attributes = ShiftCardUtils.attributes(ShiftCardUtils.decode(ShiftCardUtils.encode(fixture, INFO)))
			expect(attributes[keys.salvage]).to.equal(2)
			expect(attributes[keys.offered]).to.equal(9)
			expect(type(attributes[keys.rating])).to.equal("string")
		end)
	end)

	describe("truck and summary", function()
		it("carries a valid truck and drops a bad one", function()
			local info = { client = INFO.client, shift = INFO.shift, truck = 2 }
			expect(ShiftCardUtils.decode(ShiftCardUtils.encode(review(2), info)).truck).to.equal(2)
			local forged = ShiftCardUtils.encode(review(2), info)
			forged.truck = 99
			expect(ShiftCardUtils.decode(forged).truck).to.equal(nil)
			forged.truck = nil
			expect(ShiftCardUtils.decode(forged).truck).to.equal(nil)
		end)

		it("summarises the card for the depot board", function()
			local fixture = review(2)
			fixture.offered = 9
			local card = ShiftCardUtils.decode(ShiftCardUtils.encode(fixture, { client = "H&F", shift = 1, truck = 3 }))
			local summary = ShiftCardUtils.summary(card)
			expect(summary.cleared).to.equal(card.cleared)
			expect(summary.offered).to.equal(9)
			expect(summary.rating).to.equal(card.rating)
			expect(summary.truck).to.equal(3)
		end)

		it("writes truck 0 for an unknown truck", function()
			local card = ShiftCardUtils.decode(ShiftCardUtils.encode(review(2), INFO))
			expect(ShiftCardUtils.summary(card).truck).to.equal(0)
		end)

		it("keeps counts past 16 bits for the wire (uint32)", function()
			local wide = ShiftCardUtils.encode(review(2), INFO)
			wide.catches = 70000
			wide.salvage = 70000
			wide.offered = 70000
			local summary = ShiftCardUtils.summary(ShiftCardUtils.decode(wide))
			expect(summary.salvage).to.equal(70000)
		end)
	end)
end
