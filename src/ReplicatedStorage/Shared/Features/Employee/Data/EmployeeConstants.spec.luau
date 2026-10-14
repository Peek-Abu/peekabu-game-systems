local EmployeeConstants = require(script.Parent.EmployeeConstants)

return function()
	describe("EmployeeConstants", function()
		it("keeps the ears within the rigid one-piece limit", function()
			expect(EmployeeConstants.EAR_MAX_ANGLE > 0).to.equal(true)
			expect(EmployeeConstants.EAR_MAX_ANGLE <= math.rad(30) + 1e-6).to.equal(true)
		end)

		it("names one left and one right ear joint", function()
			local sides = {}
			for _, joint in EmployeeConstants.EAR_JOINTS do
				sides[joint.side] = joint.name
			end
			expect(sides[-1]).to.equal("LeftEarBase")
			expect(sides[1]).to.equal("RightEarBase")
		end)

		it("names the fitted-gear mount attribute and distinct lanyard/badge elements", function()
			expect(EmployeeConstants.GEAR_MOUNT_ATTRIBUTE).to.equal("MountPart")
			local seen = {}
			for _, name in
				{
					EmployeeConstants.LANYARD_STRAP,
					EmployeeConstants.BADGE_HOLDER,
					EmployeeConstants.BADGE_TITLE,
					EmployeeConstants.BADGE_BAND,
					EmployeeConstants.BADGE_BAND_TEXT,
				}
			do
				expect(seen[name]).never.to.be.ok()
				seen[name] = true
			end
		end)

		it("uses positive radii, intervals and spring gains", function()
			expect(EmployeeConstants.WORRIED_RADIUS > 0).to.equal(true)
			expect(EmployeeConstants.EAR_RADIUS > 0).to.equal(true)
			expect(EmployeeConstants.EXPRESSION_INTERVAL > 0).to.equal(true)
			expect(EmployeeConstants.CLEANING_LINGER >= 0).to.equal(true)
			expect(EmployeeConstants.EAR_STIFFNESS > 0).to.equal(true)
			expect(EmployeeConstants.EAR_DAMPING > 0).to.equal(true)
		end)
	end)
end
