local DepotBellFormulas = require(script.Parent.DepotBellFormulas)

return function()
	local T = DepotBellFormulas.TUNING

	describe("wave", function()
		it("each gold ring waits its delay, grows from small to its full size and fades out", function()
			for index, wave in T.waves do
				expect(DepotBellFormulas.wave(index, wave.delay - 0.01).live).to.equal(false)
				local first = DepotBellFormulas.wave(index, wave.delay)
				expect(first.live).to.equal(true)
				expect(first.studs).to.be.near(T.waveStart, 1e-6)
				expect(first.transparency).to.be.near(wave.alpha, 1e-6)
				local last = DepotBellFormulas.wave(index, wave.delay + T.waveSeconds)
				expect(last.studs).to.be.near(T.waveStart + wave.grow, 1e-6)
				expect(last.transparency).to.be.near(1, 1e-6)
				expect(DepotBellFormulas.wave(index, wave.delay + T.waveSeconds + 0.01).live).to.equal(false)
			end
		end)

		it("grows fast then slows (eases out)", function()
			local early = DepotBellFormulas.wave(1, 0.1).studs - DepotBellFormulas.wave(1, 0).studs
			local late = DepotBellFormulas.wave(1, T.waveSeconds).studs
				- DepotBellFormulas.wave(1, T.waveSeconds - 0.1).studs
			expect(early > late).to.equal(true)
		end)
	end)

	describe("marks", function()
		it("each pair pops past full size, rises and fades, one after another", function()
			for index, pair in T.marks do
				expect(DepotBellFormulas.marks(index, pair.delay - 0.01).live).to.equal(false)
				local most = 0
				for step = 0, 20 do
					most = math.max(most, DepotBellFormulas.marks(index, pair.delay + step / 20 * T.marksSeconds).scale)
				end
				expect(most > 1).to.equal(true)
				local last = DepotBellFormulas.marks(index, pair.delay + T.marksSeconds)
				expect(last.rise).to.be.near(T.marksRise, 1e-6)
				expect(last.transparency).to.be.near(1, 1e-6)
			end
			expect(T.marks[2].delay > T.marks[1].delay).to.equal(true)
		end)
	end)

	describe("glow", function()
		it("swells and is gone within its time, never past its brightness", function()
			expect(DepotBellFormulas.glow(0)).to.be.near(0, 1e-6)
			expect(DepotBellFormulas.glow(T.glowSeconds / 2)).to.be.near(T.glowBrightness, 1e-6)
			expect(DepotBellFormulas.glow(T.glowSeconds)).to.be.near(0, 1e-6)
			expect(DepotBellFormulas.glow(T.glowSeconds + 1)).to.equal(0)
		end)

		it("keeps the bell a quick, kid-safe light (tier 3: at most 0.4 s, brightness 6)", function()
			expect(T.glowSeconds <= 0.4).to.equal(true)
			expect(T.glowBrightness <= 6).to.equal(true)
		end)
	end)

	describe("word", function()
		it("pops in past full size, rises, holds, then fades", function()
			local most = 0
			for step = 0, 20 do
				most = math.max(most, DepotBellFormulas.word(step / 20 * T.wordSeconds * 0.3).scale)
			end
			expect(most > 1).to.equal(true)
			expect(DepotBellFormulas.word(T.wordSeconds * 0.4).transparency).to.equal(0)
			local last = DepotBellFormulas.word(T.wordSeconds)
			expect(last.transparency).to.be.near(1, 1e-6)
			expect(last.rise).to.be.near(T.wordRise, 1e-6)
			expect(DepotBellFormulas.word(T.wordSeconds + 0.01).live).to.equal(false)
		end)
	end)

	it("lasts as long as its longest part", function()
		local longest = math.max(T.wordSeconds, T.glowSeconds)
		for _, wave in T.waves do
			longest = math.max(longest, wave.delay + T.waveSeconds)
		end
		for _, pair in T.marks do
			longest = math.max(longest, pair.delay + T.marksSeconds)
		end
		expect(DepotBellFormulas.duration()).to.be.near(longest, 1e-6)
	end)
end
