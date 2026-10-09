local InputContextTracker = require(script.Parent.InputContextTracker)

local function names(stack)
	local out = {}
	for _, entry in stack do
		table.insert(out, entry.name)
	end
	return table.concat(out, ",")
end

return function()
	it("starts empty", function()
		local tracker = InputContextTracker.new()
		expect(#tracker:snapshot()).to.equal(0)
	end)

	it("pushes contexts bottom-first with their sink flag", function()
		local tracker = InputContextTracker.new()
		tracker:push("vehicle", false)
		tracker:push("ui", true)
		local stack = tracker:snapshot()
		expect(names(stack)).to.equal("vehicle,ui")
		expect(stack[2].sink).to.equal(true)
	end)

	it("returns distinct tokens and removes by token in any order", function()
		local tracker = InputContextTracker.new()
		local a = tracker:push("vehicle", false)
		local b = tracker:push("ui", true)
		expect(a).never.to.equal(b)
		expect(tracker:remove(a)).to.equal(true)
		expect(names(tracker:snapshot())).to.equal("ui")
		expect(tracker:remove(b)).to.equal(true)
		expect(#tracker:snapshot()).to.equal(0)
	end)

	it("allows the same name twice (two systems may want the same mode)", function()
		local tracker = InputContextTracker.new()
		local a = tracker:push("ui", true)
		tracker:push("ui", true)
		tracker:remove(a)
		expect(names(tracker:snapshot())).to.equal("ui")
	end)

	it("remove is false for an unknown or already-removed token", function()
		local tracker = InputContextTracker.new()
		local a = tracker:push("ui", true)
		expect(tracker:remove(a)).to.equal(true)
		expect(tracker:remove(a)).to.equal(false)
		expect(tracker:remove(999)).to.equal(false)
	end)

	it("snapshots are copies", function()
		local tracker = InputContextTracker.new()
		tracker:push("ui", true)
		local stack = tracker:snapshot()
		table.clear(stack)
		expect(#tracker:snapshot()).to.equal(1)
	end)
end
