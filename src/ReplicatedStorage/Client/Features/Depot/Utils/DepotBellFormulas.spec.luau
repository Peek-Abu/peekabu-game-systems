local DepotBellFormulas = require(script.Parent.DepotBellFormulas)

return function()
	local T = DepotBellFormulas.TUNING

	describe("wave", function()
		it("is one gold ring (owner pick B): it grows from small to its full size and fades out", function()
			expect(#T.waves).to.equal(1)
			local wave = T.waves[1]
			expect(DepotBellFormulas.wave(1, wave.delay - 0.01).live).to.equal(false)
			local first = DepotBellFormulas.wave(1, wave.delay)
			expect(first.live).to.equal(true)
			expect(first.studs).to.be.near(T.waveStart, 1e-6)
			expect(first.transparency).to.be.near(wave.alpha, 1e-6)
			local last = DepotBellFormulas.wave(1, wave.delay + T.waveSeconds)
			expect(last.studs).to.be.near(T.waveStart + wave.grow, 1e-6)
			expect(last.transparency).to.be.near(1, 1e-6)
			expect(DepotBellFormulas.wave(1, wave.delay + T.waveSeconds + 0.01).live).to.equal(false)
		end)

		it("grows fast then slows (eases out)", function()
			local early = DepotBellFormulas.wave(1, 0.1).studs - DepotBellFormulas.wave(1, 0).studs
			local late = DepotBellFormulas.wave(1, T.waveSeconds).studs
				- DepotBellFormulas.wave(1, T.waveSeconds - 0.1).studs
			expect(early > late).to.equal(true)
		end)
	end)

	describe("glow", function()
		it("starts at 0, fades up quickly, holds, then fades back down to 0 (owner: never snap a light)", function()
			expect(DepotBellFormulas.glow(0)).to.equal(0)
			local up = DepotBellFormulas.glow(T.glowIn / 2)
			expect(up > 0 and up < T.glowBrightness).to.equal(true)
			expect(DepotBellFormulas.glow(T.glowIn)).to.be.near(T.glowBrightness, 1e-6)
			expect(DepotBellFormulas.glow(T.glowIn + T.glowHold)).to.be.near(T.glowBrightness, 1e-6)
			local down = DepotBellFormulas.glow(T.glowIn + T.glowHold + T.glowOut / 2)
			expect(down > 0 and down < T.glowBrightness).to.equal(true)
			expect(DepotBellFormulas.glow(DepotBellFormulas.glowSeconds())).to.be.near(0, 1e-6)
			expect(DepotBellFormulas.glow(DepotBellFormulas.glowSeconds() + 1)).to.equal(0)
			expect(DepotBellFormulas.glow(-0.1)).to.equal(0)
		end)

		it("never jumps: no two frames 1/60 s apart differ by more than a small step", function()
			local most, previous = 0, DepotBellFormulas.glow(0)
			for frame = 1, 60 do
				local now = DepotBellFormulas.glow(frame / 60)
				most = math.max(most, math.abs(now - previous))
				previous = now
			end
			expect(most < T.glowBrightness * 0.5).to.equal(true)
		end)

		it("keeps the bell a quick, kid-safe light (tier 3: at most 0.4 s, brightness 6)", function()
			expect(DepotBellFormulas.glowSeconds() <= 0.4 + 1e-6).to.equal(true)
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

		it("is the big DING! of pick B", function()
			expect(T.word).to.equal(true)
			expect(T.wordText).to.equal("DING!")
			expect(T.wordStuds >= 6).to.equal(true)
		end)
	end)

	it("lasts as long as its longest part", function()
		local longest = math.max(T.wordSeconds, DepotBellFormulas.glowSeconds())
		for _, wave in T.waves do
			longest = math.max(longest, wave.delay + T.waveSeconds)
		end
		expect(DepotBellFormulas.duration()).to.be.near(longest, 1e-6)
	end)
end
