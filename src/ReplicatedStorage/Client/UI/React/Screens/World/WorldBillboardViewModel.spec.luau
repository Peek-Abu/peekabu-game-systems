local WorldBillboardViewModel = require(script.Parent.WorldBillboardViewModel)

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

return function()
	describe("fit", function()
		it("scales the design to the shell's drawn size, by the tighter side", function()
			expect(WorldBillboardViewModel.fit(Vector2.new(170, 155), Vector2.new(340, 310))).to.equal(0.5)
			expect(near(WorldBillboardViewModel.fit(Vector2.new(680, 300), Vector2.new(340, 310)), 300 / 310)).to.equal(
				true
			)
		end)

		it("draws nothing for a shell with no size yet, and 1 for an empty design", function()
			expect(WorldBillboardViewModel.fit(Vector2.zero, Vector2.new(340, 310))).to.equal(0)
			expect(WorldBillboardViewModel.fit(Vector2.new(100, 100), Vector2.zero)).to.equal(1)
		end)
	end)

	describe("screenScale", function()
		it("is 1 on the 1920x1080 reference and never grows past it", function()
			expect(WorldBillboardViewModel.screenScale(Vector2.new(1920, 1080))).to.equal(1)
			expect(WorldBillboardViewModel.screenScale(Vector2.new(3840, 2160))).to.equal(1)
		end)

		it("shrinks with the smaller screen side", function()
			expect(near(WorldBillboardViewModel.screenScale(Vector2.new(1280, 720)), 2 / 3)).to.equal(true)
			expect(near(WorldBillboardViewModel.screenScale(Vector2.new(1366, 768)), 768 / 1080)).to.equal(true)
		end)

		it("keeps a phone's signs readable at 0.6", function()
			expect(WorldBillboardViewModel.screenScale(Vector2.new(844, 390))).to.equal(0.6)
			expect(WorldBillboardViewModel.screenScale(Vector2.new(0, 0))).to.equal(0.6)
		end)
	end)

	describe("clip", function()
		it("keeps text that fits", function()
			expect(WorldBillboardViewModel.clip("Employee of the Month plaque", 32)).to.equal(
				"Employee of the Month plaque"
			)
			expect(WorldBillboardViewModel.clip("", 4)).to.equal("")
		end)

		it("cuts longer text to the limit, ending in an ellipsis", function()
			local cut = WorldBillboardViewModel.clip(string.rep("a", 40), 32)
			expect(cut).to.equal(string.rep("a", 31) .. "…")
			expect(utf8.len(cut)).to.equal(32)
		end)

		it("cuts on a character boundary", function()
			expect(WorldBillboardViewModel.clip("Café Ünïcode", 5)).to.equal("Café…")
		end)

		it("reads broken UTF-8 as a question mark", function()
			expect(WorldBillboardViewModel.clip("\255\254", 10)).to.equal("?")
		end)
	end)
end
