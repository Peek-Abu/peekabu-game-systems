local FilmPathFormulas = require(script.Parent.FilmPathFormulas)

local function mark(position, look, fov)
	return { position = position, look = look or Vector3.new(0, 0, -1), fov = fov or 70 }
end

local function near(a, b, tolerance)
	return (a - b).Magnitude < (tolerance or 1e-3)
end

return function()
	describe("ease", function()
		it("starts and ends at rest and is halfway at the middle", function()
			expect(FilmPathFormulas.ease(0)).to.equal(0)
			expect(FilmPathFormulas.ease(1)).to.equal(1)
			expect(math.abs(FilmPathFormulas.ease(0.5) - 0.5) < 1e-6).to.equal(true)
			expect(FilmPathFormulas.ease(0.1) < 0.1).to.equal(true)
			expect(FilmPathFormulas.ease(-1)).to.equal(0)
			expect(FilmPathFormulas.ease(2)).to.equal(1)
		end)
	end)

	describe("sample", function()
		it("holds a single mark", function()
			local path = FilmPathFormulas.build({ mark(Vector3.new(1, 2, 3), Vector3.new(1, 0, 0), 40) })
			local cframe, fov = FilmPathFormulas.sample(path, 0.7)
			expect(near(cframe.Position, Vector3.new(1, 2, 3))).to.equal(true)
			expect(near(cframe.LookVector, Vector3.new(1, 0, 0))).to.equal(true)
			expect(fov).to.equal(40)
		end)

		it("starts on the first mark and ends on the last", function()
			local path = FilmPathFormulas.build({
				mark(Vector3.new(0, 5, 0), Vector3.new(0, 0, -1), 70),
				mark(Vector3.new(10, 5, 0), Vector3.new(1, 0, 0), 50),
				mark(Vector3.new(10, 5, 20), Vector3.new(0, 0, 1), 30),
			})
			local first, fov0 = FilmPathFormulas.sample(path, 0)
			local last, fov1 = FilmPathFormulas.sample(path, 1)
			expect(near(first.Position, Vector3.new(0, 5, 0))).to.equal(true)
			expect(near(first.LookVector, Vector3.new(0, 0, -1))).to.equal(true)
			expect(math.abs(fov0 - 70) < 1e-3).to.equal(true)
			expect(near(last.Position, Vector3.new(10, 5, 20))).to.equal(true)
			expect(near(last.LookVector, Vector3.new(0, 0, 1))).to.equal(true)
			expect(math.abs(fov1 - 30) < 1e-3).to.equal(true)
		end)

		it("passes through a middle mark at its share of the path's length", function()
			local path = FilmPathFormulas.build({
				mark(Vector3.new(0, 0, 0)),
				mark(Vector3.new(10, 0, 0)),
				mark(Vector3.new(20, 0, 0)),
			})
			local middle = FilmPathFormulas.sample(path, 0.5)
			expect(near(middle.Position, Vector3.new(10, 0, 0), 0.05)).to.equal(true)
		end)

		it("moves at an even speed along a straight line", function()
			local path = FilmPathFormulas.build({ mark(Vector3.new(0, 0, 0)), mark(Vector3.new(30, 0, 0)) })
			local quarter = FilmPathFormulas.sample(path, 0.25)
			expect(near(quarter.Position, Vector3.new(7.5, 0, 0), 0.05)).to.equal(true)
		end)

		it("never rolls the camera", function()
			local path = FilmPathFormulas.build({
				mark(Vector3.new(0, 0, 0), Vector3.new(0, 0, -1)),
				mark(Vector3.new(10, 0, 0), Vector3.new(1, -0.5, 0).Unit),
			})
			for _, t in { 0.2, 0.5, 0.8 } do
				local cframe = FilmPathFormulas.sample(path, t)
				expect(math.abs(cframe.RightVector.Y) < 1e-3).to.equal(true)
			end
		end)

		it("keeps the look moving smoothly between marks (no snap)", function()
			local path = FilmPathFormulas.build({
				mark(Vector3.new(0, 0, 0), Vector3.new(0, 0, -1)),
				mark(Vector3.new(10, 0, 0), Vector3.new(1, 0, 0)),
				mark(Vector3.new(20, 0, 0), Vector3.new(0, 0, 1)),
			})
			local previous = FilmPathFormulas.sample(path, 0).LookVector
			local worst = 0
			for step = 1, 100 do
				local look = FilmPathFormulas.sample(path, step / 100).LookVector
				worst = math.max(worst, math.deg(math.acos(math.clamp(previous:Dot(look), -1, 1))))
				previous = look
			end
			expect(worst < 10).to.equal(true)
		end)
	end)
end
