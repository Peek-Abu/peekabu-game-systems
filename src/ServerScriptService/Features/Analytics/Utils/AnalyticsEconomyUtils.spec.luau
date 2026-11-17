local AnalyticsEconomyUtils = require(script.Parent.AnalyticsEconomyUtils)

local function change(overrides)
	local base = {
		userId = 1,
		currency = "credits",
		flow = "source",
		amount = 120,
		balance = 340,
		reason = "shiftPay",
	}
	for key, value in overrides do
		base[key] = value
	end
	return base
end

return function()
	it("a gain is a source at the display name", function()
		local call = AnalyticsEconomyUtils.call(change({}))
		expect(call ~= nil).to.equal(true)
		expect(call.flow).to.equal("source")
		expect(call.currency).to.equal("Credits")
		expect(call.amount).to.equal(120)
		expect(call.endingBalance).to.equal(340)
		expect(call.transactionType).to.equal("Gameplay")
		expect(call.sku).to.equal("shiftPay")
	end)

	it("a spend is a sink with a positive amount", function()
		local call = AnalyticsEconomyUtils.call(change({ flow = "sink", amount = 50, balance = 290 }))
		expect(call ~= nil).to.equal(true)
		expect(call.flow).to.equal("sink")
		expect(call.amount).to.equal(50)
		expect(call.endingBalance).to.equal(290)
	end)

	it("names Gloom and Gleam too", function()
		expect(AnalyticsEconomyUtils.call(change({ currency = "gloom" })).currency).to.equal("Gloom")
		expect(AnalyticsEconomyUtils.call(change({ currency = "gleam" })).currency).to.equal("Gleam")
	end)

	it("nothing for a zero change, an unlogged reason, an unknown currency or an unknown reason", function()
		expect(AnalyticsEconomyUtils.call(change({ amount = 0 }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ reason = "migration" }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ reason = "admin" }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ reason = "other" }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ currency = "coins" }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ reason = "who-knows" }))).to.equal(nil)
	end)

	it("non-finite amounts are dropped", function()
		expect(AnalyticsEconomyUtils.call(change({ amount = 0 / 0 }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ amount = math.huge }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ balance = 0 / 0 }))).to.equal(nil)
	end)

	describe("record", function()
		local function record(overrides)
			local base = {
				currency = "gleam",
				flow = "sink",
				amount = 120,
				kind = "Shop",
				sku = "skin:rare",
				item = "Pippa.Bubble",
				rarity = "rare",
				where = "shop",
			}
			for key, value in overrides do
				base[key] = value
			end
			return base
		end

		it("a spend becomes the call with the item, rarity and where in the fields", function()
			local call, fields = AnalyticsEconomyUtils.record(record({}), 380, "new")
			expect(call ~= nil).to.equal(true)
			expect(call.flow).to.equal("sink")
			expect(call.currency).to.equal("Gleam")
			expect(call.amount).to.equal(120)
			expect(call.endingBalance).to.equal(380)
			expect(call.transactionType).to.equal("Shop")
			expect(call.sku).to.equal("skin:rare")
			expect(fields[1]).to.equal("Pippa.Bubble")
			expect(fields[2]).to.equal("rare")
			expect(fields[3]).to.equal("shop|new")
		end)

		it("names Acorns", function()
			local call = AnalyticsEconomyUtils.record(record({ currency = "acorns", flow = "source" }), 5, "ret")
			expect(call.currency).to.equal("Acorns")
			expect(call.flow).to.equal("source")
		end)

		it("missing item, rarity and where read as -", function()
			local bare = record({})
			bare.item, bare.rarity, bare.where = nil, nil, nil
			local _, fields = AnalyticsEconomyUtils.record(bare, 10, "unk")
			expect(fields[1]).to.equal("-")
			expect(fields[2]).to.equal("-")
			expect(fields[3]).to.equal("-|unk")
		end)

		it("cleans tokens: odd characters dropped, length capped", function()
			local _, fields =
				AnalyticsEconomyUtils.record(record({ item = "a b|c#" .. string.rep("x", 80) }), 10, "new")
			expect(string.find(fields[1], "[ |]")).to.equal(nil)
			expect(#fields[1] <= 50).to.equal(true)
		end)

		it("nothing for no amount, a bad number, no balance, an empty sku or an unknown currency", function()
			expect(AnalyticsEconomyUtils.record(record({ amount = 0 }), 10, "new")).to.equal(nil)
			expect(AnalyticsEconomyUtils.record(record({ amount = -5 }), 10, "new")).to.equal(nil)
			expect(AnalyticsEconomyUtils.record(record({ amount = 0 / 0 }), 10, "new")).to.equal(nil)
			expect(AnalyticsEconomyUtils.record(record({}), nil, "new")).to.equal(nil)
			expect(AnalyticsEconomyUtils.record(record({}), math.huge, "new")).to.equal(nil)
			expect(AnalyticsEconomyUtils.record(record({ sku = "" }), 10, "new")).to.equal(nil)
			expect(AnalyticsEconomyUtils.record(record({ currency = "coins" }), 10, "new")).to.equal(nil)
		end)
	end)

	describe("token", function()
		it("keeps ids and words, drops the rest", function()
			expect(AnalyticsEconomyUtils.token("Bundle.Showstopper")).to.equal("Bundle.Showstopper")
			expect(AnalyticsEconomyUtils.token("locker:gloom_1")).to.equal("locker:gloom_1")
			expect(AnalyticsEconomyUtils.token(nil)).to.equal("-")
			expect(AnalyticsEconomyUtils.token("")).to.equal("-")
			expect(AnalyticsEconomyUtils.token("!!")).to.equal("-")
		end)
	end)

	describe("item", function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
		local CosmeticBundleRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticBundleRegistry)

		it("a catalogue item groups as kind:rarity, with its rarity", function()
			local item = CosmeticRegistry.all()[1]
			local sku, rarity = AnalyticsEconomyUtils.item(item.id)
			expect(sku).to.equal(`{item.kind}:{item.rarity}`)
			expect(rarity).to.equal(item.rarity)
		end)

		it("a bundle groups as bundle:rarity", function()
			local bundle = CosmeticBundleRegistry.all()[1]
			if bundle == nil then
				return
			end
			local sku, rarity = AnalyticsEconomyUtils.item(bundle.id)
			expect(sku).to.equal(`bundle:{bundle.rarity}`)
			expect(rarity).to.equal(bundle.rarity)
		end)

		it("an unknown id groups as other, with no rarity", function()
			local sku, rarity = AnalyticsEconomyUtils.item("Nobody.Nothing")
			expect(sku).to.equal("other")
			expect(rarity).to.equal(nil)
		end)
	end)
end
