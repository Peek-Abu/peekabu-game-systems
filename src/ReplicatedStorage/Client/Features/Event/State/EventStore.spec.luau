local EventStore = require(script.Parent.EventStore)

return function()
	afterEach(function()
		EventStore.setPaid(nil)
	end)

	it("holds what the last shift paid in the event's money, until cleared", function()
		expect(EventStore.paid()).to.equal(nil)
		EventStore.setPaid({ event = "harvest", total = 40, parts = { "finished", "contract", "firstToday" } })
		expect(EventStore.paid().total).to.equal(40)
		expect(EventStore.paid().event).to.equal("harvest")
		EventStore.setPaid(nil)
		expect(EventStore.paid()).to.equal(nil)
	end)
end
