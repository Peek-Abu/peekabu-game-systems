local VM = require(script.Parent.ToonMenuBarViewModel)

-- A stand-in for the font: every letter is 0.7 of the text size wide.
local function measure(text, size)
	return #text * size * 0.7
end

local function tabs(names, icons)
	local list = {}
	for _, name in names do
		table.insert(list, { text = name, icon = icons })
	end
	return list
end

local function total(layout, gap)
	local sum = 0
	for _, width in layout.widths do
		sum += width + gap
	end
	return sum
end

return function()
	local NAMES = { "Featured", "Hire", "Skins", "Gleam", "Lockers", "Passes" }

	it("keeps the full size and the icons when the tabs fit", function()
		local layout = VM.tabs(tabs({ "Skins", "Gleam" }, true), 2000, 24, 12, 12, measure)
		expect(layout.textSize).to.equal(24)
		expect(layout.icons).to.equal(true)
		expect(layout.scroll).to.equal(false)
	end)

	it("never lays the tabs wider than the room unless they scroll", function()
		for _, room in { 2000, 900, 600, 420, 300, 120 } do
			local layout = VM.tabs(tabs(NAMES, true), room, 22, 12, 8, measure)
			if not layout.scroll then
				expect(total(layout, 8) <= room).to.equal(true)
			end
		end
	end)

	it("shrinks the text, then drops the icons, and never goes under the readable floor", function()
		local shrunk = VM.tabs(tabs(NAMES, true), 700, 22, 12, 8, measure)
		expect(shrunk.textSize < 22).to.equal(true)
		expect(shrunk.textSize >= 12).to.equal(true)
		local bare = VM.tabs(tabs(NAMES, true), 420, 22, 12, 8, measure)
		expect(bare.icons).to.equal(false)
		expect(bare.textSize >= 12).to.equal(true)
	end)

	it(
		"scrolls at the floor size when even bare tabs do not fit (every word whole, nothing under the wallets)",
		function()
			local layout = VM.tabs(tabs(NAMES, true), 120, 22, 12, 8, measure)
			expect(layout.scroll).to.equal(true)
			expect(layout.textSize).to.equal(12)
			expect(layout.icons).to.equal(false)
			for index, name in NAMES do
				expect(layout.widths[index] >= measure(name, 12)).to.equal(true)
			end
		end
	)
end
