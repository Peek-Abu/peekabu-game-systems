local SoundFormulas = require(script.Parent.SoundFormulas)

return function()
	describe("pickPitch", function()
		it("is 1 without a range", function()
			expect(SoundFormulas.pickPitch(nil, 0.7)).to.equal(1)
		end)

		it("maps the roll onto the range", function()
			local range = { min = 0.8, max = 1.2 }
			expect(SoundFormulas.pickPitch(range, 0)).to.be.near(0.8)
			expect(SoundFormulas.pickPitch(range, 1)).to.be.near(1.2)
			expect(SoundFormulas.pickPitch(range, 0.5)).to.be.near(1)
		end)

		it("clamps an out-of-range roll", function()
			expect(SoundFormulas.pickPitch({ min = 0.8, max = 1.2 }, 2)).to.be.near(1.2)
		end)
	end)

	describe("listenersInRange", function()
		it("keeps only listeners within the radius, sorted by id", function()
			local listeners = {
				{ id = 3, position = Vector3.new(0, 0, 10) },
				{ id = 1, position = Vector3.new(0, 0, 0) },
				{ id = 2, position = Vector3.new(0, 0, 500) },
			}
			local heard = SoundFormulas.listenersInRange(Vector3.zero, 50, listeners)
			expect(#heard).to.equal(2)
			expect(heard[1]).to.equal(1)
			expect(heard[2]).to.equal(3)
		end)

		it("includes a listener exactly on the edge", function()
			local heard =
				SoundFormulas.listenersInRange(Vector3.zero, 10, { { id = 1, position = Vector3.new(10, 0, 0) } })
			expect(#heard).to.equal(1)
		end)

		it("skips listeners with no position (not spawned)", function()
			local heard = SoundFormulas.listenersInRange(Vector3.zero, 10, { { id = 1, position = nil } })
			expect(#heard).to.equal(0)
		end)
	end)
end
