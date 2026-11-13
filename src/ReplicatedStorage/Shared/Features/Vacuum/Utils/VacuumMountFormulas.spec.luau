local VacuumMountFormulas = require(script.Parent.VacuumMountFormulas)

return function()
	local function near(a, b, eps)
		return math.abs(a - b) <= (eps or 1e-4)
	end

	local function nearV(a, b, eps)
		return (a - b).Magnitude <= (eps or 1e-4)
	end

	describe("rays", function()
		it("lays a cols x rows grid over the pad's footprint round the mount, starting behind the back", function()
			local origins = VacuumMountFormulas.rays(Vector2.new(0, 0.2), Vector2.new(0.25, 0.35), 3, 2, 4)
			expect(#origins).to.equal(6)
			local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
			for _, o in origins do
				expect(o.Z).to.equal(4)
				minX, maxX = math.min(minX, o.X), math.max(maxX, o.X)
				minY, maxY = math.min(minY, o.Y), math.max(maxY, o.Y)
			end
			-- Inside the pad (never its very edge), symmetric about the mount.
			expect(near(minX, -maxX)).to.equal(true)
			expect(maxX < 0.25 and maxX > 0).to.equal(true)
			expect(near((minY + maxY) / 2, 0.2)).to.equal(true)
			expect(maxY < 0.55 and minY > -0.15).to.equal(true)
		end)

		it("gives the mount itself for a 1 x 1 grid", function()
			local origins = VacuumMountFormulas.rays(Vector2.new(0.1, 0.3), Vector2.new(0.2, 0.2), 1, 1, 2)
			expect(#origins).to.equal(1)
			expect(nearV(origins[1], Vector3.new(0.1, 0.3, 2))).to.equal(true)
		end)
	end)

	describe("backDepth", function()
		it("is the outermost surface hit, so the plate never sinks into any of it", function()
			expect(VacuumMountFormulas.backDepth({ 0.39, 0.41, 0.4 }, 0.5, 0, 1)).to.equal(0.41)
		end)

		it("is the fallback when nothing was hit", function()
			expect(VacuumMountFormulas.backDepth({}, 0.5, 0, 1)).to.equal(0.5)
		end)

		it("is kept within the limits (a stray hit far out or one inside the body)", function()
			expect(VacuumMountFormulas.backDepth({ 3 }, 0.5, 0, 1)).to.equal(1)
			expect(VacuumMountFormulas.backDepth({ -0.2 }, 0.5, 0, 1)).to.equal(0)
		end)
	end)

	describe("backFrame", function()
		it("keeps the mount's height, side and turn and moves it onto the back's surface", function()
			local mount = CFrame.new(0.05, 0.2, 0.64) * CFrame.Angles(0.1, 0, 0)
			local back = VacuumMountFormulas.backFrame(mount, 0.4)
			expect(nearV(back.Position, Vector3.new(0.05, 0.2, 0.4))).to.equal(true)
			expect(nearV(back.LookVector, mount.LookVector)).to.equal(true)
		end)
	end)

	describe("plateFrame", function()
		it("is the middle of the pad's front face (toward the wearer, -Z in pack space)", function()
			local plate = VacuumMountFormulas.plateFrame(CFrame.new(0, 0, 0.035), Vector3.new(0.4, 0.56, 0.08))
			expect(nearV(plate.Position, Vector3.new(0, 0, -0.005))).to.equal(true)
		end)

		it("follows a turned pad", function()
			local plate = VacuumMountFormulas.plateFrame(
				CFrame.new(0, 1, 0) * CFrame.Angles(0, math.pi / 2, 0),
				Vector3.new(0.4, 0.5, 0.2)
			)
			-- The pad's own -Z is pack -X after a quarter turn.
			expect(nearV(plate.Position, Vector3.new(-0.1, 1, 0))).to.equal(true)
		end)
	end)

	describe("pivotFor", function()
		it("puts the pack where its plate meets the back exactly (any pack, any back)", function()
			local back = CFrame.new(3, 4, 5) * CFrame.Angles(0, 0.4, 0)
			local plate = CFrame.new(0.1, -0.2, -0.05) * CFrame.Angles(0.2, 0, 0)
			local pivot = VacuumMountFormulas.pivotFor(back, plate)
			local plateWorld = pivot * plate
			expect(nearV(plateWorld.Position, back.Position)).to.equal(true)
			expect(nearV(plateWorld.LookVector, back.LookVector)).to.equal(true)
		end)
	end)

	describe("gap", function()
		it("is how far the plate stands off the back (negative: sunk in)", function()
			expect(near(VacuumMountFormulas.gap(0.64, 0.4), 0.24)).to.equal(true)
			expect(near(VacuumMountFormulas.gap(0.38, 0.63), -0.25)).to.equal(true)
		end)
	end)
end
