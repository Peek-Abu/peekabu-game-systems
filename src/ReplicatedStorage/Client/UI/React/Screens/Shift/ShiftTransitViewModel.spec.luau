local ShiftTransitViewModel = require(script.Parent.ShiftTransitViewModel)

return function()
	describe("slip", function()
		it("writes the route slip in transit", function()
			local view = ShiftTransitViewModel.slip({ holds = {}, client = "Harlow & Finch Ltd.", truck = 2 }, false)
			expect(view.band).to.equal("MORROW & MORROW — DISPATCH")
			expect(view.truck).to.equal("TRUCK 2")
			expect(view.title).to.equal("ROUTE SLIP")
			expect(view.from).to.equal("Company depot")
			expect(view.to).to.equal("Harlow & Finch Ltd.")
			expect(view.stamp).to.equal("IN TRANSIT")
			expect(view.arrived).to.equal(false)
		end)

		it("stamps ARRIVED", function()
			local view = ShiftTransitViewModel.slip({ holds = {}, client = "Harlow & Finch Ltd." }, true)
			expect(view.stamp).to.equal("ARRIVED")
			expect(view.arrived).to.equal(true)
		end)

		it("leaves the truck off when unknown and writes a site on file without a client", function()
			local view = ShiftTransitViewModel.slip(nil, false)
			expect(view.truck).to.equal(nil)
			expect(view.to).to.equal(ShiftTransitViewModel.NO_CLIENT)
		end)

		it("cuts a long client name", function()
			local long = string.rep("A", 60)
			local view = ShiftTransitViewModel.slip({ holds = {}, client = long }, false)
			expect(utf8.len(view.to)).to.equal(ShiftTransitViewModel.CLIENT_MAX)
		end)
	end)
	describe("V1 load screen", function()
		it("heads the card EN ROUTE TO the client, without the company suffix", function()
			local view = ShiftTransitViewModel.slip({ holds = {}, client = "Harlow & Finch Ltd.", truck = 2 }, false)
			expect(view.heading).to.equal("EN ROUTE TO")
			expect(view.client).to.equal("HARLOW & FINCH")
			expect(view.site).to.equal("4th floor offices · 7:00 shift")
			expect(view.bar).to.equal("DRIVING TO THE SITE...")
		end)

		it("says ARRIVED AT and opens the doors once ready", function()
			local view = ShiftTransitViewModel.slip({ holds = {}, client = "Harlow & Finch Ltd." }, true)
			expect(view.heading).to.equal("ARRIVED AT")
			expect(view.bar).to.equal("DOORS OPEN!")
		end)

		it("gives a true tip about the Manager", function()
			local view = ShiftTransitViewModel.slip(nil, false)
			expect(string.find(view.tip, "Manager", 1, true) ~= nil).to.equal(true)
			expect(view.client).to.equal(string.upper(ShiftTransitViewModel.NO_CLIENT))
		end)

		it("fits the load screen to the window", function()
			expect(ShiftTransitViewModel.fit(Vector2.new(1920, 1080))).to.equal(1.25)
			expect(ShiftTransitViewModel.fit(Vector2.new(844, 390))).to.equal(0.5)
			expect(ShiftTransitViewModel.fit(Vector2.new(0, 0))).to.equal(0.3)
		end)

		it("grows with the one UI scale on a big monitor (its 1500x780 design is 1.25x at 1080p)", function()
			-- 2560x1440: the UI scale is 4/3, so the slip draws at 1.25 * 4/3; 4K: 1.25 * 2.
			expect(ShiftTransitViewModel.fit(Vector2.new(2560, 1440))).to.be.near(1.25 * 4 / 3, 1e-6)
			expect(ShiftTransitViewModel.fit(Vector2.new(3840, 2160))).to.equal(2.5)
		end)
	end)

	describe("advance", function()
		local advance = ShiftTransitViewModel.advance

		it("never goes backwards", function()
			expect(advance(0.6, 0.2, false, 1 / 60) >= 0.6).to.equal(true)
			expect(advance(0.6, 0, false, 1) >= 0.6).to.equal(true)
		end)

		it("closes on the readiness quickly", function()
			local shown = 0
			for _ = 1, 30 do
				shown = advance(shown, 0.5, false, 1 / 60)
			end
			expect(shown > 0.4).to.equal(true)
		end)

		it("keeps creeping slowly past a stalled stage, short of full", function()
			local shown = 0.5
			local after = advance(shown, 0.5, false, 1 / 60)
			expect(after > shown).to.equal(true)
			expect(after - shown < 0.01).to.equal(true)
			for _ = 1, 60 * 120 do
				shown = advance(shown, 0.5, false, 1 / 60)
			end
			expect(shown < ShiftTransitViewModel.BAR_CAP + 1e-6).to.equal(true)
			expect(shown <= 0.5 + ShiftTransitViewModel.BAR_CREEP + 1e-6).to.equal(true)
		end)

		it("is never full before arrival, even when ready", function()
			local shown = 0
			for _ = 1, 600 do
				shown = advance(shown, 1, false, 1 / 60)
			end
			expect(shown < 1).to.equal(true)
		end)

		it("eases to full once arrived, within the ARRIVED beat", function()
			local shown = 0.4
			for _ = 1, 20 do
				shown = advance(shown, 1, true, 1 / 60)
			end
			expect(shown).to.equal(1)
		end)

		it("ignores a broken step", function()
			expect(advance(0.3, 0.5, false, -1)).to.equal(0.3)
			expect(advance(0.3, 0 / 0, false, 1 / 60) >= 0.3).to.equal(true)
		end)
	end)
end
