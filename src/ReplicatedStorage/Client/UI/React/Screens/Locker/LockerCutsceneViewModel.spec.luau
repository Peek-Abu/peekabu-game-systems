local Cutscene = require(script.Parent.LockerCutsceneViewModel)

return function()
	describe("cutscenePose (stage 2 3D cutscene)", function()
		it("walks through establishing, approach, key_turn and burst_open for both Lockers", function()
			local start = Cutscene.cutscenePose("gloom", 0)
			expect(start.beat).to.equal("establishing")
			expect(start.doorDeg).to.equal(0)
			expect(start.glow).to.equal(false)

			local approach = Cutscene.cutscenePose("gloom", 0.35)
			expect(approach.beat).to.equal("approach")
			expect(approach.employeeCFrame.Position.X > 0).to.equal(true)
			expect(Cutscene.cutscenePose("gleam", 0.35).employeeCFrame.Position.X < 0).to.equal(true)

			local turn = Cutscene.cutscenePose("gloom", 0.65)
			expect(turn.beat).to.equal("key_turn")
			expect(turn.keyRollDeg > 0).to.equal(true)
			expect(turn.doorDeg).to.equal(0)

			local burst = Cutscene.cutscenePose("gloom", 0.92)
			expect(burst.beat).to.equal("burst_open")
			expect(burst.doorDeg > 80).to.equal(true)
			expect(burst.glow).to.equal(true)
			expect(burst.flashTransparency < 1).to.equal(true)
		end)

		-- Owner check 11-16: the camera sat behind (then inside) the employee's head, so the locker, the key and the
		-- door were never seen. The employee (about 3.5 studs wide) must stay clear of the camera's line to what it
		-- looks at, and the camera clear of the employee, in every beat after the establishing shot.
		it("never lets the employee block the camera's view of the locker", function()
			for _, id in { "gloom", "gleam", "harvest" } do
				for _, rarity in { "uncommon", "legendary" } do
					for step = 0, 50 do
						local alpha = 0.24 + 0.76 * step / 50
						local pose = Cutscene.cutscenePose(id, alpha, rarity)
						local emp = pose.employeeCFrame.Position
						local a = Vector2.new(pose.camPos.X, pose.camPos.Z)
						local b = Vector2.new(pose.camLook.X, pose.camLook.Z)
						local p = Vector2.new(emp.X, emp.Z)
						local ab = b - a
						local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
						local gap = (a + ab * t - p).Magnitude
						expect(gap > 2.2).to.equal(true)
						expect((a - p).Magnitude > 3).to.equal(true)
					end
				end
			end
		end)
	end)

	-- Owner picks 11-16: about 4 seconds, a door rattle with the prize's colour leaking out before the burst, held
	-- longer, rattled harder, with more and brighter lights the rarer the prize.
	describe("rarity build-up", function()
		local LADDER = { "uncommon", "rare", "epic", "legendary" }

		it("runs about 4 seconds, longer the rarer the prize", function()
			expect(math.abs(Cutscene.openingDuration("uncommon") - 4) < 0.25).to.equal(true)
			for index = 2, #LADDER do
				expect(Cutscene.openingDuration(LADDER[index]) > Cutscene.openingDuration(LADDER[index - 1])).to.equal(
					true
				)
			end
			expect(Cutscene.openingDuration("odd") >= Cutscene.openingDuration("legendary")).to.equal(true)
		end)

		it("rattles harder, with more and brighter lights and a bigger burst, the rarer the prize", function()
			for index = 2, #LADDER do
				local lower = Cutscene.RARITY_FX[LADDER[index - 1]]
				local higher = Cutscene.RARITY_FX[LADDER[index]]
				expect(higher.hold > lower.hold).to.equal(true)
				expect(higher.lights > lower.lights).to.equal(true)
				expect(higher.brightness > lower.brightness).to.equal(true)
				expect(higher.rattleDeg > lower.rattleDeg).to.equal(true)
				expect(higher.rays > lower.rays).to.equal(true)
				expect(higher.flash >= lower.flash).to.equal(true)
				expect(#higher.chime >= #lower.chime).to.equal(true)
			end
		end)

		it("rattles the shut door with the light leaking out between the key turn and the burst", function()
			for _, rarity in LADDER do
				local duration = Cutscene.openingDuration(rarity)
				local fx = Cutscene.RARITY_FX[rarity]
				-- The middle of the hold: the last fx.hold seconds before the burst.
				local burstAt = duration - Cutscene.BURST_SECONDS
				local mid = Cutscene.cutscenePose("gloom", (burstAt - fx.hold / 2) / duration, rarity)
				expect(mid.beat).to.equal("rattle")
				expect(mid.glow).to.equal(false)
				expect(mid.doorDeg <= fx.rattleDeg).to.equal(true)
				expect(mid.leak > 0).to.equal(true)
				expect(mid.keyRollDeg).to.equal(90)
				local late = Cutscene.cutscenePose("gloom", (burstAt - 0.02) / duration, rarity)
				expect(late.leak > mid.leak).to.equal(true)
				expect(Cutscene.cutscenePose("gloom", (burstAt + 0.05) / duration, rarity).beat).to.equal("burst_open")
			end
		end)

		-- Owner 11-16: the leak is plain white through the hold, then shows the prize's own colour about half a second
		-- before the door opens (a glimpse of the rarity).
		it("leaks plain white, then the prize's colour in the last half second before the burst", function()
			for _, rarity in LADDER do
				local duration = Cutscene.openingDuration(rarity)
				local burstAt = duration - Cutscene.BURST_SECONDS
				local late = Cutscene.cutscenePose("gloom", (burstAt - 0.05) / duration, rarity)
				expect(late.leakTint > 0.9).to.equal(true)
				expect(Cutscene.cutscenePose("gloom", (burstAt + 0.1) / duration, rarity).leakTint).to.equal(1)
			end
			local hold = Cutscene.RARITY_FX.legendary.hold
			local duration = Cutscene.openingDuration("legendary")
			local burstAt = duration - Cutscene.BURST_SECONDS
			local early = Cutscene.cutscenePose("gloom", (burstAt - hold + 0.1) / duration, "legendary")
			expect(early.beat).to.equal("rattle")
			expect(early.leakTint).to.equal(0)
			expect(Cutscene.GLIMPSE_SECONDS).to.equal(0.5)
		end)

		-- Owner 11-16: the key floats in from screen right, never from the employee (who only idles).
		it("brings the key in from the side away from the employee", function()
			for _, id in { "gloom", "gleam" } do
				local start = Cutscene.cutscenePose(id, 0, "uncommon")
				local emp = start.employeeCFrame.Position
				for step = 0, 60 do
					local pose = Cutscene.cutscenePose(id, step / 60 * 0.7, "uncommon")
					local key = pose.keyCFrame.Position
					if key.Y > -50 then
						expect((key - emp).Magnitude > 2.5).to.equal(true)
						-- The employee stands at +X of the locker; the key comes from -X (screen right).
						expect(key.X < emp.X - 2).to.equal(true)
					end
				end
			end
		end)

		it("flashes brighter at the burst for a rarer prize", function()
			local function brightest(rarity)
				local least = 1
				for step = 0, 100 do
					least = math.min(least, Cutscene.cutscenePose("gloom", step / 100, rarity).flashTransparency)
				end
				return least
			end
			expect(brightest("legendary") < brightest("uncommon")).to.equal(true)
		end)
	end)
end
