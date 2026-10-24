local OfficeSeedUtils = require(script.Parent.OfficeSeedUtils)

return function()
	it("is deterministic and in [0, 1)", function()
		for seed = 1, 50 do
			local a = OfficeSeedUtils.hash01(seed, "k")
			expect(OfficeSeedUtils.hash01(seed, "k")).to.equal(a)
			expect(a >= 0 and a < 1).to.equal(true)
		end
	end)

	it("spreads 1000 keys around 0.5", function()
		local sum = 0
		for i = 1, 1000 do
			sum += OfficeSeedUtils.hash01(12345, "key" .. i)
		end
		expect(math.abs(sum / 1000 - 0.5) < 0.05).to.equal(true)
	end)

	it("differs by seed and key", function()
		expect(OfficeSeedUtils.hash01(1, "a")).never.to.equal(OfficeSeedUtils.hash01(2, "a"))
		expect(OfficeSeedUtils.hash01(1, "a")).never.to.equal(OfficeSeedUtils.hash01(1, "b"))
	end)
end
