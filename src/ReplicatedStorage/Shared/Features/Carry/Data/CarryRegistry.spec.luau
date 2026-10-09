local CarryRegistry = require(script.Parent.CarryRegistry)

local function ensure(id, value)
	if not CarryRegistry.has(id) then
		CarryRegistry.register(id, value)
	end
end

return function()
	local function refuses(id, value)
		expect(function()
			CarryRegistry.register(id, value)
		end).to.throw()
		expect(CarryRegistry.has(id)).to.equal(false)
	end

	it("registers and returns a kind", function()
		ensure("spec-egg", { weight = 2, throwable = true, throwSpeed = 30 })
		expect(CarryRegistry.get("spec-egg").weight).to.equal(2)
	end)

	it("rejects a duplicate kind", function()
		ensure("spec-dup", { weight = 1 })
		expect(function()
			CarryRegistry.register("spec-dup", { weight = 1 })
		end).to.throw()
	end)

	it("rejects a negative weight", function()
		refuses("spec-negative", { weight = -1 })
	end)

	it("rejects a non-positive throw speed", function()
		refuses("spec-throw", { weight = 1, throwable = true, throwSpeed = 0 })
	end)
end
