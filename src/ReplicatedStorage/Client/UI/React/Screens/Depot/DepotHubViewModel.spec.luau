local VM = require(script.Parent.DepotHubViewModel)
return function()
	describe("hub", function()
		it("fits the guide header and scroll body in portrait and short landscape", function()
			for _, viewport in { Vector2.new(390, 844), Vector2.new(844, 390), Vector2.new(1366, 768) } do
				local layout = VM.panelLayout(viewport, viewport.X < 900)
				expect(layout.width <= viewport.X - 32).to.equal(true)
				expect(layout.height <= viewport.Y - 32).to.equal(true)
				expect(layout.titleWidth >= 140).to.equal(true)
				expect(layout.bodyWidth > 250).to.equal(true)
				expect(layout.height - layout.headerHeight - 20 >= 120).to.equal(true)
			end
		end)
		it("stacks narrow settings while keeping wide headers compact", function()
			expect(VM.panelLayout(Vector2.new(390, 844), true).compact).to.equal(true)
			expect(VM.panelLayout(Vector2.new(844, 390), true).compact).to.equal(false)
		end)
		it("teaches that Gloom counts on the spot, with no dust bag to carry and no empty action", function()
			for _, page in { "guide", "gear" } do
				local copy = VM.copy(page)
				local text = ""
				for _, section in copy.sections do
					text ..= string.lower(section.title .. " " .. section.body) .. " "
				end
				expect(string.find(text, "gloom", 1, true) ~= nil).to.equal(true)
				expect(string.find(text, "bank dust bags", 1, true)).to.equal(nil)
				expect(string.find(text, "produce dust bags", 1, true)).to.equal(nil)
				expect(string.find(text, "empty your vacuum", 1, true)).to.equal(nil)
				expect(string.find(text, "stops collecting", 1, true)).to.equal(nil)
				expect(string.find(text, "empty at the truck", 1, true)).to.equal(nil)
			end
		end)
		it("includes a supplied live control legend without assuming a key", function()
			expect(
				string.find(VM.copy("guide", "Hold R2 to clean.").sections[2].body, "Hold R2 to clean.", 1, true) ~= nil
			).to.equal(true)
			expect(string.find(VM.copy("gear").sections[1].body, "press 1", 1, true)).to.equal(nil)
		end)
		it("does not put shortcuts over running or results crew", function()
			expect(VM.visible({ phase = "running", crew = { 1 } }, 1)).to.equal(false)
			expect(VM.visible({ phase = "results", crew = { 1 } }, 1)).to.equal(false)
			expect(VM.visible({ phase = "running", crew = { 2 } }, 1)).to.equal(true)
			expect(VM.visible(nil, 1)).to.equal(true)
		end)
		it("keeps touch targets usable on short landscape screens", function()
			local size = VM.cardSize(true)
			expect(size.X >= 48).to.equal(true)
			expect(size.Y >= 48).to.equal(true)
		end)
		it("bounds audio and shake adjustment and rounds percent", function()
			expect(VM.adjust(0, -1)).to.equal(0)
			expect(VM.adjust(1, 1)).to.equal(1)
			expect(VM.adjust(0.5, 1)).to.equal(0.6)
		end)
	end)
end
