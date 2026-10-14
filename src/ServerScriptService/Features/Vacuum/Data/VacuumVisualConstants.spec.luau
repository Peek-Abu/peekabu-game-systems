local C = require(script.Parent.VacuumVisualConstants)
return function()
	describe("backpack vacuum fallback geometry", function()
		it("has uniquely named, positive pieces for the pack and the wand", function()
			local names = {}
			for _, list in { C.backpack, C.wand } do
				for _, piece in list do
					expect(names[piece.name]).to.equal(nil)
					names[piece.name] = true
					expect(piece.size.X > 0 and piece.size.Y > 0 and piece.size.Z > 0).to.equal(true)
					expect(piece.frame.Position.Magnitude < 2).to.equal(true)
				end
			end
			for _, name in { "CanisterBody", "GaugeFill", "GaugeWindow", "FullLamp", "HoseOutlet", "WandHolster" } do
				expect(names[name]).to.equal(true)
			end
			for _, name in { "WandGrip", "WandInlet", "WandTube", "WandSwivel", "FloorHead" } do
				expect(names[name]).to.equal(true)
			end
		end)

		it("keeps the pack behind its mount (+Z is back) and the outlet and holster on the right (+X)", function()
			for _, piece in C.backpack do
				expect(piece.frame.Position.Z >= 0).to.equal(true)
			end
			expect(C.outlet.Position.X > 0).to.equal(true)
			expect(C.holster.Position.X > 0).to.equal(true)
		end)

		it("leans the wand forward and keeps the floor head clear of the floor", function()
			expect(C.hold.angle > 0 and C.hold.angle < math.rad(60)).to.equal(true)
			expect(C.hold.clearance > 0).to.equal(true)
			expect(C.hold.down > 0 and C.hold.forward > 0).to.equal(true)
		end)
	end)
end
