local EmployeePoseFormulas = require(script.Parent.EmployeePoseFormulas)

return function()
	local function near(a, b)
		return (a.Position - b.Position).Magnitude < 1e-4
			and (a.LookVector - b.LookVector).Magnitude < 1e-4
			and (a.UpVector - b.UpVector).Magnitude < 1e-4
	end

	describe("turn", function()
		it("is the identity for no turn", function()
			expect(near(EmployeePoseFormulas.turn(Vector3.zero), CFrame.identity)).to.equal(true)
		end)

		it("rolls +X up for a positive Z turn", function()
			local arm = EmployeePoseFormulas.turn(Vector3.new(0, 0, 90)):VectorToWorldSpace(Vector3.xAxis)
			expect((arm - Vector3.yAxis).Magnitude < 1e-4).to.equal(true)
		end)

		it("swings +X forward (-Z) for a positive Y turn", function()
			local arm = EmployeePoseFormulas.turn(Vector3.new(0, 90, 0)):VectorToWorldSpace(Vector3.xAxis)
			expect((arm + Vector3.zAxis).Magnitude < 1e-4).to.equal(true)
		end)
	end)

	describe("motor", function()
		it("is C0 * C1^-1 at rest", function()
			local c0 = CFrame.new(1, 2, 3)
			local c1 = CFrame.new(0, -1, 0)
			expect(near(EmployeePoseFormulas.motor(c0, c1, CFrame.identity), CFrame.new(1, 3, 3))).to.equal(true)
		end)

		it("turns the child about the joint, not about its own centre", function()
			-- Shoulder at +1 X; the arm's centre 1 stud further out. Rolled 90 degrees, the arm points up.
			local offset = EmployeePoseFormulas.motor(
				CFrame.new(1, 0, 0),
				CFrame.new(-1, 0, 0),
				EmployeePoseFormulas.turn(Vector3.new(0, 0, 90))
			)
			expect((offset.Position - Vector3.new(1, 1, 0)).Magnitude < 1e-4).to.equal(true)
		end)
	end)

	describe("solve", function()
		it("places a chain from the root", function()
			local placed = EmployeePoseFormulas.solve(1, CFrame.new(0, 10, 0), {
				{ a = 1, b = 2, offset = CFrame.new(0, 1, 0) },
				{ a = 2, b = 3, offset = CFrame.new(1, 0, 0) },
			})
			expect(near(placed[2], CFrame.new(0, 11, 0))).to.equal(true)
			expect(near(placed[3], CFrame.new(1, 11, 0))).to.equal(true)
		end)

		it("walks a link backwards when only its child is placed", function()
			local placed = EmployeePoseFormulas.solve(2, CFrame.identity, {
				{ a = 1, b = 2, offset = CFrame.new(0, 1, 0) },
			})
			expect(near(placed[1], CFrame.new(0, -1, 0))).to.equal(true)
		end)

		it("leaves parts no link reaches unplaced", function()
			local placed = EmployeePoseFormulas.solve(1, CFrame.identity, {
				{ a = 1, b = 2, offset = CFrame.identity },
				{ a = 3, b = 4, offset = CFrame.identity },
			})
			expect(placed[2]).to.be.ok()
			expect(placed[3]).never.to.be.ok()
			expect(placed[4]).never.to.be.ok()
		end)

		it("places each part once when the links form a loop", function()
			local placed = EmployeePoseFormulas.solve(1, CFrame.identity, {
				{ a = 1, b = 2, offset = CFrame.new(1, 0, 0) },
				{ a = 2, b = 3, offset = CFrame.new(1, 0, 0) },
				{ a = 3, b = 1, offset = CFrame.new(5, 0, 0) },
			})
			expect(near(placed[1], CFrame.identity)).to.equal(true)
			expect(near(placed[2], CFrame.new(1, 0, 0))).to.equal(true)
		end)
	end)

	describe("bounds", function()
		it("returns nil for no boxes", function()
			expect(EmployeePoseFormulas.bounds({})).never.to.be.ok()
		end)

		it("covers every corner of rotated boxes", function()
			local box = EmployeePoseFormulas.bounds({
				{ cframe = CFrame.new(0, 0, 0), size = Vector3.new(2, 2, 2) },
				{ cframe = CFrame.new(10, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), size = Vector3.new(4, 2, 2) },
			})
			expect((box.min - Vector3.new(-1, -2, -1)).Magnitude < 1e-4).to.equal(true)
			expect((box.max - Vector3.new(11, 2, 1)).Magnitude < 1e-4).to.equal(true)
		end)
	end)
end
