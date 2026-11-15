local VacuumFeelFormulas = require(script.Parent.VacuumFeelFormulas)

return function()
	describe("lean", function()
		it("leans a pile toward the nozzle, more as it nears done", function()
			local start = VacuumFeelFormulas.lean(2, 0)
			local late = VacuumFeelFormulas.lean(2, 1)
			expect(start > 0 and late > start).to.equal(true)
			expect(late <= VacuumFeelFormulas.MAX_LEAN).to.equal(true)
		end)

		it("leans less when the nozzle is far, never backwards", function()
			expect(VacuumFeelFormulas.lean(12, 1) < VacuumFeelFormulas.lean(2, 1)).to.equal(true)
			expect(VacuumFeelFormulas.lean(100, 1) >= 0).to.equal(true)
		end)
	end)

	describe("stretch", function()
		it("stretches a pile up toward the nozzle and thins it, keeping about its volume", function()
			local up, across = VacuumFeelFormulas.stretch(1, 0)
			expect(up > 1 and across < 1).to.equal(true)
			expect(math.abs(up * across * across - 1) < 0.01).to.equal(true)
		end)

		it("is the plain pile with no pull, and a tug stretches it further", function()
			local up, across = VacuumFeelFormulas.stretch(0, 0)
			expect(up).to.equal(1)
			expect(across).to.equal(1)
			expect(VacuumFeelFormulas.stretch(0.5, 1) > VacuumFeelFormulas.stretch(0.5, 0)).to.equal(true)
		end)
	end)

	describe("wobble", function()
		it("is small at the start of a pile and grows as it nears done", function()
			local function peak(progress)
				local most = 0
				for step = 0, 200 do
					most = math.max(most, math.abs(VacuumFeelFormulas.wobble(step / 60, 7, progress)))
				end
				return most
			end
			expect(peak(1) > peak(0) * 2).to.equal(true)
			expect(peak(1) <= VacuumFeelFormulas.MAX_WOBBLE + 1e-9).to.equal(true)
		end)
	end)

	describe("camera", function()
		it("widens the view a little while sucking, more near done, none when not", function()
			expect(VacuumFeelFormulas.fov(false, 1)).to.equal(0)
			local start = VacuumFeelFormulas.fov(true, 0)
			local late = VacuumFeelFormulas.fov(true, 1)
			expect(start > 0 and late > start).to.equal(true)
			expect(late <= 6).to.equal(true)
		end)

		it("adds strain only once a pile is well under way, growing to its most", function()
			expect(VacuumFeelFormulas.strain(0.1)).to.equal(0)
			expect(VacuumFeelFormulas.strain(1) > VacuumFeelFormulas.strain(0.6)).to.equal(true)
			expect(VacuumFeelFormulas.strain(1) <= VacuumFeelFormulas.MAX_STRAIN).to.equal(true)
		end)

		it("punches a bigger pop harder, within bounds", function()
			expect(VacuumFeelFormulas.popTrauma(8) > VacuumFeelFormulas.popTrauma(3)).to.equal(true)
			expect(VacuumFeelFormulas.popTrauma(100) <= 0.45).to.equal(true)
			expect(VacuumFeelFormulas.popTrauma(0) > 0).to.equal(true)
		end)
	end)

	describe("hose", function()
		local tuning = { swing0 = 0.6, swing1 = 0.9, wiggle = 0.25, wiggleHz = 3, floor = 0.2 }

		it("is the planned curve when the wand is still and not sucking", function()
			local c0, c1 = VacuumFeelFormulas.hose(0.8, 0.24, 0, 1.3, 5, 0, tuning)
			expect(c0).to.equal(0.8)
			expect(c1).to.equal(0.24)
		end)

		it("swings the curve with the wand's move, both ends the other way", function()
			local up0, up1 = VacuumFeelFormulas.hose(0.8, 0.24, 0.5, 0, 0, 0, tuning)
			local down0, down1 = VacuumFeelFormulas.hose(0.8, 0.24, -0.5, 0, 0, 0, tuning)
			expect(up0 > 0.8 and down0 < 0.8).to.equal(true)
			expect(up1 < 0.24 and down1 > 0.24).to.equal(true)
		end)

		it("wiggles while sucking, within its share, and never folds the hose flat", function()
			local most = 0
			for step = 0, 120 do
				local c0 = VacuumFeelFormulas.hose(0.8, 0.24, 0, step / 60, 3, 1, tuning)
				most = math.max(most, math.abs(c0 - 0.8))
			end
			expect(most > 0.05 and most <= 0.8 * tuning.wiggle + 1e-9).to.equal(true)
			local c0, c1 = VacuumFeelFormulas.hose(0.8, 0.24, -10, 0, 0, 1, tuning)
			expect(c0 >= 0.8 * tuning.floor - 1e-9 and c1 >= 0.24 * tuning.floor - 1e-9).to.equal(true)
		end)
	end)
	describe("pileScale (P1: piles shrink smoothly)", function()
		it("is the pile's height over its full height, within 0..1", function()
			local base = Vector3.new(4, 2, 4)
			expect(VacuumFeelFormulas.pileScale(Vector3.new(4, 2, 4), base)).to.be.near(1, 1e-9)
			expect(VacuumFeelFormulas.pileScale(Vector3.new(2, 1, 2), base)).to.be.near(0.5, 1e-9)
			expect(VacuumFeelFormulas.pileScale(Vector3.new(8, 4, 8), base)).to.be.near(1, 1e-9)
		end)

		it("reads full size when the full size is unknown", function()
			expect(VacuumFeelFormulas.pileScale(Vector3.new(1, 1, 1), nil)).to.equal(1)
			expect(VacuumFeelFormulas.pileScale(Vector3.new(1, 1, 1), Vector3.zero)).to.equal(1)
		end)
	end)

	describe("shrinkTo (P1: piles shrink smoothly)", function()
		it("glides through the server's steps instead of jumping with each", function()
			-- The server steps the pile 0.05 smaller every 0.1 s; at 60 frames a second the shown scale never moves
			-- more than a share of a step in one frame.
			local shown, speed, target = 1, 0, 1
			local most = 0
			for frame = 1, 120 do
				if frame % 6 == 0 then
					target = math.max(0.35, target - 0.05)
				end
				local before = shown
				shown, speed = VacuumFeelFormulas.shrinkTo(shown, speed, target, 1 / 60)
				most = math.max(most, math.abs(shown - before))
			end
			expect(most < 0.05 / 2).to.equal(true)
		end)

		it("settles on the server's scale once it stops changing, without overshooting it", function()
			local shown, speed = 1, 0
			local least = 1
			for _ = 1, 120 do
				shown, speed = VacuumFeelFormulas.shrinkTo(shown, speed, 0.5, 1 / 60)
				least = math.min(least, shown)
			end
			expect(shown).to.be.near(0.5, 1e-3)
			expect(least >= 0.5 - 1e-3).to.equal(true)
		end)
	end)

	describe("pieceFrame (an art pile's stand-in)", function()
		local floor = CFrame.new(10, 0, 5)
		local piece = CFrame.new(1, 2, 0)

		it("puts each piece where the art had it at full size and no lean", function()
			local frame = VacuumFeelFormulas.pieceFrame(floor, CFrame.identity, piece, 1, 1, 1)
			expect((frame.Position - Vector3.new(11, 2, 5)).Magnitude).to.be.near(0, 1e-6)
		end)

		it("shrinks the pieces toward the floor point, never below the floor", function()
			local frame = VacuumFeelFormulas.pieceFrame(floor, CFrame.identity, piece, 0.5, 1, 1)
			expect((frame.Position - Vector3.new(10.5, 1, 5)).Magnitude).to.be.near(0, 1e-6)
		end)

		it("stretches up and thins across", function()
			local frame = VacuumFeelFormulas.pieceFrame(floor, CFrame.identity, piece, 1, 1.5, 0.8)
			expect((frame.Position - Vector3.new(10.8, 3, 5)).Magnitude).to.be.near(0, 1e-6)
		end)

		it("leans about the floor point", function()
			local tilt = CFrame.fromAxisAngle(Vector3.xAxis, -math.pi / 2)
			local frame = VacuumFeelFormulas.pieceFrame(floor, tilt, CFrame.new(0, 2, 0), 1, 1, 1)
			expect(frame.Position.Y).to.be.near(0, 1e-6)
			expect((frame.Position - Vector3.new(10, 0, 3)).Magnitude).to.be.near(0, 1e-6)
		end)
	end)

	describe("airFlow (P1: air rushes into the nozzle)", function()
		-- A floor head 1.2 wide, 0.3 tall, 0.5 deep, its bottom on the floor (y 0), 3 studs ahead of a root at y 3.
		local head = CFrame.new(0, 0.15, -3)
		local size = Vector3.new(1.2, 0.3, 0.5)
		local root = Vector3.new(0, 3, 0)

		it("pulls into the head's mouth, just over the floor", function()
			local _, sink = VacuumFeelFormulas.airFlow(head, size, root)
			expect(math.abs(sink.X)).to.be.near(0, 1e-6)
			expect(sink.Y > 0 and sink.Y < 0.3).to.equal(true)
			expect(sink.Z).to.be.near(-3, 1e-6)
		end)

		it("comes from ahead of the head (away from the holder) and above the floor", function()
			local source, sink = VacuumFeelFormulas.airFlow(head, size, root)
			expect(source.Z < sink.Z - 0.5).to.equal(true)
			expect(source.Y > sink.Y + 0.3).to.equal(true)
		end)

		it("draws from wider than the head, so the air fans in over it", function()
			local _, _, radius = VacuumFeelFormulas.airFlow(head, size, root)
			expect(radius >= 1.2 and radius <= 1.2 * 2.5).to.equal(true)
		end)

		it("turns with the holder: a head off to the right takes its air from further right", function()
			local source = VacuumFeelFormulas.airFlow(CFrame.new(3, 0.15, 0), size, root)
			expect(source.X > 3.5).to.equal(true)
		end)
	end)
end
