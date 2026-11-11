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

	describe("placeOf", function()
		local boxes = {
			{ min = Vector3.new(0, 0, 0), max = Vector3.new(10, 10, 10) },
			{ min = Vector3.new(100, 0, 0), max = Vector3.new(110, 10, 10) },
		}

		it("is Outside for a point in any box, edges included", function()
			expect(SoundFormulas.placeOf(Vector3.new(5, 5, 5), boxes)).to.equal("Outside")
			expect(SoundFormulas.placeOf(Vector3.new(110, 0, 10), boxes)).to.equal("Outside")
		end)

		it("is Building for a point in no box", function()
			expect(SoundFormulas.placeOf(Vector3.new(50, 5, 5), boxes)).to.equal("Building")
			expect(SoundFormulas.placeOf(Vector3.new(5, 11, 5), boxes)).to.equal("Building")
		end)

		it("is nil without boxes (the hub, a layout with no grounds)", function()
			expect(SoundFormulas.placeOf(Vector3.new(5, 5, 5), {})).to.equal(nil)
		end)

		it("is nil without a point (a 2D sound)", function()
			expect(SoundFormulas.placeOf(nil, boxes)).to.equal(nil)
		end)
	end)

	describe("placeOfPlay", function()
		local boxes = { { min = Vector3.new(0, 0, 0), max = Vector3.new(10, 10, 10) } }

		it("is where a positional play's point is, as placeOf", function()
			expect(SoundFormulas.placeOfPlay({}, Vector3.new(5, 5, 5), boxes)).to.equal("Outside")
			expect(SoundFormulas.placeOfPlay({}, Vector3.new(50, 5, 5), boxes)).to.equal("Building")
			expect(SoundFormulas.placeOfPlay({}, nil, boxes)).to.equal(nil)
		end)

		it("is the pinned place for a pinned sound, 2D or wherever it plays", function()
			expect(SoundFormulas.placeOfPlay({ place = "Outside" }, nil, boxes)).to.equal("Outside")
			expect(SoundFormulas.placeOfPlay({ place = "Building" }, nil, boxes)).to.equal("Building")
			expect(SoundFormulas.placeOfPlay({ place = "Building" }, Vector3.new(5, 5, 5), boxes)).to.equal("Building")
		end)

		it("keeps a pin without boxes (a placeless listener hears every place)", function()
			expect(SoundFormulas.placeOfPlay({ place = "Outside" }, nil, {})).to.equal("Outside")
		end)

		it("is nil for a heardEverywhere sound", function()
			expect(SoundFormulas.placeOfPlay({ heardEverywhere = true }, Vector3.new(5, 5, 5), boxes)).to.equal(nil)
		end)
	end)

	describe("placeGain", function()
		it("is 1 when the sound and the listener share a place", function()
			expect(SoundFormulas.placeGain("Building", "Building")).to.equal(1)
			expect(SoundFormulas.placeGain("Outside", "Outside")).to.equal(1)
		end)

		it("is 0 across places: nothing from inside reaches the yard, nor the other way", function()
			expect(SoundFormulas.placeGain("Building", "Outside")).to.equal(0)
			expect(SoundFormulas.placeGain("Outside", "Building")).to.equal(0)
		end)

		it("is 1 when either has no place", function()
			expect(SoundFormulas.placeGain(nil, "Outside")).to.equal(1)
			expect(SoundFormulas.placeGain("Building", nil)).to.equal(1)
			expect(SoundFormulas.placeGain(nil, nil)).to.equal(1)
		end)
	end)

	describe("dbToGain", function()
		it("is 1 at 0 dB", function()
			expect(SoundFormulas.dbToGain(0)).to.equal(1)
		end)

		it("halves the amplitude at about -6 dB and doubles it at about +6 dB", function()
			expect(SoundFormulas.dbToGain(-6)).to.be.near(0.501, 0.001)
			expect(SoundFormulas.dbToGain(6)).to.be.near(1.995, 0.001)
		end)

		it("is 10x amplitude at +20 dB and a tenth at -20 dB", function()
			expect(SoundFormulas.dbToGain(20)).to.be.near(10, 1e-9)
			expect(SoundFormulas.dbToGain(-20)).to.be.near(0.1, 1e-9)
		end)
	end)

	describe("busGain", function()
		it("is the bus's trim as a linear gain", function()
			expect(SoundFormulas.busGain({ group = "SFX", db = -6 })).to.be.near(0.501, 0.001)
		end)

		it("is 1 with no bus (the sound sits in its volume group directly)", function()
			expect(SoundFormulas.busGain(nil)).to.equal(1)
		end)

		it("never exceeds the Sound group volume cap of 10", function()
			expect(SoundFormulas.busGain({ group = "SFX", db = 40 })).to.equal(10)
		end)
	end)
end
