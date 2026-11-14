local VM = require(script.Parent.ShopCarouselViewModel)

return function()
	local function offer(id)
		return { id = id, items = { id }, currency = "gleam", price = 10, pool = "featured" }
	end

	describe("slides", function()
		it("shows the offered deals, then today's banner, then the rest of the featured pool", function()
			local live = { featured = offer("today"), more = { offer("b"), offer("c") }, picks = {}, nextRotation = 0 }
			local slides = VM.slides({ "PickLegendary" }, live)
			expect(#slides).to.equal(4)
			expect(slides[1].kind).to.equal("deal")
			expect(slides[1].deal).to.equal("PickLegendary")
			expect(slides[2].kind).to.equal("today")
			expect(slides[2].offer.id).to.equal("today")
			expect(slides[3].kind).to.equal("more")
			expect(slides[4].offer.id).to.equal("c")
		end)

		it("is empty with nothing to show", function()
			expect(#VM.slides({}, { featured = nil, more = {}, picks = {}, nextRotation = 0 })).to.equal(0)
		end)
	end)

	describe("at", function()
		it("wraps both ways round the slides", function()
			expect(VM.at(1, 3)).to.equal(1)
			expect(VM.at(4, 3)).to.equal(1)
			expect(VM.at(0, 3)).to.equal(3)
			expect(VM.at(-1, 3)).to.equal(2)
		end)

		it("stays on 1 with no slides", function()
			expect(VM.at(5, 0)).to.equal(1)
		end)
	end)

	describe("due", function()
		it("moves on by itself every AUTO_SECONDS", function()
			expect(VM.due(VM.AUTO_SECONDS - 0.1, false)).to.equal(false)
			expect(VM.due(VM.AUTO_SECONDS, false)).to.equal(true)
		end)

		it("waits HOLD_SECONDS after the player picks a slide, so it never moves under their hand", function()
			expect(VM.due(VM.AUTO_SECONDS + 1, true)).to.equal(false)
			expect(VM.due(VM.HOLD_SECONDS, true)).to.equal(true)
			expect(VM.HOLD_SECONDS > VM.AUTO_SECONDS).to.equal(true)
		end)
	end)
end
