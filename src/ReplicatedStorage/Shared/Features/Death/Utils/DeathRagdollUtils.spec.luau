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

	it("pairs every body part with every other exactly once, so no two limbs of one ragdoll collide", function()
		local found = DeathRagdollUtils.selfCollisionPairs({ "A", "B", "C", "D" })
		expect(#found).to.equal(6)
		local seen = {}
		for _, pair in found do
			expect(pair[1] ~= pair[2]).to.equal(true)
			local key = if pair[1] < pair[2] then pair[1] .. pair[2] else pair[2] .. pair[1]
			expect(seen[key]).to.equal(nil)
			seen[key] = true
		end
	end)

	it("gives no pairs for fewer than two parts", function()
		expect(#DeathRagdollUtils.selfCollisionPairs({})).to.equal(0)
		expect(#DeathRagdollUtils.selfCollisionPairs({ "A" })).to.equal(0)
	end)
end
