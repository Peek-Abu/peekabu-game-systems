local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local DeathRagdollUtils = require(script.Parent.DeathRagdollUtils)

return function()
	it("returns the declared limits for known R15 and R6 joints", function()
		expect(DeathRagdollUtils.limitsFor("Neck").upperAngle).to.equal(30)
		expect(DeathRagdollUtils.limitsFor("LeftKnee").twistLower).to.equal(-120)
		expect(DeathRagdollUtils.limitsFor("Left Hip").upperAngle).to.equal(50)
	end)

	it("falls back to the default limits for an unknown joint", function()
		expect(DeathRagdollUtils.limitsFor("TailJoint")).to.equal(DeathConstants.DEFAULT_LIMITS)
	end)

	it("skips the root joint", function()
		expect(DeathRagdollUtils.isRootJoint("Root")).to.equal(true)
		expect(DeathRagdollUtils.isRootJoint("RootJoint")).to.equal(true)
		expect(DeathRagdollUtils.isRootJoint("Neck")).to.equal(false)
	end)

	it("keeps every declared joint's limits sane", function()
		for name, limits in DeathConstants.JOINT_LIMITS do
			expect(limits.upperAngle >= 0 and limits.upperAngle <= 180).to.equal(true)
			expect(limits.twistLower <= limits.twistUpper).to.equal(true)
			expect(name ~= "").to.equal(true)
		end
	end)
end
