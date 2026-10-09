local VfxRecipeRegistry = require(script.Parent.VfxRecipeRegistry)

local function recipe(overrides)
	local base = { template = "Spark", lifetime = 0.5 }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function ensure(id, value)
	if not VfxRecipeRegistry.has(id) then
		VfxRecipeRegistry.register(id, value)
	end
end

return function()
	-- Inside the returned function: TestEZ injects `expect` only into this scope.
	local function refuses(id, value)
		expect(function()
			VfxRecipeRegistry.register(id, value)
		end).to.throw()
		expect(VfxRecipeRegistry.has(id)).to.equal(false)
	end

	it("registers and returns a recipe", function()
		ensure("spec-spark", recipe({ sound = "spark", trauma = 0.3, shakeRadius = 40 }))
		expect(VfxRecipeRegistry.get("spec-spark").template).to.equal("Spark")
		expect(table.find(VfxRecipeRegistry.ids(), "spec-spark")).to.be.ok()
	end)

	it("rejects a duplicate id", function()
		ensure("spec-dup", recipe())
		expect(function()
			VfxRecipeRegistry.register("spec-dup", recipe())
		end).to.throw()
	end)

	it("rejects an empty template", function()
		refuses("spec-no-template", recipe({ template = "" }))
	end)

	it("rejects a non-positive lifetime", function()
		refuses("spec-no-life", recipe({ lifetime = 0 }))
	end)

	it("rejects trauma outside 0..1", function()
		refuses("spec-trauma", recipe({ trauma = 1.5, shakeRadius = 10 }))
	end)

	it("requires a positive shakeRadius when trauma is set", function()
		refuses("spec-no-radius", recipe({ trauma = 0.5 }))
		refuses("spec-zero-radius", recipe({ trauma = 0.5, shakeRadius = 0 }))
	end)

	it("rejects an empty sound id", function()
		refuses("spec-empty-sound", recipe({ sound = "" }))
	end)
end
