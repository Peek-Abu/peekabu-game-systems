local VM = require(script.Parent.PaperPropViewModel)
return function()
	describe("company prop art", function()
		it("supplies distinct recognizable filled silhouettes", function()
			for _, kind in { "jobs", "guide", "gear", "settings", "vacuum" } do
				expect(#VM.shapes(kind) >= 5).to.equal(true)
				for _, shape in VM.shapes(kind) do
					expect(shape.w > 0 and shape.h > 0).to.equal(true)
					expect(shape.x >= 0 and shape.y >= 0 and shape.x + shape.w <= 64 and shape.y + shape.h <= 64).to.equal(
						true
					)
				end
			end
			expect(VM.shapes("jobs")[1].w == VM.shapes("guide")[1].w).to.equal(false)
		end)
	end)
end
