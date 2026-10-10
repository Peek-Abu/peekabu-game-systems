local ToastRegistry = require(script.Parent.ToastRegistry)

local STYLE = {
	background = Color3.new(1, 1, 0),
	text = Color3.new(0, 0, 0),
	accent = Color3.new(1, 0, 0),
	font = Enum.Font.SourceSans,
}

return function()
	it("ships the info style", function()
		expect(ToastRegistry.has("info")).to.equal(true)
	end)

	it("registers and returns a style", function()
		if not ToastRegistry.has("spec-sticky") then
			ToastRegistry.register("spec-sticky", STYLE)
		end
		expect(ToastRegistry.get("spec-sticky").background).to.equal(STYLE.background)
	end)

	it("rejects a duplicate style", function()
		if not ToastRegistry.has("spec-dup") then
			ToastRegistry.register("spec-dup", STYLE)
		end
		expect(function()
			ToastRegistry.register("spec-dup", STYLE)
		end).to.throw()
	end)
end
