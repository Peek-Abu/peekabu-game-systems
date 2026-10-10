local ToastStore = require(script.Parent.ToastStore)

return function()
	beforeEach(function()
		ToastStore.toasts({})
	end)

	it("pushes toasts with increasing ids and an expiry", function()
		ToastStore.push("one", "info", 4, 100)
		ToastStore.push("two", "info", 4, 101)
		local list = ToastStore.toasts()
		expect(#list).to.equal(2)
		expect(list[2].id > list[1].id).to.equal(true)
		expect(list[1].expiresAt).to.equal(104)
	end)

	it("expires toasts on time", function()
		ToastStore.push("one", "info", 4, 100)
		ToastStore.expire(103)
		expect(#ToastStore.toasts()).to.equal(1)
		ToastStore.expire(105)
		expect(#ToastStore.toasts()).to.equal(0)
	end)
end
