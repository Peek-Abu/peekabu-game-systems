local Formulas = require(script.Parent.AnimationCarryGrabFormulas)

return function()
	local FROM = CFrame.new(0, 0.5, -3)
	local TO = CFrame.new(0, 2.5, -1.5) * CFrame.Angles(0, math.rad(40), 0)

	describe("plays", function()
		it("plays for cargo picked up within reach of a prompt", function()
			expect(Formulas.plays(FROM, TO)).to.equal(true)
		end)

		it("skips cargo that was already in the hands, or came from far away (a teleport, a stale origin)", function()
			expect(Formulas.plays(TO, TO)).to.equal(false)
			expect(Formulas.plays(CFrame.new(0, 0, -100), TO)).to.equal(false)
		end)
	end)

	describe("pose", function()
		it("holds the cargo where it lay while the arms reach for it", function()
			expect(Formulas.pose(FROM, TO, 0)).to.equal(FROM)
			expect(Formulas.pose(FROM, TO, Formulas.REACH_SECONDS * 0.9)).to.equal(FROM)
		end)

		it("lifts it into the hands, ending exactly on the hold", function()
			local finish = Formulas.REACH_SECONDS + Formulas.LIFT_SECONDS
			local mid = Formulas.pose(FROM, TO, Formulas.REACH_SECONDS + Formulas.LIFT_SECONDS / 2)
			expect(mid.Position.Y > FROM.Position.Y).to.equal(true)
			expect(mid.Position.Y < TO.Position.Y + Formulas.ARC).to.equal(true)
			local final = Formulas.pose(FROM, TO, finish)
			expect((final.Position - TO.Position).Magnitude < 1e-4).to.equal(true)
			expect(final.LookVector:Dot(TO.LookVector) > 0.9999).to.equal(true)
			expect(Formulas.pose(FROM, TO, finish + 5)).to.equal(TO)
		end)

		it("rises a little above the straight line mid-lift (a scoop, not a slide)", function()
			local half = Formulas.REACH_SECONDS + Formulas.LIFT_SECONDS / 2
			local straight = FROM.Position:Lerp(TO.Position, 0.5)
			expect(Formulas.pose(FROM, TO, half).Position.Y > straight.Y).to.equal(true)
		end)
	end)

	describe("finished", function()
		it("is short and snappy: done within half a second", function()
			expect(Formulas.finished(0)).to.equal(false)
			expect(Formulas.finished(Formulas.REACH_SECONDS + Formulas.LIFT_SECONDS)).to.equal(true)
			expect(Formulas.REACH_SECONDS + Formulas.LIFT_SECONDS <= 0.5).to.equal(true)
		end)
	end)
end
