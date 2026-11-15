local VacuumAirFormulas = require(script.Parent.VacuumAirFormulas)

return function()
	local source = Vector3.new(0, 1, -3)
	local sink = Vector3.new(0, 0.1, 0)

	-- Distance from the flow's axis (the line from the sink to the source).
	local function offAxis(point)
		local axis = (source - sink).Unit
		local rel = point - sink
		return (rel - axis * rel:Dot(axis)).Magnitude
	end

	describe("travel", function()
		it("starts slow and speeds up into the mouth", function()
			expect(VacuumAirFormulas.travel(0, 0.6)).to.equal(0)
			expect(VacuumAirFormulas.travel(0.15, 0.6) < 0.25).to.equal(true)
			local early = VacuumAirFormulas.travel(0.2, 0.6) - VacuumAirFormulas.travel(0.1, 0.6)
			local late = VacuumAirFormulas.travel(0.6, 0.6) - VacuumAirFormulas.travel(0.5, 0.6)
			expect(late > early * 2).to.equal(true)
			expect(VacuumAirFormulas.travel(0.6, 0.6)).to.equal(1)
			expect(VacuumAirFormulas.travel(5, 0.6)).to.equal(1)
		end)
	end)

	describe("spiral", function()
		it("is born on a ring about the source and ends in the mouth", function()
			local born = VacuumAirFormulas.spiral(source, sink, 1.5, 0, 0.7, 1.25)
			expect((born - source).Magnitude).to.be.near(1.5, 1e-4)
			expect(offAxis(born)).to.be.near(1.5, 1e-4)
			local done = VacuumAirFormulas.spiral(source, sink, 1.5, 1, 0.7, 1.25)
			expect((done - sink).Magnitude).to.be.near(0, 1e-4)
		end)

		it("closes in on the axis all the way", function()
			local last = math.huge
			for step = 0, 20 do
				local r = offAxis(VacuumAirFormulas.spiral(source, sink, 1.5, step / 20, 0, 1.25))
				expect(r <= last + 1e-6).to.equal(true)
				last = r
			end
		end)

		it("turns about the axis, faster near the mouth (it swirls in, never a straight line)", function()
			local function angleAt(u)
				local axis = (source - sink).Unit
				local side = axis:Cross(Vector3.yAxis).Unit
				local up = side:Cross(axis)
				local rel = VacuumAirFormulas.spiral(source, sink, 1.5, u, 0, 1.25) - sink
				return math.atan2(rel:Dot(up), rel:Dot(side))
			end
			local function turned(a, b)
				local d = angleAt(b) - angleAt(a)
				return math.abs((d + math.pi) % (2 * math.pi) - math.pi)
			end
			expect(turned(0, 0.1) > 0.01).to.equal(true)
			expect(turned(0.8, 0.9) > turned(0, 0.1)).to.equal(true)
		end)

		it("copes with a flow straight up or down", function()
			local p = VacuumAirFormulas.spiral(Vector3.new(0, 3, 0), Vector3.zero, 1, 0.5, 0, 1)
			expect(p.X == p.X and p.Y == p.Y and p.Z == p.Z).to.equal(true)
		end)
	end)

	describe("blob", function()
		it("is round at rest and stretches along its flight as it speeds up, about its volume kept", function()
			local along, across = VacuumAirFormulas.blob(0)
			expect(along).to.equal(1)
			expect(across).to.equal(1)
			local slow = VacuumAirFormulas.blob(3)
			local fast, thin = VacuumAirFormulas.blob(12)
			expect(fast > slow and slow > 1).to.equal(true)
			expect(fast <= 1 + VacuumAirFormulas.MAX_BLOB_STRETCH + 1e-9).to.equal(true)
			expect(fast * thin * thin).to.be.near(1, 1e-6)
		end)

		it("swells as it tears off, then shrinks into the mouth", function()
			expect(VacuumAirFormulas.blobSize(0)).to.equal(0)
			expect(VacuumAirFormulas.blobSize(0.3)).to.be.near(1, 1e-6)
			expect(VacuumAirFormulas.blobSize(1) < 0.5).to.equal(true)
		end)
	end)
end
