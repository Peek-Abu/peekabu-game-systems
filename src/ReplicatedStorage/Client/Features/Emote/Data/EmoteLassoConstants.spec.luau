local EmoteLassoConstants = require(script.Parent.EmoteLassoConstants)

return function()
	local T = EmoteLassoConstants.TUNING

	it("spins the loop at the owner's pick, 1.5x the clip", function()
		expect(T.spinMul).to.equal(1.5)
	end)

	it("keeps every rope joint from folding back (bend limits under 90 degrees, ends stiffer)", function()
		expect(T.bendEnds < T.bendMid).to.equal(true)
		expect(T.bendMid < 90).to.equal(true)
		expect(T.bendEnds > 0).to.equal(true)
	end)

	it("has a chain and a ring with enough points to bend smoothly", function()
		expect(T.ropePoints >= 6).to.equal(true)
		expect(T.ringPoints >= 8).to.equal(true)
	end)

	it("pulls the knot harder than the ring's far side, so the far side trails", function()
		expect(T.pullKnot > T.pullNear).to.equal(true)
		expect(T.pullNear > T.pullFar).to.equal(true)
	end)

	it("steps on a fixed substep with a cap per frame", function()
		expect(T.substep > 0 and T.substep <= 1 / 120).to.equal(true)
		expect(T.maxSubsteps >= 4).to.equal(true)
	end)

	it("matches the LassoLoop mesh: the knot sits the rope's length straight above the grip", function()
		local rise = EmoteLassoConstants.KNOT - EmoteLassoConstants.GRIP
		expect(math.abs(rise.X) < 1e-6 and math.abs(rise.Z) < 1e-6).to.equal(true)
		expect(math.abs(rise.Y - T.ropeLength) < 1e-6).to.equal(true)
	end)
end
