local InteractionRegistry = require(script.Parent.InteractionRegistry)

local function ensure(id, value)
	if not InteractionRegistry.has(id) then
		InteractionRegistry.register(id, value)
	end
end

return function()
	local function refuses(id, value)
		expect(function()
			InteractionRegistry.register(id, value)
		end).to.throw()
		expect(InteractionRegistry.has(id)).to.equal(false)
	end

	it("registers and returns a kind", function()
		ensure("spec-door", { actionText = "Open", objectText = "Door", holdDuration = 0.5, cooldown = 1 })
		expect(InteractionRegistry.get("spec-door").actionText).to.equal("Open")
	end)

	it("rejects a duplicate kind", function()
		ensure("spec-dup", { actionText = "Use" })
		expect(function()
			InteractionRegistry.register("spec-dup", { actionText = "Use" })
		end).to.throw()
	end)

	it("rejects an empty action text", function()
		refuses("spec-no-text", { actionText = "" })
	end)

	it("rejects negative hold, distance or cooldown", function()
		refuses("spec-hold", { actionText = "Use", holdDuration = -1 })
		refuses("spec-distance", { actionText = "Use", maxDistance = 0 })
		refuses("spec-cooldown", { actionText = "Use", cooldown = -1 })
	end)
end
