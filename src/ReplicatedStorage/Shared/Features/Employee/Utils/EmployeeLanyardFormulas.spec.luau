local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeLanyardFormulas = require(script.Parent.EmployeeLanyardFormulas)
local EmployeeLanyardConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeLanyardConstants)

return function()
	describe("fit decoding & selection", function()
		it("decodes fitted bodies for Pippa, Cappy, CappyNoHoodie, Prickles and Manager", function()
			for _, name in { "Pippa", "Cappy", "CappyNoHoodie", "Prickles", "Manager" } do
				local fit = EmployeeLanyardFormulas.fit(name)
				expect(fit).to.be.ok()
				expect(#fit.ribbon.centre > 20).to.equal(true)
				expect(fit.torso_width > 0.4).to.equal(true)
			end
		end)

		it("widens boss ribbons (ranks 5-7) over worker cords (ranks 1-4)", function()
			local fit = EmployeeLanyardFormulas.fit("Pippa")
			local r1 = EmployeeLanyardFormulas.width(fit, 1)
			local r4 = EmployeeLanyardFormulas.width(fit, 4)
			local r6 = EmployeeLanyardFormulas.width(fit, 6)
			expect(r1).to.be.near(r4, 1e-6)
			expect(r6 > r1 * 2).to.equal(true)
		end)
	end)

	describe("geometry & spring", function()
		it("builds a closed ribbon mesh with outward triangles and rank-7 edge bands", function()
			local fit = EmployeeLanyardFormulas.fit("Cappy")
			local width = EmployeeLanyardFormulas.width(fit, 7)
			local geo = EmployeeLanyardFormulas.geometry(fit, width, 1.25)
			expect(#geo.pos).to.equal(geo.nSamples * 10)
			expect(#geo.tris > 100).to.equal(true)
			expect(#geo.triBand).to.equal(#geo.tris)
			local hasEdge = false
			for _, b in geo.triBand do
				if b == 1 then
					hasEdge = true
				end
			end
			expect(hasEdge).to.equal(true)
		end)

		it("sways under acceleration and settles to rest when still", function()
			local fit = EmployeeLanyardFormulas.fit("Prickles")
			local spring = EmployeeLanyardFormulas.newSpring()
			local p1, _, _, moving1 = EmployeeLanyardFormulas.step(fit, 3, spring, { 0, 0, 12 }, 1 / 60)
			expect(moving1).to.equal(true)
			expect(p1 >= fit.badge_rest["3"].pitch_deg).to.equal(true)
			local moving = true
			for _ = 1, 120 do
				local _, _, _, m = EmployeeLanyardFormulas.step(fit, 3, spring, { 0, 0, 0 }, 1 / 60)
				moving = m
			end
			expect(moving).to.equal(false)
		end)

		it("provides v6 front card layouts for all 7 ranks", function()
			expect(#EmployeeLanyardConstants.INFO_FRONT).to.equal(7)
			expect(#EmployeeLanyardConstants.RANK_NAMES).to.equal(7)
		end)
	end)

	describe("imported badge orientation", function()
		it("puts the uploaded front outward and rear relief behind the front information", function()
			-- Verified on the live unflipped R1: imported -Z shows the 3D NEW! over the front GUI.
			local front = EmployeeLanyardFormulas.badgePartCFrame(CFrame.new(0, -0.44, 0.003))
			local rearIcon = EmployeeLanyardFormulas.badgePartCFrame(CFrame.new(0, -0.44, -0.015))
			expect(front.Position.Z < 0).to.equal(true)
			expect(rearIcon.Position.Z > 0).to.equal(true)
			local flippedRear = CFrame.Angles(0, math.pi, 0) * rearIcon
			expect(flippedRear.Position.Z < 0).to.equal(true)
		end)

		it("restores the authored asymmetric rank-5 part and clears its front plane", function()
			local part = EmployeeLanyardFormulas.badgePartCFrame(CFrame.new(0, -0.34417, 0.0186666))
			expect(part.Position.Y).to.be.near(-0.34417, 1e-6)
			expect(part.Position.Z).to.be.near(-0.0186666, 1e-6)
			local z =
				EmployeeLanyardFormulas.cardZ({ { cframe = part, size = Vector3.new(0.29667, 0.575, 0.0673334) } })
			expect(z).to.be.near(-0.0523333 - EmployeeLanyardConstants.CARD_CLEARANCE, 1e-6)
		end)
	end)
	describe("info card front plane", function()
		-- R1's real parts (ReplicatedStorage.Assets.CleanupCrew.LanyardBadges.R1, measured in Studio). The old layout
		-- put the card face at z -0.0047, buried behind the badge's front-most face (z -0.0203) and inside rank 1's
		-- Sleeve, so the card and its portrait vanished as soon as the camera came close.
		local r1 = {
			{ cframe = CFrame.new(0, -0.3581, 0.0008), size = Vector3.new(0.2796, 0.5650, 0.0317) },
			{ cframe = CFrame.new(0, -0.1372, 0.0000), size = Vector3.new(0.0860, 0.2640, 0.0406) },
			{ cframe = CFrame.new(0, -0.4400, 0.0000), size = Vector3.new(0.2783, 0.4000, 0.0300) },
		}

		it("puts the card in front of the badge's front-most face", function()
			local z = EmployeeLanyardFormulas.cardZ(r1)
			expect(z).to.be.ok()
			expect(z < -0.0203).to.equal(true)
			expect(z).to.be.near(-0.0203 - EmployeeLanyardConstants.CARD_CLEARANCE, 1e-6)
		end)

		it("clears every part of the badge, including rotated ones", function()
			local parts = {
				{ cframe = CFrame.new(0, 0, 0), size = Vector3.new(0.4, 0.1, 0.01) },
				{ cframe = CFrame.Angles(0, math.pi / 2, 0), size = Vector3.new(0.4, 0.1, 0.01) },
			}
			-- Turned a quarter turn, the second part's 0.4-stud width runs along z, so its face is at -0.2.
			local z = EmployeeLanyardFormulas.cardZ(parts)
			expect(z).to.be.near(-0.2 - EmployeeLanyardConstants.CARD_CLEARANCE, 1e-6)
		end)

		it("has no plane for a badge with no parts", function()
			expect(EmployeeLanyardFormulas.cardZ({})).to.equal(nil)
		end)
	end)
end
