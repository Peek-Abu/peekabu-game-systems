local CalloutWheelStore = require(script.Parent.CalloutWheelStore)

return function()
	afterEach(function()
		CalloutWheelStore.reset()
	end)

	it("keeps the aimed spot and hands back the pick as it closes", function()
		CalloutWheelStore.show(Vector3.new(1, 2, 3))
		expect(CalloutWheelStore.open()).to.equal(true)
		CalloutWheelStore.hover({ kind = "ping", id = "help" })
		local pick, spot = CalloutWheelStore.hide()
		expect(pick.id).to.equal("help")
		expect(spot).to.equal(Vector3.new(1, 2, 3))
		expect(CalloutWheelStore.open()).to.equal(false)
		expect(CalloutWheelStore.aim()).to.equal(nil)
	end)
end
