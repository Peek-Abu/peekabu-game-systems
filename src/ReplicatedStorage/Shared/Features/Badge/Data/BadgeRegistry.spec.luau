local BadgeRegistry = require(script.Parent.BadgeRegistry)

local function ensure(key, badgeId)
	if BadgeRegistry.get(key) == nil then
		BadgeRegistry.register(key, { badgeId = badgeId })
	end
end

return function()
	it("registers a badge and finds it by key and id", function()
		ensure("spec-first-night", 990100001)
		expect(BadgeRegistry.get("spec-first-night").badgeId).to.equal(990100001)
		expect(BadgeRegistry.keyFor(990100001)).to.equal("spec-first-night")
		expect(table.find(BadgeRegistry.keys(), "spec-first-night")).to.be.ok()
	end)

	it("rejects a duplicate key or id, and a bad id", function()
		ensure("spec-dup-badge", 990100002)
		expect(function()
			BadgeRegistry.register("spec-dup-badge", { badgeId = 990100003 })
		end).to.throw()
		expect(function()
			BadgeRegistry.register("spec-other-badge", { badgeId = 990100002 })
		end).to.throw()
		expect(function()
			BadgeRegistry.register("spec-bad-badge", { badgeId = 0 })
		end).to.throw()
		expect(function()
			BadgeRegistry.register("", { badgeId = 990100004 })
		end).to.throw()
	end)
end
