local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotClerkRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotClerkRules)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)

local CLERK = DepotSpotConstants.CLERK
local NAMES = { "Cappy", "Pippa", "Prickles" }

return function()
	describe("dayOf", function()
		it("counts whole days of server time", function()
			expect(DepotClerkRules.dayOf(0)).to.equal(0)
			expect(DepotClerkRules.dayOf(86399.9)).to.equal(0)
			expect(DepotClerkRules.dayOf(86400)).to.equal(1)
			expect(DepotClerkRules.dayOf(86400 * 20000 + 5)).to.equal(20000)
		end)
	end)

	describe("clerkFor", function()
		it("takes the employees in turn, one a day", function()
			expect(DepotClerkRules.clerkFor(0, NAMES)).to.equal("Cappy")
			expect(DepotClerkRules.clerkFor(1, NAMES)).to.equal("Pippa")
			expect(DepotClerkRules.clerkFor(2, NAMES)).to.equal("Prickles")
			expect(DepotClerkRules.clerkFor(3, NAMES)).to.equal("Cappy")
		end)

		it("is the same clerk all day for everyone (it depends only on the day)", function()
			expect(DepotClerkRules.clerkFor(20000, NAMES)).to.equal(DepotClerkRules.clerkFor(20000, table.clone(NAMES)))
		end)

		it("has no clerk without employees", function()
			expect(DepotClerkRules.clerkFor(4, {})).to.equal(nil)
		end)
	end)

	describe("greets", function()
		it("greets a player who walks up", function()
			expect(DepotClerkRules.greets(CLERK.GREET.RADIUS - 1, nil, 100)).to.equal(true)
		end)

		it("does not greet from across the hub", function()
			expect(DepotClerkRules.greets(CLERK.GREET.RADIUS + 1, nil, 100)).to.equal(false)
		end)

		it("waits out the cooldown before greeting again", function()
			expect(DepotClerkRules.greets(2, 100, 100 + CLERK.GREET.COOLDOWN - 1)).to.equal(false)
			expect(DepotClerkRules.greets(2, 100, 100 + CLERK.GREET.COOLDOWN)).to.equal(true)
		end)
	end)

	describe("parcelHeight", function()
		it("fills the gap from the counter to the stamp's face", function()
			expect(DepotClerkRules.parcelHeight(5.0, 4.5)).to.be.near(0.5, 1e-6)
		end)

		it("keeps a parcel a parcel: never thinner or taller than its limits", function()
			expect(DepotClerkRules.parcelHeight(4.5, 4.5)).to.equal(CLERK.PARCEL.MIN_HEIGHT)
			expect(DepotClerkRules.parcelHeight(9, 4.5)).to.equal(CLERK.PARCEL.MAX_HEIGHT)
		end)
	end)

	describe("hop", function()
		local HOP = CLERK.HOP

		it("waits a beat after the stamp lifts off", function()
			local lift, squash = DepotClerkRules.hop(HOP.DELAY / 2)
			expect(lift).to.equal(0)
			expect(squash).to.equal(1)
		end)

		it("rises to the apex halfway through the hop", function()
			local lift = DepotClerkRules.hop(HOP.DELAY + HOP.SECONDS / 2)
			expect(lift).to.be.near(HOP.APEX, 1e-6)
		end)

		it("lands with a squash, then settles", function()
			local lift, squash = DepotClerkRules.hop(HOP.DELAY + HOP.SECONDS + HOP.SQUASH_SECONDS / 2)
			expect(lift).to.equal(0)
			expect(squash).to.equal(HOP.SQUASH)
			local _, settled = DepotClerkRules.hop(HOP.DELAY + HOP.SECONDS + HOP.SQUASH_SECONDS + 0.01)
			expect(settled).to.equal(1)
		end)

		it("is done once it has settled", function()
			expect(DepotClerkRules.hopDone(HOP.DELAY + HOP.SECONDS + HOP.SQUASH_SECONDS + 0.01)).to.equal(true)
			expect(DepotClerkRules.hopDone(HOP.DELAY)).to.equal(false)
		end)
	end)
end
