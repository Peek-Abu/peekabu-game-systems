local FootstepProximityFormulas = require(script.Parent.FootstepProximityFormulas)

-- Bramble's intent (owner 11-13): quiet as a bat until pretty close, then loud and quick.
local GATE = { silentBeyond = 18, loudVolume = 1.6, quickPitch = 1.12 }

return function()
	describe("scale", function()
		it("leaves a set with no gate as it is, at any distance", function()
			local near = FootstepProximityFormulas.scale(nil, 2)
			local far = FootstepProximityFormulas.scale(nil, 500)
			expect(near.volume).to.equal(1)
			expect(near.pitch).to.equal(1)
			expect(far.volume).to.equal(1)
			expect(far.pitch).to.equal(1)
		end)

		it("is silent beyond the gate", function()
			expect(FootstepProximityFormulas.scale(GATE, 18.01).volume).to.equal(0)
			expect(FootstepProximityFormulas.scale(GATE, 60).volume).to.equal(0)
		end)

		it("is suddenly loud and quick inside it, with no fade in between", function()
			local edge = FootstepProximityFormulas.scale(GATE, 18)
			local close = FootstepProximityFormulas.scale(GATE, 3)
			expect(edge.volume).to.equal(1.6)
			expect(edge.pitch).to.equal(1.12)
			expect(close.volume).to.equal(1.6)
			expect(close.pitch).to.equal(1.12)
		end)

		it("treats a missing listener (an unknown distance) as far away", function()
			expect(FootstepProximityFormulas.scale(GATE, math.huge).volume).to.equal(0)
			expect(FootstepProximityFormulas.scale(nil, math.huge).volume).to.equal(1)
		end)
	end)
end
