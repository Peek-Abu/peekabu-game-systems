local LeaderstatRegistry = require(script.Parent.LeaderstatRegistry)

local function read()
	return 0
end

local function ensure(name, order)
	if LeaderstatRegistry.get(name) == nil then
		LeaderstatRegistry.register(name, { order = order, read = read })
	end
end

return function()
	it("lists columns by order, then name", function()
		ensure("Spec Zeta", 1)
		ensure("Spec Alpha", 1)
		ensure("Spec First", 0)
		local names = LeaderstatRegistry.names()
		local first = table.find(names, "Spec First")
		local alpha = table.find(names, "Spec Alpha")
		local zeta = table.find(names, "Spec Zeta")
		expect(first < alpha).to.equal(true)
		expect(alpha < zeta).to.equal(true)
	end)

	it("rejects a duplicate or an empty name", function()
		ensure("Spec Dup", 0)
		expect(function()
			LeaderstatRegistry.register("Spec Dup", { order = 0, read = read })
		end).to.throw()
		expect(function()
			LeaderstatRegistry.register("", { order = 0, read = read })
		end).to.throw()
	end)

	it("returns the reader", function()
		ensure("Spec Read", 3)
		expect(LeaderstatRegistry.get("Spec Read").read).to.equal(read)
		expect(LeaderstatRegistry.get("Spec Missing")).to.equal(nil)
	end)
end
