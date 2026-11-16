local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local EventRegistry = require(script.Parent.EventRegistry)

return function()
	it("lists every event once, looked up by id", function()
		local seen = {}
		for _, event in EventRegistry.all() do
			expect(seen[event.id]).to.equal(nil)
			seen[event.id] = true
			expect(EventRegistry.get(event.id)).to.equal(event)
		end
		expect(EventRegistry.get("nope")).to.equal(nil)
	end)

	it("gives every event real dates, a real money and a real conversion", function()
		for _, event in EventRegistry.all() do
			expect(event.ends > event.starts).to.equal(true)
			expect(#event.name > 0 and #event.short > 0 and #event.short <= 10).to.equal(true)
			expect(CurrencyConstants.isValidCurrencyType(event.currency)).to.equal(true)
			expect(CurrencyConstants.isValidCurrencyType(event.convertTo)).to.equal(true)
			expect(event.convertTo).never.to.equal(event.currency)
			expect(event.convertRate > 0).to.equal(true)
			for _, amount in event.pay do
				expect(amount >= 0).to.equal(true)
			end
			for _, key in event.keys do
				expect(key.price > 0).to.equal(true)
			end
		end
	end)

	it("never lets two events run at once (one event money live at a time)", function()
		local all = EventRegistry.all()
		for i, a in all do
			for j, b in all do
				if i ~= j then
					expect(a.ends <= b.starts or b.ends <= a.starts).to.equal(true)
				end
			end
		end
	end)

	it("runs the Thanksgiving event on acorns, paying the approved table", function()
		local harvest = EventRegistry.get("harvest")
		expect(harvest).to.be.ok()
		expect(harvest.currency).to.equal("acorns")
		expect(harvest.pay.finished).to.equal(10)
		expect(harvest.pay.contract).to.equal(10)
		expect(harvest.pay.firstToday).to.equal(20)
		expect(harvest.pay.friend).to.equal(5)
		expect(harvest.convertTo).to.equal("credits")
		expect(harvest.convertRate).to.equal(5)
		-- About one acorn pickup a shift, worth 5 (owner, 11-16).
		expect(harvest.pickup.amount).to.equal(5)
		expect(harvest.pickup.firstPile >= 1).to.equal(true)
		expect(harvest.pickup.lastPile >= harvest.pickup.firstPile).to.equal(true)
		-- Dates approved 11-16: Thu 26 Nov 12:00 am ET to the end of Sun 20 Dec ET.
		expect(harvest.starts).to.equal(1795669200)
		expect(harvest.ends).to.equal(1797829200)
	end)
end
