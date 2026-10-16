local ShiftTransitUtils = require(script.Parent.ShiftTransitUtils)

return function()
	describe("build and decode", function()
		it("round-trips holds, the client and the truck", function()
			local built = ShiftTransitUtils.build({
				{ userId = 7, id = 3, built = true, seed = 42, spot = Vector3.new(1, 2, 3) },
				{ userId = 9, id = 3, built = false },
			}, "Harlow & Finch Ltd.", 2)
			local snapshot = ShiftTransitUtils.decode(built)
			expect(snapshot).to.be.ok()
			expect(#snapshot.holds).to.equal(2)
			local first = snapshot.holds[1]
			expect(first.userId).to.equal(7)
			expect(first.id).to.equal(3)
			expect(first.built).to.equal(true)
			expect(first.seed).to.equal(42)
			expect(first.spot).to.equal(Vector3.new(1, 2, 3))
			local second = snapshot.holds[2]
			expect(second.built).to.equal(false)
			expect(second.seed).to.equal(nil)
			expect(second.spot).to.equal(nil)
			expect(snapshot.client).to.equal("Harlow & Finch Ltd.")
			expect(snapshot.truck).to.equal(2)
		end)

		it("ships only plain data (no Vector3)", function()
			local built = ShiftTransitUtils.build({
				{ userId = 7, id = 1, built = true, spot = Vector3.new(4, 5, 6) },
			}, nil, nil)
			for _, hold in built.holds do
				for _, value in hold do
					expect(typeof(value) == "Vector3").to.equal(false)
				end
			end
		end)

		it("reads no holds as an empty list", function()
			local snapshot = ShiftTransitUtils.decode({})
			expect(snapshot).to.be.ok()
			expect(#snapshot.holds).to.equal(0)
		end)

		it("rejects a malformed value", function()
			expect(ShiftTransitUtils.decode(nil)).to.equal(nil)
			expect(ShiftTransitUtils.decode("x")).to.equal(nil)
			expect(ShiftTransitUtils.decode({ holds = "x" })).to.equal(nil)
			expect(ShiftTransitUtils.decode({ holds = { { userId = "a", id = 1, built = true } } })).to.equal(nil)
			expect(ShiftTransitUtils.decode({ holds = { { userId = 1, id = 1, built = "yes" } } })).to.equal(nil)
			expect(ShiftTransitUtils.decode({ holds = { { userId = 1, id = 1, built = true, x = 1 } } })).to.equal(nil)
			expect(ShiftTransitUtils.decode({ holds = {}, client = 5 })).to.equal(nil)
		end)
	end)

	describe("holdOf", function()
		it("finds the player's hold, or nil", function()
			local snapshot = ShiftTransitUtils.decode(ShiftTransitUtils.build({
				{ userId = 7, id = 2, built = false },
			}, nil, nil))
			expect(ShiftTransitUtils.holdOf(snapshot, 7).id).to.equal(2)
			expect(ShiftTransitUtils.holdOf(snapshot, 8)).to.equal(nil)
			expect(ShiftTransitUtils.holdOf(nil, 7)).to.equal(nil)
		end)
	end)
end
