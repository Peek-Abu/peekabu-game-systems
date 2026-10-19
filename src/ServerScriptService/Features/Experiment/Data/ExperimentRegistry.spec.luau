local ExperimentRegistry = require(script.Parent.ExperimentRegistry)

return function()
	describe("ExperimentRegistry", function()
		it("lists the eleven launch experiments in board order", function()
			local ids = ExperimentRegistry.ids()
			expect(#ids).to.equal(11)
			expect(ids[1]).to.equal("exp-rehire")
			expect(ids[10]).to.equal("exp-timecard")
			expect(ids[11]).to.equal("exp-locker")
		end)

		it("gives every experiment a unique id, a unit and two distinct short variants", function()
			local seen = {}
			for _, def in ExperimentRegistry.list() do
				expect(seen[def.id]).to.equal(nil)
				seen[def.id] = true
				expect(string.match(def.id, "^exp%-%l[%l%d]*$")).to.be.ok()
				expect(def.unit == "player" or def.unit == "crew").to.equal(true)
				expect(#def.variants).to.equal(2)
				expect(def.variants[1]).never.to.equal(def.variants[2])
				for _, variant in def.variants do
					expect(#variant <= 9).to.equal(true)
					expect(string.match(variant, "^[%w%.%-]+$")).to.be.ok()
				end
			end
		end)

		it("assigns the crew-shared mechanics per crew and the rest per player", function()
			expect(ExperimentRegistry.get("exp-clean").unit).to.equal("crew")
			expect(ExperimentRegistry.get("exp-rehire").unit).to.equal("crew")
			expect(ExperimentRegistry.get("exp-friendskip").unit).to.equal("crew")
			expect(ExperimentRegistry.get("exp-stars").unit).to.equal("player")
			expect(ExperimentRegistry.get("exp-clean").variants[1]).to.equal("1.5s")
			expect(ExperimentRegistry.get("exp-rehire").variants[2]).to.equal("10s")
		end)

		it("is nil for an unknown id", function()
			expect(ExperimentRegistry.get("exp-nope")).to.equal(nil)
		end)
	end)
end
