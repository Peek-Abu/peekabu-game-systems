local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToonConstants = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonConstants)
local ToonFaceRules = require(script.Parent.ToonFaceRules)

return function()
	local NEAR = ToonConstants.WORRIED_RADIUS - 1
	local FAR = ToonConstants.WORRIED_RADIUS + 1

	describe("isThreatened", function()
		it("is never threatened without a Manager", function()
			expect(ToonFaceRules.isThreatened(nil, false, nil)).to.equal(false)
		end)

		it("is threatened when the Manager chases or catches this player, at any distance", function()
			expect(ToonFaceRules.isThreatened("chase", true, 500)).to.equal(true)
			expect(ToonFaceRules.isThreatened("catch", true, nil)).to.equal(true)
		end)

		it("is threatened by a nearby Manager who is investigating, chasing someone or searching", function()
			expect(ToonFaceRules.isThreatened("investigate", false, NEAR)).to.equal(true)
			expect(ToonFaceRules.isThreatened("chase", false, NEAR)).to.equal(true)
			expect(ToonFaceRules.isThreatened("search", false, NEAR)).to.equal(true)
			expect(ToonFaceRules.isThreatened("catch", false, NEAR)).to.equal(true)
		end)

		it("ignores a nearby Manager who is only patrolling or resting", function()
			expect(ToonFaceRules.isThreatened("patrol", false, NEAR)).to.equal(false)
			expect(ToonFaceRules.isThreatened("rest", false, NEAR)).to.equal(false)
		end)

		it("ignores an alert Manager beyond the radius when he is not after this player", function()
			expect(ToonFaceRules.isThreatened("investigate", false, FAR)).to.equal(false)
			expect(ToonFaceRules.isThreatened("chase", false, FAR)).to.equal(false)
			expect(ToonFaceRules.isThreatened("chase", false, nil)).to.equal(false)
		end)

		it("does not count being the target of a non-chase mode", function()
			expect(ToonFaceRules.isThreatened("search", true, FAR)).to.equal(false)
		end)
	end)

	describe("decide", function()
		it("is Worried whenever threatened, even while busy", function()
			expect(ToonFaceRules.decide(true, true, 10, 10)).to.equal("Worried")
		end)

		it("is Happy while busy", function()
			expect(ToonFaceRules.decide(false, true, 10, nil)).to.equal("Happy")
		end)

		it("stays Happy for the linger window after the last busy moment", function()
			local now = 100
			expect(ToonFaceRules.decide(false, false, now, now - ToonConstants.HAPPY_LINGER + 0.1)).to.equal("Happy")
			expect(ToonFaceRules.decide(false, false, now, now - ToonConstants.HAPPY_LINGER - 0.1)).to.equal("Content")
		end)

		it("is Content otherwise", function()
			expect(ToonFaceRules.decide(false, false, 10, nil)).to.equal("Content")
		end)
	end)
end
