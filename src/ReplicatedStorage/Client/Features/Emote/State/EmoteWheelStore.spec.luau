local EmoteWheelStore = require(script.Parent.EmoteWheelStore)

return function()
	afterEach(function()
		EmoteWheelStore.reset()
	end)

	it("opens with nothing picked and hands back the leaned-toward slot as it closes", function()
		EmoteWheelStore.show()
		expect(EmoteWheelStore.open()).to.equal(true)
		expect(EmoteWheelStore.hovered()).to.equal(nil)
		EmoteWheelStore.hover(3)
		expect(EmoteWheelStore.hide()).to.equal(3)
		expect(EmoteWheelStore.open()).to.equal(false)
		expect(EmoteWheelStore.hovered()).to.equal(nil)
	end)

	it("closes with no slot when nothing was picked", function()
		EmoteWheelStore.show()
		expect(EmoteWheelStore.hide()).to.equal(nil)
	end)
end
