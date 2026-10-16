local CargoInventoryUtils = require(script.Parent.CargoInventoryUtils)

local function has(list, value)
	return table.find(list, value) ~= nil
end

return function()
	describe("knownValue", function()
		it("knows trash's value, and a valuable's only once appraised", function()
			expect(CargoInventoryUtils.knownValue({ kind = "rubbishBag", value = 10 })).to.equal(10)
			local grimy = { kind = "keyring", value = 12, appraisal = { base = 40, clean = 0, appraised = false } }
			expect(CargoInventoryUtils.knownValue(grimy)).to.equal(nil)
			grimy.appraisal.appraised = true
			expect(CargoInventoryUtils.knownValue(grimy)).to.equal(12)
		end)
	end)

	describe("published", function()
		it("publishes each filled slot's kind, known value and appraised jackpot name", function()
			local fields = CargoInventoryUtils.published({
				[1] = { kind = "rubbishBag", value = 10 },
				[3] = {
					kind = "wristwatch",
					value = 260,
					appraisal = { base = 260, clean = 1, appraised = true, variant = "Gold" },
				},
			}, 3, 0)
			expect(fields.set.inv1).to.equal("rubbishBag")
			expect(fields.set.inv1Value).to.equal(10)
			expect(fields.set.inv3).to.equal("wristwatch")
			expect(fields.set.inv3Value).to.equal(260)
			expect(fields.set.inv3Variant).to.equal("Gold")
			expect(fields.set.invHands).to.equal(3)
			expect(has(fields.cleared, "inv2")).to.equal(true)
			expect(has(fields.cleared, "inv4Value")).to.equal(true)
			expect(has(fields.cleared, "inv1Variant")).to.equal(true)
			expect(has(fields.cleared, "invSelected")).to.equal(true)
		end)

		it("hides an unappraised valuable's value and jackpot, and clears the hands with empty hands", function()
			local fields = CargoInventoryUtils.published({
				[2] = {
					kind = "coffeeMug",
					value = 30,
					appraisal = { base = 100, clean = 0, appraised = false, variant = "World's Best Boss" },
				},
			}, nil, 4)
			expect(fields.set.inv2).to.equal("coffeeMug")
			expect(fields.set.inv2Value).to.equal(nil)
			expect(has(fields.cleared, "inv2Value")).to.equal(true)
			expect(has(fields.cleared, "inv2Variant")).to.equal(true)
			expect(has(fields.cleared, "invHands")).to.equal(true)
			expect(fields.set.invSelected).to.equal(4)
		end)
	end)
end
