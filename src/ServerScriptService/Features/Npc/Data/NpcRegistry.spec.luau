local NpcRegistry = require(script.Parent.NpcRegistry)

local function ensure(kind, input)
	if NpcRegistry.get(kind) == nil then
		NpcRegistry.register(kind, input)
	end
end

return function()
	it("fills unset fields from the defaults", function()
		ensure("spec-cow", { attitude = "timid", runSpeed = 20 })
		local def = NpcRegistry.get("spec-cow")
		expect(def.attitude).to.equal("timid")
		expect(def.runSpeed).to.equal(20)
		expect(def.walkSpeed).to.equal(8)
		expect(NpcRegistry.has("spec-cow")).to.equal(true)
	end)

	it("lists kinds sorted", function()
		ensure("spec-a", { attitude = "passive" })
		ensure("spec-b", { attitude = "passive" })
		local kinds = NpcRegistry.kinds()
		expect(table.find(kinds, "spec-a") < table.find(kinds, "spec-b")).to.equal(true)
	end)

	it("rejects a duplicate kind", function()
		ensure("spec-dup", { attitude = "passive" })
		expect(function()
			NpcRegistry.register("spec-dup", { attitude = "passive" })
		end).to.throw()
	end)

	it("rejects an unknown attitude and nonsense numbers", function()
		expect(function()
			NpcRegistry.register("spec-bad-1", { attitude = "angry" })
		end).to.throw()
		expect(function()
			NpcRegistry.register("spec-bad-2", { attitude = "hostile", sightAngle = 400 })
		end).to.throw()
		expect(function()
			NpcRegistry.register("spec-bad-3", { attitude = "hostile", attackCooldown = -1 })
		end).to.throw()
		expect(function()
			NpcRegistry.register("spec-bad-4", { attitude = "passive", walkSpeed = 20, runSpeed = 10 })
		end).to.throw()
		expect(NpcRegistry.has("spec-bad-1")).to.equal(false)
	end)
end
