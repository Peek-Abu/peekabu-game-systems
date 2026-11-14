local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoffeeConstants = require(ReplicatedStorage.Shared.Features.Coffee.Data.CoffeeConstants)
local CoffeeRules = require(ReplicatedStorage.Shared.Features.Coffee.Rules.CoffeeRules)

return function()
	describe("fresh and validate", function()
		it("starts with no coffee time and accepts whole seconds 0 or more", function()
			local slice = CoffeeRules.fresh()
			expect(slice.seconds).to.equal(0)
			expect(slice.since).to.equal(0)
			expect((CoffeeRules.validate(slice))).to.equal(true)
			expect((CoffeeRules.validate({ seconds = 1800, since = 1700000000 }))).to.equal(true)
			expect((CoffeeRules.validate({ seconds = -1, since = 0 }))).to.equal(false)
			expect((CoffeeRules.validate({ seconds = 1.5, since = 0 }))).to.equal(false)
			expect((CoffeeRules.validate({ seconds = 10, since = -1 }))).to.equal(false)
		end)
	end)

	describe("one coffee", function()
		it("is 30 minutes of shift time", function()
			expect(CoffeeConstants.SECONDS).to.equal(1800)
		end)
	end)

	describe("add", function()
		it("adds 30 minutes and stamps when the coffee time started", function()
			local slice = CoffeeRules.fresh()
			CoffeeRules.add(slice, 500)
			expect(slice.seconds).to.equal(1800)
			expect(slice.since).to.equal(500)
		end)

		it("adds to coffee time already running and keeps its start (the buyer's place in line)", function()
			local slice = { seconds = 1200, since = 500 }
			CoffeeRules.add(slice, 900)
			expect(slice.seconds).to.equal(3000)
			expect(slice.since).to.equal(500)
		end)
	end)

	describe("spend", function()
		it("takes seconds off and never goes below 0", function()
			local slice = { seconds = 3, since = 500 }
			CoffeeRules.spend(slice, 1)
			expect(slice.seconds).to.equal(2)
			expect(slice.since).to.equal(500)
			CoffeeRules.spend(slice, 5)
			expect(slice.seconds).to.equal(0)
		end)

		it("forgets the start once the coffee time is used up", function()
			local slice = { seconds = 1, since = 500 }
			CoffeeRules.spend(slice, 1)
			expect(slice.since).to.equal(0)
		end)
	end)

	describe("runs", function()
		it("counts down only while a real shift runs with players in the server", function()
			expect(CoffeeRules.runs("running", false, 1)).to.equal(true)
			expect(CoffeeRules.runs("running", true, 1)).to.equal(false)
			expect(CoffeeRules.runs("running", false, 0)).to.equal(false)
			expect(CoffeeRules.runs("lobby", false, 2)).to.equal(false)
			expect(CoffeeRules.runs("starting", false, 2)).to.equal(false)
			expect(CoffeeRules.runs("results", false, 2)).to.equal(false)
		end)
	end)

	describe("spender", function()
		it("spends the earliest buyer's coffee first", function()
			local picked = CoffeeRules.spender({
				{ userId = 1, seconds = 900, since = 300 },
				{ userId = 2, seconds = 1800, since = 100 },
				{ userId = 3, seconds = 1800, since = 200 },
			})
			expect(picked).to.be.ok()
			expect(picked.userId).to.equal(2)
		end)

		it("skips players with no coffee time and breaks ties by the lower user id", function()
			local picked = CoffeeRules.spender({
				{ userId = 9, seconds = 0, since = 0 },
				{ userId = 5, seconds = 60, since = 100 },
				{ userId = 4, seconds = 60, since = 100 },
			})
			expect(picked.userId).to.equal(4)
		end)

		it("is nobody when no one has coffee time", function()
			expect(CoffeeRules.spender({})).to.equal(nil)
			expect(CoffeeRules.spender({ { userId = 1, seconds = 0, since = 0 } })).to.equal(nil)
		end)
	end)

	describe("offered", function()
		it("shows the buy button only while a real shift runs and no coffee is on", function()
			expect(CoffeeRules.offered("running", false, false)).to.equal(true)
			expect(CoffeeRules.offered("running", true, false)).to.equal(false)
			expect(CoffeeRules.offered("running", false, true)).to.equal(false)
			expect(CoffeeRules.offered("lobby", false, false)).to.equal(false)
			expect(CoffeeRules.offered("results", false, false)).to.equal(false)
		end)
	end)

	describe("payScale", function()
		it("doubles the pay when coffee ran the whole shift", function()
			expect(CoffeeConstants.PAY_SCALE).to.equal(2)
			expect(CoffeeRules.payScale(510, 510)).to.equal(2)
			expect(CoffeeRules.payScale(509, 510.7)).to.equal(2)
		end)

		it("pays 2x for the part of the shift coffee ran", function()
			expect(CoffeeRules.payScale(255, 510)).to.equal(1.5)
			expect(CoffeeRules.payScale(100, 600)).to.equal(1.2)
		end)

		it("leaves the pay without coffee, and never goes past 2x", function()
			expect(CoffeeRules.payScale(0, 510)).to.equal(1)
			expect(CoffeeRules.payScale(0, 0)).to.equal(1)
			expect(CoffeeRules.payScale(900, 510)).to.equal(2)
			expect(CoffeeRules.payScale(5, 0)).to.equal(2)
		end)
	end)

	describe("scaleText", function()
		it("reads 2 or 1.5", function()
			expect(CoffeeRules.scaleText(2)).to.equal("2")
			expect(CoffeeRules.scaleText(1.5)).to.equal("1.5")
		end)
	end)

	describe("clock", function()
		it("reads minutes and seconds", function()
			expect(CoffeeRules.clock(1450)).to.equal("24:10")
			expect(CoffeeRules.clock(1800)).to.equal("30:00")
			expect(CoffeeRules.clock(65)).to.equal("1:05")
			expect(CoffeeRules.clock(5400)).to.equal("90:00")
			expect(CoffeeRules.clock(0)).to.equal("0:00")
			expect(CoffeeRules.clock(-3)).to.equal("0:00")
		end)
	end)

	describe("badge", function()
		it("reads the world entry", function()
			local badge = CoffeeRules.badge({ buyer = "Ice", seconds = 1450 })
			expect(badge).to.be.ok()
			expect(badge.buyer).to.equal("Ice")
			expect(badge.seconds).to.equal(1450)
		end)

		it("is nothing for an absent or broken entry", function()
			expect(CoffeeRules.badge(nil)).to.equal(nil)
			expect(CoffeeRules.badge("Ice")).to.equal(nil)
			expect(CoffeeRules.badge({ buyer = "Ice" })).to.equal(nil)
			expect(CoffeeRules.badge({ seconds = 3 })).to.equal(nil)
		end)

		it("shows the buyer and the time left", function()
			expect(CoffeeRules.badgeText("Ice", 1450)).to.equal("2x PAY · ICE · 24:10")
		end)
	end)

	describe("Gleam", function()
		it("costs 150 Gleam for the same 30 minutes", function()
			expect(CoffeeConstants.GLEAM_PRICE).to.equal(150)
		end)

		it("is affordable with 150 Gleam or more", function()
			expect(CoffeeRules.affords(150)).to.equal(true)
			expect(CoffeeRules.affords(900)).to.equal(true)
			expect(CoffeeRules.affords(149)).to.equal(false)
			expect(CoffeeRules.affords(nil)).to.equal(false)
		end)

		it("takes 150 Gleam off the balance, or refuses and leaves it", function()
			local rich = { balance = 200 }
			expect(CoffeeRules.payGleam(rich)).to.equal(true)
			expect(rich.balance).to.equal(50)
			local poor = { balance = 149 }
			expect(CoffeeRules.payGleam(poor)).to.equal(false)
			expect(poor.balance).to.equal(149)
		end)

		it("costs less in Gleam than the same Robux at the best Gleam pack", function()
			-- 150 Gleam at the best pack (R$ 999 for 1,500) is R$ 99.9: the Robux price (R$ 99, owner 11-14) stays the
			-- better deal, just. Compared in whole numbers (99 x 1,500 < 150 x 999), so rounding never flips it.
			expect(CoffeeConstants.ROBUX_PRICE).to.equal(99)
			expect(CoffeeConstants.ROBUX_PRICE * 1500 < CoffeeConstants.GLEAM_PRICE * 999).to.equal(true)
		end)

		it("tells a player who is short how much coffee costs", function()
			expect(CoffeeRules.shortLine()).to.equal("You need 150 Gleam!")
		end)
	end)

	describe("robuxText", function()
		it("shows Roblox's live price, or the known price until Roblox answers", function()
			expect(CoffeeRules.robuxText(179)).to.equal("179 R$")
			expect(CoffeeRules.robuxText(nil)).to.equal("99 R$")
		end)
	end)

	describe("paLine", function()
		it("names the buyer and says it is 30 minutes", function()
			expect(CoffeeRules.paLine("Ice")).to.equal("PA: Ice bought coffee! The crew gets 2x pay for 30 minutes!")
		end)
	end)
end
