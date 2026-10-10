local ToastQueueUtils = require(script.Parent.ToastQueueUtils)

local function toast(id, expiresAt)
	return { id = id, text = tostring(id), style = "info", expiresAt = expiresAt }
end

return function()
	it("appends the newest last", function()
		local list = ToastQueueUtils.push({ toast(1, 10) }, toast(2, 10), 4)
		expect(#list).to.equal(2)
		expect(list[2].id).to.equal(2)
	end)

	it("drops the oldest beyond maxVisible", function()
		local list = {}
		for id = 1, 5 do
			list = ToastQueueUtils.push(list, toast(id, 10), 4)
		end
		expect(#list).to.equal(4)
		expect(list[1].id).to.equal(2)
	end)

	it("does not change the list it was given", function()
		local original = { toast(1, 10) }
		ToastQueueUtils.push(original, toast(2, 10), 4)
		expect(#original).to.equal(1)
	end)

	it("expires toasts whose time has passed and says whether anything changed", function()
		local list, changed = ToastQueueUtils.expire({ toast(1, 5), toast(2, 15) }, 10)
		expect(changed).to.equal(true)
		expect(#list).to.equal(1)
		expect(list[1].id).to.equal(2)
		local _, unchanged = ToastQueueUtils.expire(list, 10)
		expect(unchanged).to.equal(false)
	end)
end
