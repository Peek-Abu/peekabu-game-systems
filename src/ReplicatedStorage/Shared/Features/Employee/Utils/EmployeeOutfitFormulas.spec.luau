local EmployeeOutfitFormulas = require(script.Parent.EmployeeOutfitFormulas)

return function()
	local function near(a, b)
		return (a.Position - b.Position).Magnitude < 1e-4
			and a.LookVector:Dot(b.LookVector) > 0.9999
			and a.UpVector:Dot(b.UpVector) > 0.9999
	end

	local OFFSET = CFrame.new(0.2, -0.4, 0.1) * CFrame.Angles(0, math.rad(30), math.rad(-15))

	describe("scaled", function()
		it("leaves an offset unchanged at scale 1", function()
			expect(near(EmployeeOutfitFormulas.scaled(OFFSET, 1), OFFSET)).to.equal(true)
		end)

		it("scales the position and keeps the rotation at 1.25", function()
			local out = EmployeeOutfitFormulas.scaled(OFFSET, 1.25)
			expect((out.Position - OFFSET.Position * 1.25).Magnitude < 1e-4).to.equal(true)
			expect(out.LookVector:Dot(OFFSET.LookVector) > 0.9999).to.equal(true)
			expect(out.UpVector:Dot(OFFSET.UpVector) > 0.9999).to.equal(true)
		end)

		it("refuses a scale of 0 or below", function()
			expect(function()
				EmployeeOutfitFormulas.scaled(OFFSET, 0)
			end).to.throw()
			expect(function()
				EmployeeOutfitFormulas.scaled(OFFSET, -1)
			end).to.throw()
		end)
	end)

	describe("joint", function()
		it("scales a prop joint's C0 and C1 the same way", function()
			local c0 = CFrame.new(0.1, -0.5, 0.3) * CFrame.Angles(math.rad(10), 0, 0)
			local c1 = CFrame.new(0, 0.2, 0)
			local outC0, outC1 = EmployeeOutfitFormulas.joint(c0, c1, 1.25)
			expect(near(outC0, EmployeeOutfitFormulas.scaled(c0, 1.25))).to.equal(true)
			expect(near(outC1, EmployeeOutfitFormulas.scaled(c1, 1.25))).to.equal(true)
		end)
	end)

	describe("rest", function()
		it("is Part0 * C0 * C1^-1, whatever the joint's animated Transform", function()
			local part0 = CFrame.new(3, 2, 1) * CFrame.Angles(0, math.rad(90), 0)
			local c0 = CFrame.new(0, -0.6, 0)
			local c1 = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(5))
			expect(near(EmployeeOutfitFormulas.rest(part0, c0, c1), part0 * c0 * c1:Inverse())).to.equal(true)
		end)
	end)

	describe("place", function()
		it("puts a piece where it sat against the reference, scaled, on the target", function()
			local reference = CFrame.new(0, 1.1, 0)
			local piece = CFrame.new(0.5, 2.1, -0.2) * CFrame.Angles(0, math.rad(20), 0)
			local target = CFrame.new(10, 5, 0) * CFrame.Angles(0, math.rad(180), 0)
			local out = EmployeeOutfitFormulas.place(target, reference, piece, 1.25)
			local expected = target * EmployeeOutfitFormulas.scaled(reference:ToObjectSpace(piece), 1.25)
			expect(near(out, expected)).to.equal(true)
		end)
	end)
end
