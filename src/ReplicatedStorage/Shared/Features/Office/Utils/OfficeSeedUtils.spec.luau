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

	-- Golden values: if the hash ever changes, every run's layout reshuffles. Change these only on purpose.
	it("keeps its golden values", function()
		expect(OfficeSeedUtils.hash01(1, "a")).to.equal(0.67130170203745365)
		expect(OfficeSeedUtils.hash01(123456789, "prop:pods1.prop.3")).to.equal(0.39473763736896217)
		expect(OfficeSeedUtils.hash01(2, "welcome")).to.equal(0.43619991675950587)
	end)

	it("picks a stable element of a list", function()
		local list = { "a", "b", "c", "d", "e" }
		-- 0.436 * 5 floors to 2, so the third entry.
		expect(OfficeSeedUtils.pick(2, "welcome", list)).to.equal("c")
		for seed = 1, 200 do
			expect(table.find(list, OfficeSeedUtils.pick(seed, "x", list)) ~= nil).to.equal(true)
		end
	end)
end
