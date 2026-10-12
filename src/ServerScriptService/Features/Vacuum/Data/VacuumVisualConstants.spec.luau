local C = require(script.Parent.VacuumVisualConstants)
return function()
	describe("original vacuum geometry", function()
		it("has positive finite source shapes and a reachable grip origin", function()
			expect(#C.parts).to.equal(38)
			local names = {}
			for _, part in C.parts do
				expect(names[part.name]).to.equal(nil)
				names[part.name] = true
				expect(part.size.X > 0 and part.size.Y > 0 and part.size.Z > 0).to.equal(true)
				expect(part.frame.Position.Magnitude < 5).to.equal(true)
			end
			expect(names["Carry grip"]).to.equal(true)
			expect(names["Wide floor head"]).to.equal(true)
		end)
	end)
end
