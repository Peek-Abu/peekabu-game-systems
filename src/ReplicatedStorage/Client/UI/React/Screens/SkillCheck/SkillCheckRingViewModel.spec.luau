local SkillCheckRingViewModel = require(script.Parent.SkillCheckRingViewModel)

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

return function()
	describe("fraction", function()
		it("runs 0 at the ring's start to 1 at its arrival", function()
			expect(SkillCheckRingViewModel.fraction(8.8, 10, 1.2)).to.equal(0)
			expect(near(SkillCheckRingViewModel.fraction(9.4, 10, 1.2), 0.5)).to.equal(true)
			expect(SkillCheckRingViewModel.fraction(10, 10, 1.2)).to.equal(1)
		end)

		it("clamps before the start and after the arrival", function()
			expect(SkillCheckRingViewModel.fraction(5, 10, 1.2)).to.equal(0)
			expect(SkillCheckRingViewModel.fraction(12, 10, 1.2)).to.equal(1)
		end)

		it("is arrived for a travel of zero", function()
			expect(SkillCheckRingViewModel.fraction(9, 10, 0)).to.equal(1)
		end)
	end)

	describe("outerRadius", function()
		it("closes from the start radius onto the inner circle", function()
			for _, layout in { "desktop", "phone" } do
				local metrics = SkillCheckRingViewModel.METRICS[layout]
				expect(SkillCheckRingViewModel.outerRadius(layout, 0)).to.equal(metrics.outerStart)
				expect(SkillCheckRingViewModel.outerRadius(layout, 1)).to.equal(metrics.inner)
				local mid = SkillCheckRingViewModel.outerRadius(layout, 0.5)
				expect(mid < metrics.outerStart and mid > metrics.inner).to.equal(true)
			end
		end)

		it("is smaller on a phone", function()
			local desktop = SkillCheckRingViewModel.METRICS.desktop
			local phone = SkillCheckRingViewModel.METRICS.phone
			expect(phone.outerStart < desktop.outerStart).to.equal(true)
			expect(phone.inner < desktop.inner).to.equal(true)
		end)
	end)

	describe("beads", function()
		it("lays the beads evenly round the circle from straight up", function()
			local beads = SkillCheckRingViewModel.beads(8, 180, 10)
			expect(#beads).to.equal(8)
			expect(beads[1].angle).to.equal(0)
			expect(beads[3].angle).to.equal(90)
		end)

		it("marks the beads inside the opening", function()
			local beads = SkillCheckRingViewModel.beads(8, 90, 100)
			-- 40..140 holds the 45, 90 and 135 beads.
			local open = {}
			for _, bead in beads do
				if bead.open then
					table.insert(open, bead.angle)
				end
			end
			expect(#open).to.equal(3)
			expect(open[1]).to.equal(45)
			expect(open[3]).to.equal(135)
		end)

		it("marks beads across 0/360", function()
			local beads = SkillCheckRingViewModel.beads(8, 0, 100)
			expect(beads[1].open).to.equal(true)
			expect(beads[2].open).to.equal(true)
			expect(beads[8].open).to.equal(true)
			expect(beads[5].open).to.equal(false)
		end)

		it("always leaves at least one bead open, however narrow the opening", function()
			local beads = SkillCheckRingViewModel.beads(8, 20, 2)
			local count = 0
			for _, bead in beads do
				if bead.open then
					count += 1
				end
			end
			expect(count >= 1).to.equal(true)
		end)
	end)

	describe("place", function()
		it("puts angle 0 straight above the centre and 90 to its right", function()
			local up = SkillCheckRingViewModel.place(0, 10)
			expect(near(up.X, 0)).to.equal(true)
			expect(near(up.Y, -10)).to.equal(true)
			local right = SkillCheckRingViewModel.place(90, 10)
			expect(near(right.X, 10)).to.equal(true)
			expect(near(right.Y, 0)).to.equal(true)
		end)
	end)

	describe("centre", function()
		local screens = {
			{ "desktop", Vector2.new(1920, 1080) },
			{ "desktop", Vector2.new(1871, 1052) },
			{ "desktop", Vector2.new(2135, 869) },
			{ "phone", Vector2.new(844, 390) },
			{ "phone", Vector2.new(667, 375) },
		}

		it("sits on the screen's middle line, inside the screen, its outer ring under the top HUD", function()
			for _, case in screens do
				local layout, viewport = case[1], case[2]
				local centre = SkillCheckRingViewModel.centre(layout, viewport)
				local outer = SkillCheckRingViewModel.METRICS[layout].outerStart
				expect(centre.X).to.equal(viewport.X / 2)
				expect(centre.Y + outer <= viewport.Y).to.equal(true)
				expect(centre.Y - outer >= SkillCheckRingViewModel.TOP_RESERVE[layout]).to.equal(true)
			end
		end)

		it("sits above the middle on desktop, over the character's head rather than its body (owner 11-18)", function()
			for _, case in screens do
				local layout, viewport = case[1], case[2]
				if layout == "desktop" then
					expect(SkillCheckRingViewModel.centre(layout, viewport).Y < viewport.Y / 2).to.equal(true)
				end
			end
		end)
	end)

	describe("toDesign", function()
		it("turns a viewport point into HUD design px from the HUD frame's origin and scale", function()
			local at = SkillCheckRingViewModel.toDesign(Vector2.new(730, 420), Vector2.new(0, 20), 0.5)
			expect(at.X).to.equal(1460)
			expect(at.Y).to.equal(800)
		end)

		it("is the point itself at scale 1 from the corner", function()
			local at = SkillCheckRingViewModel.toDesign(Vector2.new(12, 34), Vector2.zero, 1)
			expect(at.X).to.equal(12)
			expect(at.Y).to.equal(34)
		end)
	end)

	describe("screenBox", function()
		it("spans the points it is given", function()
			local box = SkillCheckRingViewModel.screenBox({
				Vector2.new(10, 50),
				Vector2.new(30, 20),
				Vector2.new(25, 80),
			})
			expect(box.left).to.equal(10)
			expect(box.right).to.equal(30)
			expect(box.top).to.equal(20)
			expect(box.bottom).to.equal(80)
		end)

		it("has no box without points", function()
			expect(SkillCheckRingViewModel.screenBox({})).to.equal(nil)
		end)
	end)

	describe("placement", function()
		-- The same screens as centre: 1080p, the 73% laptop scale, Studio's short pane, two phones.
		local screens = {
			{ "desktop", Vector2.new(1920, 1080) },
			{ "desktop", Vector2.new(1871, 1052) },
			{ "desktop", Vector2.new(2135, 869) },
			{ "phone", Vector2.new(844, 390) },
			{ "phone", Vector2.new(667, 375) },
		}

		-- A character standing mid-screen, its top (ears, hat) `top` px down, `tall` px tall and `wide` px wide.
		local function body(viewport, top, tall, wide)
			local mid = viewport.X / 2
			return { left = mid - wide / 2, right = mid + wide / 2, top = top, bottom = top + tall }
		end

		local function clear(layout)
			local metrics = SkillCheckRingViewModel.METRICS[layout]
			return metrics.inner + metrics.bead + SkillCheckRingViewModel.HEAD_MARGIN[layout]
		end

		-- Whether the inner circle's square (with its beads) reaches into the character's box.
		local function overlaps(layout, centre, box)
			local metrics = SkillCheckRingViewModel.METRICS[layout]
			local r = metrics.inner + metrics.bead
			return centre.X + r > box.left
				and centre.X - r < box.right
				and centre.Y + r > box.top
				and centre.Y - r < box.bottom
		end

		local function keepsClamps(layout, viewport, centre)
			local outer = SkillCheckRingViewModel.METRICS[layout].outerStart
			expect(centre.Y - outer >= SkillCheckRingViewModel.TOP_RESERVE[layout] - 1e-6).to.equal(true)
			expect(centre.Y + outer <= viewport.Y + 1e-6).to.equal(true)
			expect(centre.X - outer >= -1e-6).to.equal(true)
			expect(centre.X + outer <= viewport.X + 1e-6).to.equal(true)
		end

		it("falls back to the middle placement with no character on screen", function()
			for _, case in screens do
				local layout, viewport = case[1], case[2]
				local placed = SkillCheckRingViewModel.placement(layout, viewport, nil)
				expect(placed.spot).to.equal("middle")
				expect(placed.centre).to.equal(SkillCheckRingViewModel.centre(layout, viewport))
			end
		end)

		it("puts the inner circle just above the character's top when there is room", function()
			local viewport = Vector2.new(1920, 1080)
			local box = body(viewport, 520, 380, 160)
			local placed = SkillCheckRingViewModel.placement("desktop", viewport, box)
			expect(placed.spot).to.equal("above")
			expect(near(placed.centre.Y, 520 - clear("desktop"))).to.equal(true)
			expect(placed.centre.X).to.equal(960)
			expect(overlaps("desktop", placed.centre, box)).to.equal(false)
			keepsClamps("desktop", viewport, placed.centre)
		end)

		it("follows a taller character up (ears, hats): never a fixed offset", function()
			local viewport = Vector2.new(1920, 1080)
			local short = SkillCheckRingViewModel.placement("desktop", viewport, body(viewport, 600, 300, 160))
			local tall = SkillCheckRingViewModel.placement("desktop", viewport, body(viewport, 560, 340, 160))
			expect(short.spot).to.equal("above")
			expect(tall.spot).to.equal("above")
			expect(near(short.centre.Y - tall.centre.Y, 40)).to.equal(true)
		end)

		it("follows a character off the middle sideways, kept on screen", function()
			local viewport = Vector2.new(1920, 1080)
			local box = { left = 1700, right = 1880, top = 560, bottom = 900 }
			local placed = SkillCheckRingViewModel.placement("desktop", viewport, box)
			expect(placed.spot).to.equal("above")
			keepsClamps("desktop", viewport, placed.centre)
		end)

		it("goes beside the character, not over its face, when the top has no room (camera close)", function()
			local viewport = Vector2.new(1920, 1080)
			local box = body(viewport, 250, 700, 300)
			local placed = SkillCheckRingViewModel.placement("desktop", viewport, box)
			expect(placed.spot).to.equal("right")
			expect(placed.centre.X - (box.right + clear("desktop")) >= -1e-6).to.equal(true)
			expect(overlaps("desktop", placed.centre, box)).to.equal(false)
			keepsClamps("desktop", viewport, placed.centre)
		end)

		it("goes left when the right has no room on desktop", function()
			local viewport = Vector2.new(1920, 1080)
			local box = { left = 1200, right = 1700, top = 250, bottom = 950 }
			local placed = SkillCheckRingViewModel.placement("desktop", viewport, box)
			expect(placed.spot).to.equal("left")
			expect(overlaps("desktop", placed.centre, box)).to.equal(false)
			keepsClamps("desktop", viewport, placed.centre)
		end)

		it("on a phone, tries the left side first (the action arc is on the right)", function()
			local viewport = Vector2.new(844, 390)
			local box = body(viewport, 150, 200, 120)
			local placed = SkillCheckRingViewModel.placement("phone", viewport, box)
			expect(placed.spot).to.equal("left")
			expect(overlaps("phone", placed.centre, box)).to.equal(false)
			keepsClamps("phone", viewport, placed.centre)
		end)

		it("uses the same above rule on a phone when it fits", function()
			local viewport = Vector2.new(844, 390)
			local box = body(viewport, 340, 50, 60)
			local placed = SkillCheckRingViewModel.placement("phone", viewport, box)
			expect(placed.spot).to.equal("above")
			expect(overlaps("phone", placed.centre, box)).to.equal(false)
			keepsClamps("phone", viewport, placed.centre)
		end)

		it("keeps every clamp for any character box on every screen", function()
			for _, case in screens do
				local layout, viewport = case[1], case[2]
				for _, top in { -200, 0, 100, 300, 500, 900 } do
					for _, wide in { 40, 300, viewport.X } do
						local box = body(viewport, top, 400, wide)
						keepsClamps(layout, viewport, SkillCheckRingViewModel.placement(layout, viewport, box).centre)
					end
				end
			end
		end)

		it("when nothing clears the character, takes the side with more room", function()
			local viewport = Vector2.new(1920, 1080)
			local box = { left = 200, right = 1800, top = 100, bottom = 1000 }
			local placed = SkillCheckRingViewModel.placement("desktop", viewport, box)
			expect(placed.spot == "right" or placed.spot == "left").to.equal(true)
			keepsClamps("desktop", viewport, placed.centre)
		end)
	end)

	describe("hintSide", function()
		local function fits(layout, viewport, centre, side)
			local frame = SkillCheckRingViewModel.hintFrame(layout, side)
			local at = centre + frame.offset
			local left = at.X - frame.anchor.X * frame.size.X
			local reserve = SkillCheckRingViewModel.HINT_SIDE_RESERVE[layout]
			return left >= reserve and left + frame.size.X <= viewport.X - reserve
		end

		it("keeps the layout's side for a ring in the middle", function()
			for _, layout in { "desktop", "phone" } do
				local viewport = if layout == "desktop" then Vector2.new(1920, 1080) else Vector2.new(844, 390)
				local centre = SkillCheckRingViewModel.centre(layout, viewport)
				expect(SkillCheckRingViewModel.hintSide(layout, centre, viewport, nil)).to.equal(
					SkillCheckRingViewModel.HINT_SIDE[layout]
				)
			end
		end)

		it("goes away from the character when the ring sits beside it", function()
			local viewport = Vector2.new(1920, 1080)
			expect(SkillCheckRingViewModel.hintSide("desktop", Vector2.new(1300, 500), viewport, 1)).to.equal(1)
			expect(SkillCheckRingViewModel.hintSide("desktop", Vector2.new(600, 500), viewport, -1)).to.equal(-1)
		end)

		it("flips to the other side when its side would leave the screen", function()
			local viewport = Vector2.new(1920, 1080)
			local centre = Vector2.new(1700, 500)
			local side = SkillCheckRingViewModel.hintSide("desktop", centre, viewport, 1)
			expect(side).to.equal(-1)
			expect(fits("desktop", viewport, centre, side)).to.equal(true)
		end)

		it("mirrors the default frame on the other side", function()
			local right = SkillCheckRingViewModel.hintFrame("desktop", 1)
			local left = SkillCheckRingViewModel.hintFrame("desktop", -1)
			expect(right.offset.X).to.equal(-left.offset.X)
			expect(right.anchor.X).to.equal(0)
			expect(left.anchor.X).to.equal(1)
		end)
	end)

	describe("hintFrame", function()
		-- HUD design viewports: 1080p desktop; a laptop at the 73% HUD scale (1366x768 / 0.73); Studio's short play
		-- pane (1601x652 / 0.75); a phone; a narrow phone.
		local cases = {
			{ "desktop", Vector2.new(1920, 1080) },
			{ "desktop", Vector2.new(1871, 1052) },
			{ "desktop", Vector2.new(2135, 869) },
			{ "phone", Vector2.new(844, 390) },
			{ "phone", Vector2.new(667, 375) },
		}

		local function box(layout, viewport)
			local centre = SkillCheckRingViewModel.centre(layout, viewport)
			local frame = SkillCheckRingViewModel.hintFrame(layout)
			local at = centre + frame.offset
			local left = at.X - frame.anchor.X * frame.size.X
			local top = at.Y - frame.anchor.Y * frame.size.Y
			return { left = left, top = top, right = left + frame.size.X, bottom = top + frame.size.Y }, centre
		end

		it("stays clear of the bottom stack (hotbar, stamina, prompt) on every screen", function()
			for _, case in cases do
				local layout, viewport = case[1], case[2]
				local b = box(layout, viewport)
				local reserve = SkillCheckRingViewModel.HINT_BOTTOM_RESERVE[layout]
				expect(b.bottom <= viewport.Y - reserve).to.equal(true)
			end
		end)

		it("sits beside the ring at its centre height, never on the ring", function()
			for _, case in cases do
				local layout, viewport = case[1], case[2]
				local b, centre = box(layout, viewport)
				local metrics = SkillCheckRingViewModel.METRICS[layout]
				local reach = metrics.outerStart + metrics.bead
				expect(near((b.top + b.bottom) / 2, centre.Y)).to.equal(true)
				local rightOfRing = b.left >= centre.X + reach
				local leftOfRing = b.right <= centre.X - reach
				expect(rightOfRing or leftOfRing).to.equal(true)
			end
		end)

		it("stays on the screen, clear of the side reserve", function()
			for _, case in cases do
				local layout, viewport = case[1], case[2]
				local b = box(layout, viewport)
				local side = SkillCheckRingViewModel.HINT_SIDE_RESERVE[layout]
				expect(b.left >= side).to.equal(true)
				expect(b.right <= viewport.X - side).to.equal(true)
				expect(b.top >= 0).to.equal(true)
			end
		end)

		it("goes right of the ring on desktop, left on a phone (the action arc is right of it)", function()
			expect(SkillCheckRingViewModel.hintFrame("desktop").anchor.X).to.equal(0)
			expect(SkillCheckRingViewModel.hintFrame("phone").anchor.X).to.equal(1)
		end)

		it("keeps a phone's hint off the action arc's helper button", function()
			-- ShiftHudViewModel's phone HELPER spot: 76 px at (-291, -198) from the bottom-right corner (844x390).
			local b = box("phone", Vector2.new(844, 390))
			local helperLeft = 844 - 291 - 38
			expect(b.right <= helperLeft).to.equal(true)
		end)
	end)

	describe("flash", function()
		it("starts full and fades out", function()
			expect(SkillCheckRingViewModel.flash(0)).to.equal(1)
			local mid = SkillCheckRingViewModel.flash(SkillCheckRingViewModel.FLASH_SECONDS / 2)
			expect(mid > 0 and mid < 1).to.equal(true)
			expect(SkillCheckRingViewModel.flash(SkillCheckRingViewModel.FLASH_SECONDS)).to.equal(0)
			expect(SkillCheckRingViewModel.flash(99)).to.equal(0)
		end)

		it("is nothing before it starts", function()
			expect(SkillCheckRingViewModel.flash(-1)).to.equal(0)
		end)
	end)

	describe("shown", function()
		it("shows the ring until a moment after it arrives", function()
			expect(SkillCheckRingViewModel.shown(9, 10)).to.equal(true)
			expect(SkillCheckRingViewModel.shown(10 + SkillCheckRingViewModel.LINGER, 10)).to.equal(true)
			expect(SkillCheckRingViewModel.shown(10 + SkillCheckRingViewModel.LINGER + 0.01, 10)).to.equal(false)
		end)
	end)

	describe("hint", function()
		it("shows the words for the first rings only", function()
			expect(SkillCheckRingViewModel.hint(0, 2)).to.equal(false)
			expect(SkillCheckRingViewModel.hint(1, 2)).to.equal(true)
			expect(SkillCheckRingViewModel.hint(2, 2)).to.equal(true)
			expect(SkillCheckRingViewModel.hint(3, 2)).to.equal(false)
		end)
	end)
end
