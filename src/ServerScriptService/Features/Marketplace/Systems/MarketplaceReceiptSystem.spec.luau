local MarketplaceReceiptSystem = require(script.Parent.MarketplaceReceiptSystem)

local RECEIPT = { purchaseId = "p-1", playerId = 7, productId = 555, currencySpent = 10 }

-- A fake world: one player's receipt history and coin balance, with a commit that applies every op to
-- it all-or-nothing (and can be told to fail its durable save).
local function world()
	local self = {
		present = true,
		loaded = true,
		receipts = { ids = {} },
		coins = 0,
		saveSucceeds = true,
		commits = 0,
		grantCalls = 0,
		grantFails = false,
	}
	self.deps = {
		productKeyFor = function(productId)
			return if productId == 555 then "coins-small" else nil
		end,
		isPresent = function(_userId)
			return self.present
		end,
		readReceipts = function(_userId)
			return if self.loaded then self.receipts else nil
		end,
		recordOp = function(_userId, purchaseId)
			return function()
				if table.find(self.receipts.ids, purchaseId) == nil then
					table.insert(self.receipts.ids, purchaseId)
				end
			end
		end,
		grantOps = function(_userId, key, _receipt)
			self.grantCalls += 1
			if self.grantFails then
				return nil, "handler failed"
			end
			expect(key).to.equal("coins-small")
			return {
				function()
					self.coins += 100
				end,
			}
		end,
		commit = function(ops)
			self.commits += 1
			for _, op in ops do
				op()
			end
			return self.saveSucceeds
		end,
	}
	return self
end

return function()
	it("grants a new purchase once and acknowledges it", function()
		local w = world()
		local decision, _, granted = MarketplaceReceiptSystem.process(RECEIPT, w.deps, {})
		expect(decision).to.equal("granted")
		expect(granted).to.equal(true)
		expect(w.coins).to.equal(100)
		expect(table.find(w.receipts.ids, "p-1")).to.be.ok()
	end)

	it("never grants a purchase id twice", function()
		local w = world()
		local inFlight = {}
		MarketplaceReceiptSystem.process(RECEIPT, w.deps, inFlight)
		local decision, _, granted = MarketplaceReceiptSystem.process(RECEIPT, w.deps, inFlight)
		expect(decision).to.equal("granted")
		expect(granted).to.equal(false)
		expect(w.coins).to.equal(100)
		expect(w.grantCalls).to.equal(1)
	end)

	it("asks again (and grants nothing new on the retry) when the durable save is not confirmed", function()
		local w = world()
		w.saveSucceeds = false
		local decision = MarketplaceReceiptSystem.process(RECEIPT, w.deps, {})
		expect(decision).to.equal("retry")
		-- The grant is committed in memory; Roblox will call again.
		w.saveSucceeds = true
		local again, _, granted = MarketplaceReceiptSystem.process(RECEIPT, w.deps, {})
		expect(again).to.equal("granted")
		expect(granted).to.equal(false)
		expect(w.coins).to.equal(100)
		expect(w.commits).to.equal(2)
	end)

	it("asks again for an unknown product, an absent buyer or an unloaded profile, touching nothing", function()
		local w = world()
		local unknown = table.clone(RECEIPT)
		unknown.productId = 999
		expect((MarketplaceReceiptSystem.process(unknown, w.deps, {}))).to.equal("retry")

		w.present = false
		expect((MarketplaceReceiptSystem.process(RECEIPT, w.deps, {}))).to.equal("retry")

		w.present = true
		w.loaded = false
		expect((MarketplaceReceiptSystem.process(RECEIPT, w.deps, {}))).to.equal("retry")

		expect(w.commits).to.equal(0)
		expect(w.coins).to.equal(0)
	end)

	it("asks again when the product's grant handler fails, recording nothing", function()
		local w = world()
		w.grantFails = true
		local decision, reason = MarketplaceReceiptSystem.process(RECEIPT, w.deps, {})
		expect(decision).to.equal("retry")
		expect(reason).to.equal("handler failed")
		expect(w.commits).to.equal(0)
		expect(#w.receipts.ids).to.equal(0)
	end)

	it("asks again when the grant handler or the commit throws, and clears the in-flight mark", function()
		local w = world()
		local inFlight = {}
		w.deps.grantOps = function()
			error("boom")
		end
		expect((MarketplaceReceiptSystem.process(RECEIPT, w.deps, inFlight))).to.equal("retry")
		expect(inFlight["p-1"]).to.equal(nil)

		w = world()
		w.deps.commit = function()
			error("datastore down")
		end
		expect((MarketplaceReceiptSystem.process(RECEIPT, w.deps, inFlight))).to.equal("retry")
		expect(inFlight["p-1"]).to.equal(nil)
	end)

	it("refuses a second callback for a purchase id that is still being processed", function()
		local w = world()
		local inFlight = { ["p-1"] = true }
		local decision = MarketplaceReceiptSystem.process(RECEIPT, w.deps, inFlight)
		expect(decision).to.equal("retry")
		expect(w.commits).to.equal(0)
		expect(inFlight["p-1"]).to.equal(true)
	end)

	it("releases the in-flight mark whatever the outcome", function()
		local w = world()
		local inFlight = {}
		w.saveSucceeds = false
		MarketplaceReceiptSystem.process(RECEIPT, w.deps, inFlight)
		expect(inFlight["p-1"]).to.equal(nil)
		w.grantFails = true
		local fresh = table.clone(RECEIPT)
		fresh.purchaseId = "p-2"
		MarketplaceReceiptSystem.process(fresh, w.deps, inFlight)
		expect(inFlight["p-2"]).to.equal(nil)
	end)
end
