local VfxAtmosphereRegistry = require(script.Parent.VfxAtmosphereRegistry)

local function ensure(id, value)
	if not VfxAtmosphereRegistry.has(id) then
		VfxAtmosphereRegistry.register(id, value)
	end
end

local function refuses(id, value)
	expect(function()
		VfxAtmosphereRegistry.register(id, value)
	end).to.throw()
	expect(VfxAtmosphereRegistry.has(id)).to.equal(false)
end

return function()
	it("registers and returns a preset", function()
		ensure("spec-night", { clockTime = 0, brightness = 0.5, ambient = Color3.new(0.1, 0.1, 0.2) })
		expect(VfxAtmosphereRegistry.get("spec-night").clockTime).to.equal(0)
	end)

	it("rejects a duplicate id", function()
		ensure("spec-dup", { brightness = 1 })
		expect(function()
			VfxAtmosphereRegistry.register("spec-dup", { brightness = 1 })
		end).to.throw()
	end)

	it("rejects an empty preset", function()
		refuses("spec-empty", {})
	end)

	it("rejects a clock time outside 0..24", function()
		refuses("spec-clock", { clockTime = 25 })
	end)

	it("rejects negative brightness", function()
		refuses("spec-dark", { brightness = -1 })
	end)

	it("rejects fog that starts after it ends", function()
		refuses("spec-fog", { fogStart = 100, fogEnd = 50 })
	end)
end
