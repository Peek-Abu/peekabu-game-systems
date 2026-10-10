local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftCardUtils = require(script.Parent.ShiftCardUtils)
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

	describe("lines", function()
		it("reads like the review", function()
			local lines = ShiftCardUtils.lines(ShiftCardUtils.decode(payload()))
			expect(lines[1]).to.equal("Harlow & Finch Ltd. - shift 2")
			expect(lines[2]).to.equal("Clocked out")
			expect(lines[3]).to.equal("Cleared 380 / 350 - QUOTA MET")
			expect(lines[4]).to.equal("Finder's fee 95")
			expect(lines[5]).to.equal("Salvage 3 | Piles 12 | Caught 1")
			expect(lines[6]).to.equal("Crew1: banked 99")
			expect(lines[7]).to.equal("Crew2: banked 98")
			expect(lines[8]).to.equal("Top Hauler: Crew1")
			expect(lines[9]).to.equal("Dust Devil: Crew2")
			expect(#lines).to.equal(9)
		end)

		it("says when the quota was missed, and keeps an unknown outcome as written", function()
			local missed = review(1)
			missed.quotaMet = false
			missed.outcome = "abandoned"
			local lines = ShiftCardUtils.lines(ShiftCardUtils.decode(wire(ShiftCardUtils.encode(missed, INFO))))
			expect(lines[2]).to.equal("Everyone left")
			expect(lines[3]).to.equal("Cleared 380 / 350 - quota missed")
			local odd = review(1)
			odd.outcome = "weird"
			local oddLines = ShiftCardUtils.lines(ShiftCardUtils.decode(wire(ShiftCardUtils.encode(odd, INFO))))
			expect(oddLines[2]).to.equal("weird")
		end)
	end)
end
