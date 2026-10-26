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
end
