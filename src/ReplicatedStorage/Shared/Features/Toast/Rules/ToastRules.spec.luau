local ToastRules = require(script.Parent.ToastRules)

local function hasStyle(name)
	return name == "info" or name == "stamp"
end

return function()
	it("keeps a well-formed request", function()
		local toast = ToastRules.normalize({ text = "QUOTA MET", style = "stamp", duration = 3 }, hasStyle)
		expect(toast.text).to.equal("QUOTA MET")
		expect(toast.style).to.equal("stamp")
		expect(toast.duration).to.equal(3)
	end)

	it("refuses empty or blank text", function()
		local toast, reason = ToastRules.normalize({ text = "   " }, hasStyle)
		expect(toast).to.equal(nil)
		expect(reason).to.equal("empty")
	end)

	it("clamps long text to MAX_TEXT characters", function()
		local toast = ToastRules.normalize({ text = string.rep("a", 500) }, hasStyle)
		expect(#toast.text).to.equal(140)
	end)

	it("cuts multi-byte text at characters, not bytes", function()
		local toast = ToastRules.normalize({ text = string.rep("\u{e9}", 200) }, hasStyle)
		expect(utf8.len(toast.text)).to.equal(140)
	end)

	it("falls back to info for a missing or unknown style", function()
		expect(ToastRules.normalize({ text = "hi" }, hasStyle).style).to.equal("info")
		expect(ToastRules.normalize({ text = "hi", style = "nope" }, hasStyle).style).to.equal("info")
	end)

	it("defaults and clamps the duration", function()
		expect(ToastRules.normalize({ text = "hi" }, hasStyle).duration).to.equal(4)
		expect(ToastRules.normalize({ text = "hi", duration = 0 }, hasStyle).duration).to.equal(1)
		expect(ToastRules.normalize({ text = "hi", duration = 999 }, hasStyle).duration).to.equal(15)
	end)
end
