local QueueRegistry = require(script.Parent.QueueRegistry)

-- The registry is module state shared by the whole test session: register each role once.
local function ensure(role, placeId)
	if not QueueRegistry.has(role) then
		QueueRegistry.register(role, placeId)
	end
end

return function()
	it("registers a role and returns its place", function()
		ensure("spec-home", 910000001)
		expect(QueueRegistry.placeOf("spec-home")).to.equal(910000001)
		expect(QueueRegistry.roles()["spec-home"]).to.equal(910000001)
	end)

	it("rejects a duplicate role", function()
		ensure("spec-dup", 910000002)
		expect(function()
			QueueRegistry.register("spec-dup", 910000003)
		end).to.throw()
	end)

	it("rejects an empty role, a negative or a fractional PlaceId", function()
		expect(function()
			QueueRegistry.register("", 910000004)
		end).to.throw()
		expect(function()
			QueueRegistry.register("spec-negative", -1)
		end).to.throw()
		expect(function()
			QueueRegistry.register("spec-fraction", 1.5)
		end).to.throw()
		expect(QueueRegistry.has("spec-negative")).to.equal(false)
		expect(QueueRegistry.has("spec-fraction")).to.equal(false)
	end)

	it("refuses two roles on one real place but allows several placeholders", function()
		ensure("spec-place-a", 910000005)
		expect(function()
			QueueRegistry.register("spec-place-b", 910000005)
		end).to.throw()
		ensure("spec-later-a", 0)
		ensure("spec-later-b", 0)
		expect(QueueRegistry.placeOf("spec-later-b")).to.equal(0)
	end)

	it("knows nothing about an unregistered role", function()
		expect(QueueRegistry.has("spec-never")).to.equal(false)
		expect(QueueRegistry.placeOf("spec-never")).to.equal(nil)
	end)

	it("hands out a frozen copy", function()
		expect(table.isfrozen(QueueRegistry.roles())).to.equal(true)
	end)
end
