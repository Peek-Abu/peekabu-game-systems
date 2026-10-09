local EntitlementRegistry = require(script.Parent.EntitlementRegistry)

local function ensure(category, id)
	if not EntitlementRegistry.has(category, id) then
		EntitlementRegistry.register(category, id, { name = id })
	end
end

return function()
	it("registers an id under a category", function()
		ensure("spec-suit", "hazmat")
		expect(EntitlementRegistry.has("spec-suit", "hazmat")).to.equal(true)
		expect(EntitlementRegistry.get("spec-suit", "hazmat").name).to.equal("hazmat")
		expect(EntitlementRegistry.has("spec-suit", "nope")).to.equal(false)
		expect(EntitlementRegistry.has("spec-nope", "hazmat")).to.equal(false)
	end)

	it("lists a category's ids sorted, and the categories", function()
		ensure("spec-skin", "b")
		ensure("spec-skin", "a")
		local ids = EntitlementRegistry.idsIn("spec-skin")
		expect(ids[1]).to.equal("a")
		expect(ids[2]).to.equal("b")
		expect(#EntitlementRegistry.idsIn("spec-empty")).to.equal(0)
		expect(table.find(EntitlementRegistry.categories(), "spec-skin")).to.be.ok()
	end)

	it("rejects a duplicate, an empty or over-long name, and a missing display name", function()
		ensure("spec-dup", "x")
		expect(function()
			EntitlementRegistry.register("spec-dup", "x", { name = "x" })
		end).to.throw()
		expect(function()
			EntitlementRegistry.register("", "x", { name = "x" })
		end).to.throw()
		expect(function()
			EntitlementRegistry.register("spec-long", string.rep("y", 65), { name = "y" })
		end).to.throw()
		expect(function()
			EntitlementRegistry.register("spec-unnamed", "z", { name = "" })
		end).to.throw()
		expect(EntitlementRegistry.has("spec-unnamed", "z")).to.equal(false)
	end)
end
