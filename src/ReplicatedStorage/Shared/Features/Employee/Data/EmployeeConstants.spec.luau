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

		it("names the outfit's place, the character's outfit folders and the outfit contract distinctly", function()
			expect(table.concat(EmployeeConstants.OUTFITS_PATH, ".")).to.equal("Assets.CleanupCrew.Outfits")
			local seen = {}
			for _, name in
				{
					EmployeeConstants.OUTFIT_FOLDER,
					EmployeeConstants.PROPS_FOLDER,
					EmployeeConstants.PIECES_FOLDER,
					EmployeeConstants.FACES_FOLDER,
				}
			do
				expect(seen[name]).never.to.be.ok()
				seen[name] = true
			end
			for _, name in
				{
					EmployeeConstants.OUTFIT_MESHES,
					EmployeeConstants.OUTFIT_RIG,
					EmployeeConstants.OUTFIT_STYLES,
					EmployeeConstants.OUTFIT_PROPS,
					EmployeeConstants.STYLE_SLOT_ATTRIBUTE,
					EmployeeConstants.BODY_STYLE_SLOT,
					EmployeeConstants.PROP_HAND_ATTRIBUTE,
					EmployeeConstants.HIDE_PARTS_ATTRIBUTE,
					EmployeeConstants.HIDE_ACCESSORIES_ATTRIBUTE,
					EmployeeConstants.OUTFIT_BONE_ATTRIBUTE,
					EmployeeConstants.STYLE_ATTRIBUTE,
				}
			do
				expect(type(name)).to.equal("string")
				expect(#name > 0).to.equal(true)
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

		it("keeps the head look subtle: at most 40 degrees of turn and 25 of tip, eased, near the camera", function()
			local look = EmployeeConstants.HEAD_LOOK
			expect(look.maxYaw > 0 and look.maxYaw <= math.rad(40) + 1e-9).to.equal(true)
			expect(look.maxPitch > 0 and look.maxPitch <= math.rad(25) + 1e-9).to.equal(true)
			expect(look.pitchShare > 0 and look.pitchShare <= 1).to.equal(true)
			expect(look.ease > 0 and look.radius > 0).to.equal(true)
		end)

		it("stamps the footstep set under the attribute the Footstep client reads", function()
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local FootstepConstants = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepConstants)
			expect(EmployeeConstants.FOOTSTEP_SET_ATTRIBUTE).to.equal(FootstepConstants.SET_ATTRIBUTE)
			expect(EmployeeConstants.SWAP_ATTRIBUTE).to.be.a("string")
			expect(EmployeeConstants.LOADOUT_WAIT > 0).to.equal(true)
		end)
	end)
end
