local ToonConstants = require(script.Parent.ToonConstants)

return function()
	describe("ToonConstants", function()
		it("keeps the ears within the rigid one-piece limit", function()
			expect(ToonConstants.EAR_MAX_ANGLE > 0).to.equal(true)
			expect(ToonConstants.EAR_MAX_ANGLE <= math.rad(30) + 1e-6).to.equal(true)
		end)

		it("names one left and one right ear joint", function()
			local sides = {}
			for _, joint in ToonConstants.EAR_JOINTS do
				sides[joint.side] = joint.name
			end
			expect(sides[-1]).to.equal("LeftEarBase")
			expect(sides[1]).to.equal("RightEarBase")
		end)

		it("uses positive radii, intervals and spring gains", function()
			expect(ToonConstants.WORRIED_RADIUS > 0).to.equal(true)
			expect(ToonConstants.EAR_RADIUS > 0).to.equal(true)
			expect(ToonConstants.EXPRESSION_INTERVAL > 0).to.equal(true)
			expect(ToonConstants.HAPPY_LINGER >= 0).to.equal(true)
			expect(ToonConstants.EAR_STIFFNESS > 0).to.equal(true)
			expect(ToonConstants.EAR_DAMPING > 0).to.equal(true)
		end)
	end)
end
