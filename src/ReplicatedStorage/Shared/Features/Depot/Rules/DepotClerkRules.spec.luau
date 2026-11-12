local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotClerkRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotClerkRules)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)

local CLERK = DepotSpotConstants.CLERK

return function()
	describe("the clerk", function()
		it("is Pippa, every day (owner 11-11: she ran the front desk before night shifts)", function()
			expect(CLERK.EMPLOYEE).to.equal("Pippa")
		end)
	end)

	describe("nextFidgetAt", function()
		it("waits between FIDGET_MIN and FIDGET_MAX seconds of idle", function()
			expect(DepotClerkRules.nextFidgetAt(10, 0)).to.equal(10 + CLERK.FIDGET_MIN)
			expect(DepotClerkRules.nextFidgetAt(10, 1)).to.equal(10 + CLERK.FIDGET_MAX)
		end)
	end)

	describe("pickFidget", function()
		local total = 0
		for _, entry in CLERK.FIDGETS do
			total += entry.weight
		end

		it("picks by weight: the stamp most of the time", function()
			expect(DepotClerkRules.pickFidget(0, nil)).to.equal(CLERK.FIDGETS[1].name)
			local stampShare = CLERK.FIDGETS[1].weight / total
			expect(DepotClerkRules.pickFidget(stampShare - 0.01, nil)).to.equal(CLERK.FIDGETS[1].name)
			expect(DepotClerkRules.pickFidget(stampShare + 0.01, nil)).to.equal(CLERK.FIDGETS[2].name)
			expect(DepotClerkRules.pickFidget(0.999, nil)).to.equal(CLERK.FIDGETS[#CLERK.FIDGETS].name)
		end)

		it("never plays a one-off fidget twice in a row", function()
			local last = CLERK.FIDGETS[#CLERK.FIDGETS]
			expect(last.again).to.equal(false)
			expect(DepotClerkRules.pickFidget(0.999, last.name)).never.to.equal(last.name)
		end)

		it("may stamp again right after a stamp", function()
			expect(CLERK.FIDGETS[1].again).to.equal(true)
			expect(DepotClerkRules.pickFidget(0, CLERK.FIDGETS[1].name)).to.equal(CLERK.FIDGETS[1].name)
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
