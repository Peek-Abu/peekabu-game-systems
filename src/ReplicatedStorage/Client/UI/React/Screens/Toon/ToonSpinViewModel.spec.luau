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

	describe("around", function()
		-- A figure whose box reaches further right than left of its root (a held lasso).
		local box = { min = Vector3.new(-1, 0, -0.5), max = Vector3.new(3, 5, 0.5) }
		local root = Vector3.new(0, 2, 0)

		it("centres the box on the root, so the turning model stays in the middle of the frame", function()
			local wide = VM.around(box, root)
			local centre = (wide.min + wide.max) / 2
			expect(centre.X).to.be.near(0, 1e-6)
			expect(centre.Z).to.be.near(0, 1e-6)
		end)

		it("holds every corner of the model at any angle, and keeps its height", function()
			local wide = VM.around(box, root)
			for degrees = 0, 350, 10 do
				local spin = VM.turn(CFrame.identity, root, degrees)
				for _, x in { box.min.X, box.max.X } do
					for _, z in { box.min.Z, box.max.Z } do
						local p = spin * Vector3.new(x, 0, z)
						expect(p.X >= wide.min.X - 1e-6 and p.X <= wide.max.X + 1e-6).to.equal(true)
						expect(p.Z >= wide.min.Z - 1e-6 and p.Z <= wide.max.Z + 1e-6).to.equal(true)
					end
				end
			end
			expect(wide.min.Y).to.equal(0)
			expect(wide.max.Y).to.equal(5)
		end)

		it(
			"keeps the camera centred when a turning model's props reach out (a growing box stays on the root)",
			function()
				local PortraitViewModel = require(script.Parent.Parent.Portrait.PortraitViewModel)
				local fitted = VM.around(box, root)
				-- A Legendary's showcase prop held far out to one side, after a quarter turn.
				local seen = { min = Vector3.new(-1, 0, -0.5), max = Vector3.new(1, 5, 4) }
				local raw = PortraitViewModel.grow(fitted, seen)
				local rawCentre = (raw.min + raw.max) / 2
				-- Growing by the raw box drifts off the root (the bug the owner saw on Legendary skins).
				expect(math.abs(rawCentre.Z) > 0.1).to.equal(true)
				local grown = PortraitViewModel.grow(fitted, VM.around(seen, root))
				local centre = (grown.min + grown.max) / 2
				expect(centre.X).to.be.near(0, 1e-6)
				expect(centre.Z).to.be.near(0, 1e-6)
				expect(grown.max.Z >= 4).to.equal(true)
			end
		)
	end)

	describe("turn", function()
		it("turns a model about its own upright axis, leaving the root where it stands", function()
			local home = CFrame.new(4, 2, -3)
			local root = Vector3.new(4, 2, -3)
			local turned = VM.turn(home, root, 90)
			expect(turned.Position:FuzzyEq(home.Position, 1e-5)).to.equal(true)
			expect(turned.UpVector:FuzzyEq(Vector3.yAxis, 1e-5)).to.equal(true)
		end)

		it(
			"turns the front to the screen's right for a positive angle (the camera looks along +Z at the front)",
			function()
				local turned = VM.turn(CFrame.identity, Vector3.zero, 30)
				-- The front faces -Z; seen from -Z, screen right is world -X.
				expect(turned.LookVector.X < 0).to.equal(true)
			end
		)

		it("is the home frame at 0", function()
			local home = CFrame.new(1, 2, 3) * CFrame.Angles(0, 0.4, 0)
			expect(VM.turn(home, Vector3.new(1, 0, 3), 0):FuzzyEq(home, 1e-6)).to.equal(true)
		end)
	end)
end
