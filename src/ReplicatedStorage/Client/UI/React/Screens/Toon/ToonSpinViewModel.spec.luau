local VM = require(script.Parent.ToonSpinViewModel)

return function()
	describe("drag", function()
		it("turns the model with the pointer: one frame's width is DRAG_TURN degrees", function()
			local state = VM.drag(VM.new(), 100, 200, 0.1)
			expect(state.angle).to.equal(VM.DRAG_TURN / 2)
			expect(VM.drag(VM.new(), -200, 200, 0.1).angle).to.equal(-VM.DRAG_TURN)
		end)

		it("holds the model while dragging (no coasting until let go)", function()
			local state = VM.drag(VM.new(), 100, 200, 0.1)
			local after = VM.step(state, 0.5, 0)
			expect(after.angle).to.equal(state.angle)
		end)

		it("ignores a frame with no width", function()
			expect(VM.drag(VM.new(), 50, 0, 0.1).angle).to.equal(0)
		end)
	end)

	describe("release", function()
		it("coasts after a flick and slows to a stop", function()
			local state = VM.release(VM.drag(VM.new(), 100, 200, 0.05))
			expect(state.velocity > 0).to.equal(true)
			local first = VM.step(state, 0.1, 0)
			expect(first.angle > state.angle).to.equal(true)
			expect(math.abs(first.velocity) < math.abs(state.velocity)).to.equal(true)
			local later = first
			for _ = 1, 200 do
				later = VM.step(later, 0.1, 0)
			end
			expect(later.velocity).to.equal(0)
		end)

		it("caps a wild flick", function()
			local state = VM.release(VM.drag(VM.new(), 5000, 200, 0.001))
			expect(math.abs(state.velocity) <= VM.MAX_COAST).to.equal(true)
		end)

		it("does not coast after a slow drag that stopped", function()
			local held = VM.drag(VM.new(), 100, 200, 0.1)
			held = VM.drag(held, 0, 200, 0.3)
			expect(VM.release(held).velocity).to.equal(0)
		end)
	end)

	describe("stick", function()
		it("turns at STICK_SPEED while pushed all the way", function()
			local state = VM.step(VM.new(), 0.5, 1)
			expect(state.angle).to.equal(VM.STICK_SPEED * 0.5)
			expect(VM.step(VM.new(), 0.5, -1).angle).to.equal(-VM.STICK_SPEED * 0.5)
		end)

		it("ignores a stick resting inside its dead zone", function()
			expect(VM.step(VM.new(), 1, VM.STICK_DEAD * 0.9).angle).to.equal(0)
		end)

		it("stops any coasting when the stick takes over", function()
			local coasting = VM.release(VM.drag(VM.new(), 100, 200, 0.05))
			expect(VM.step(coasting, 0.1, 1).velocity).to.equal(0)
		end)
	end)

	describe("angle", function()
		it("stays within one turn", function()
			local state = VM.step(VM.new(), 10, 1)
			expect(state.angle >= -180 and state.angle < 180).to.equal(true)
		end)
	end)
end
