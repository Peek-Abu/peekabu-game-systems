local VacuumBodyFormulas = require(script.Parent.VacuumBodyFormulas)

return function()
	describe("box", function()
		it("covers every visible piece of the chest, clothes included (owner plan A, 2026-11-16)", function()
			-- A thin torso part and a hoodie piece around it, both in the torso's rest frame.
			local box = VacuumBodyFormulas.box({
				{ at = CFrame.identity, size = Vector3.new(0.62, 1.65, 0.6) },
				{ at = CFrame.new(0, 0.2, -0.05), size = Vector3.new(0.92, 0.99, 0.94) },
			})
			expect(box.half.X).to.be.near(0.46, 1e-6)
			expect(box.half.Z).to.be.near(0.47, 1e-6)
			-- Its front reaches the hoodie's front, not the thin torso's.
			expect(box.centre.Z - box.half.Z).to.be.near(-0.05 - 0.47, 1e-6)
			expect(box.centre.Y + box.half.Y).to.be.near(0.825, 1e-6)
		end)

		it("is the part's own box for a body with no clothes", function()
			local box = VacuumBodyFormulas.box({ { at = CFrame.new(0, 0.5, 0), size = Vector3.new(1, 2, 1) } })
			expect((box.centre - Vector3.new(0, 0.5, 0)).Magnitude).to.be.near(0, 1e-6)
			expect((box.half - Vector3.new(0.5, 1, 0.5)).Magnitude).to.be.near(0, 1e-6)
		end)

		it("measures a turned piece by its corners", function()
			local box = VacuumBodyFormulas.box({
				{ at = CFrame.Angles(0, math.rad(90), 0), size = Vector3.new(2, 1, 0.5) },
			})
			expect(box.half.X).to.be.near(0.25, 1e-6)
			expect(box.half.Z).to.be.near(1, 1e-6)
		end)
	end)

	describe("pivot", function()
		it("turns the wand about the point between the paws, in front of the chest (owner plan C)", function()
			local right, left = Vector3.new(0.4, 1.15, -0.8), Vector3.new(0.1, 0.6, -1.2)
			expect((VacuumBodyFormulas.pivot(right, left) - (right + left) / 2).Magnitude).to.be.near(0, 1e-6)
		end)

		it("turns about the right paw when there is no left paw", function()
			local right = Vector3.new(0.4, 1.15, -0.8)
			expect(VacuumBodyFormulas.pivot(right, nil)).to.equal(right)
		end)
	end)

	describe("follow", function()
		it("moves a held point with the chest: where the chest went from its rest pose (owner plan B)", function()
			local rest = CFrame.new(0, 0.7, 0)
			-- The idle sways the chest 0.28 stud right and turns it 13 degrees.
			local now = CFrame.new(0.28, 0.7, 0) * CFrame.Angles(0, math.rad(13), 0)
			local delta = VacuumBodyFormulas.follow(rest, now, 1)
			local hand = Vector3.new(0.4, 1.1, -0.8)
			-- The hand keeps its place relative to the chest.
			local before = rest:PointToObjectSpace(hand)
			local after = now:PointToObjectSpace(delta * hand)
			expect((before - after).Magnitude).to.be.near(0, 1e-6)
		end)

		it(
			"never follows the chest's tilt or height, only its sway and turn (the idle's standing lean tipped the wand into the floor)",
			function()
				local rest = CFrame.new(0, 0.7, 0)
				-- Leaned 23 degrees forward and dropped 0.2, with no sway or turn.
				local leaned = CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(-23), 0, 0)
				local delta = VacuumBodyFormulas.follow(rest, leaned, 1)
				local hand = Vector3.new(0.4, 1.1, -0.8)
				expect(((delta * hand) - hand).Magnitude).to.be.near(0, 1e-6)
				-- Swayed and turned AND leaned: only the sway and the turn are followed, heights kept.
				local moved = CFrame.new(0.28, 0.5, 0)
					* CFrame.Angles(0, math.rad(13), 0)
					* CFrame.Angles(math.rad(-23), 0, 0)
				local follow = VacuumBodyFormulas.follow(rest, moved, 1)
				expect((follow * hand).Y).to.be.near(hand.Y, 1e-6)
				local _, yaw = follow:ToOrientation()
				expect(yaw).to.be.near(math.rad(13), 1e-4)
			end
		)

		it("is no move when the chest is at rest, and blends by `share`", function()
			local rest = CFrame.new(0, 0.7, 0)
			local function still(cf)
				local _, angle = cf:ToAxisAngle()
				return cf.Position.Magnitude < 1e-6 and math.abs(angle) < 1e-6
			end
			expect(still(VacuumBodyFormulas.follow(rest, rest, 1))).to.equal(true)
			local now = CFrame.new(0.2, 0.7, 0)
			expect(still(VacuumBodyFormulas.follow(rest, now, 0))).to.equal(true)
			expect(VacuumBodyFormulas.follow(rest, now, 0.5).Position.X).to.be.near(0.1, 1e-6)
		end)
	end)
end
