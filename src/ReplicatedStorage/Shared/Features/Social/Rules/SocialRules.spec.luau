local SocialRules = require(script.Parent.SocialRules)
local SocialConstants = require(script.Parent.Parent.Data.SocialConstants)

local DAY = 86400

return function()
	describe("fresh / validate", function()
		it("starts with nothing paid, asked or referred, and validates", function()
			local state = SocialRules.fresh()
			expect(state.groupPaid).to.equal(false)
			expect(state.referredBy).to.equal(0)
			expect(state.referralPaid).to.equal(false)
			expect(state.referrals).to.equal(0)
			expect(state.askedAt).to.equal(0)
			expect(SocialRules.validate(state)).to.equal(true)
		end)

		it("refuses negative or fractional numbers and non-booleans", function()
			local state = SocialRules.fresh()
			state.referrals = -1
			expect(SocialRules.validate(state)).to.equal(false)
			state = SocialRules.fresh()
			state.referredBy = 1.5
			expect(SocialRules.validate(state)).to.equal(false)
			state = SocialRules.fresh()
			state.groupPaid = "yes"
			expect(SocialRules.validate(state)).to.equal(false)
		end)
	end)

	describe("launchData / referrerFrom", function()
		it("round-trips the inviter through the launch data", function()
			expect(SocialRules.launchData(42)).to.equal(SocialConstants.LAUNCH_PREFIX .. "42")
			expect(SocialRules.referrerFrom(SocialRules.launchData(42), 7)).to.equal(42)
		end)

		it("never names the player themselves", function()
			expect(SocialRules.referrerFrom(SocialRules.launchData(7), 7)).to.equal(nil)
		end)

		it("ignores missing data and junk", function()
			expect(SocialRules.referrerFrom(nil, 7)).to.equal(nil)
			expect(SocialRules.referrerFrom("", 7)).to.equal(nil)
			expect(SocialRules.referrerFrom("ref:abc", 7)).to.equal(nil)
			expect(SocialRules.referrerFrom("ref:-3", 7)).to.equal(nil)
			expect(SocialRules.referrerFrom("hello", 7)).to.equal(nil)
		end)
	end)

	describe("canRecordReferrer", function()
		it("only for a player who never finished a shift and has no referrer yet", function()
			expect(SocialRules.canRecordReferrer(SocialRules.fresh(), 0)).to.equal(true)
			expect(SocialRules.canRecordReferrer(SocialRules.fresh(), 10)).to.equal(false)
			local state = SocialRules.fresh()
			state.referredBy = 5
			expect(SocialRules.canRecordReferrer(state, 0)).to.equal(false)
			state = SocialRules.fresh()
			state.referralPaid = true
			expect(SocialRules.canRecordReferrer(state, 0)).to.equal(false)
		end)
	end)

	describe("referral pay-out", function()
		it("is owed once to a referred player", function()
			local state = SocialRules.fresh()
			expect(SocialRules.referralOwed(state)).to.equal(false)
			state.referredBy = 5
			expect(SocialRules.referralOwed(state)).to.equal(true)
			state.referralPaid = true
			expect(SocialRules.referralOwed(state)).to.equal(false)
		end)

		it("pays the inviter up to the cap", function()
			local inviter = SocialRules.fresh()
			inviter.referrals = SocialConstants.REFERRAL_CAP - 1
			expect(SocialRules.inviterPayable(inviter)).to.equal(true)
			inviter.referrals = SocialConstants.REFERRAL_CAP
			expect(SocialRules.inviterPayable(inviter)).to.equal(false)
		end)
	end)

	describe("shouldAsk", function()
		local now = DAY * 100

		it("asks after a met contract when never asked and not a favorite", function()
			expect(SocialRules.shouldAsk(SocialRules.fresh(), now, true, false)).to.equal(true)
		end)

		it("never asks after a missed contract or once it is a favorite", function()
			expect(SocialRules.shouldAsk(SocialRules.fresh(), now, false, false)).to.equal(false)
			expect(SocialRules.shouldAsk(SocialRules.fresh(), now, true, true)).to.equal(false)
		end)

		it("waits ASK_SPACING between asks", function()
			local state = SocialRules.fresh()
			state.askedAt = now - SocialConstants.ASK_SPACING + 1
			expect(SocialRules.shouldAsk(state, now, true, false)).to.equal(false)
			state.askedAt = now - SocialConstants.ASK_SPACING
			expect(SocialRules.shouldAsk(state, now, true, false)).to.equal(true)
		end)
	end)
end
