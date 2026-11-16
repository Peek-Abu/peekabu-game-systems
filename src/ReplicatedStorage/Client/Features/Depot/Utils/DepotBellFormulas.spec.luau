local DepotBellFormulas = require(script.Parent.DepotBellFormulas)

return function()
	local T = DepotBellFormulas.TUNING

	describe("ring", function()
		it("is two gold rings rolling out across the floor, one a beat after the other (owner pick C)", function()
			expect(#T.rings).to.equal(2)
			expect(T.rings[2].delay > T.rings[1].delay).to.equal(true)
			expect(T.rings[2].radius < T.rings[1].radius).to.equal(true)
		end)

		it("each grows from small to its full radius and fades out, live only in its own time", function()
			for index, ring in T.rings do
				expect(DepotBellFormulas.ring(index, ring.delay - 0.01).live).to.equal(false)
				local first = DepotBellFormulas.ring(index, ring.delay)
				expect(first.live).to.equal(true)
				expect(first.radius).to.be.near(T.ringStart, 1e-6)
				expect(first.transparency).to.be.near(ring.alpha, 1e-6)
				local last = DepotBellFormulas.ring(index, ring.delay + T.ringSeconds)
				expect(last.radius).to.be.near(T.ringStart + ring.radius, 1e-6)
				expect(last.transparency).to.be.near(1, 1e-6)
				expect(DepotBellFormulas.ring(index, ring.delay + T.ringSeconds + 0.01).live).to.equal(false)
			end
		end)

		it("rolls out fast then slows (eases out), and holds solid before it fades", function()
			local early = DepotBellFormulas.ring(1, 0.1).radius - DepotBellFormulas.ring(1, 0).radius
			local late = DepotBellFormulas.ring(1, T.ringSeconds).radius
				- DepotBellFormulas.ring(1, T.ringSeconds - 0.1).radius
			expect(early > late).to.equal(true)
			local held = DepotBellFormulas.ring(1, T.ringSeconds * T.ringHold)
			expect(held.transparency).to.be.near(T.rings[1].alpha, 1e-6)
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

	it("lasts as long as its longest part", function()
		local longest = DepotBellFormulas.glowSeconds()
		for _, ring in T.rings do
			longest = math.max(longest, ring.delay + T.ringSeconds)
		end
		expect(DepotBellFormulas.duration()).to.be.near(longest, 1e-6)
	end)
end
