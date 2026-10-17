local CrouchStore = require(script.Parent.CrouchStore)

return function()
	afterEach(function()
		CrouchStore.apply(nil)
	end)

	it("copies the server's crouch flag", function()
		CrouchStore.apply(true)
		expect(CrouchStore.crouching()).to.equal(true)
	end)

	it("reads anything but true as standing", function()
		CrouchStore.apply(nil)
		expect(CrouchStore.crouching()).to.equal(false)
		CrouchStore.apply("yes")
		expect(CrouchStore.crouching()).to.equal(false)
		CrouchStore.apply(1)
		expect(CrouchStore.crouching()).to.equal(false)
	end)
end
