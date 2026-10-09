local CameraModeTracker = require(script.Parent.CameraModeTracker)

local function fixed(tag)
	return { kind = "fixed", cframe = CFrame.new(), fov = tag }
end

return function()
	it("has no top on an empty stack", function()
		expect(CameraModeTracker.new():top()).to.equal(nil)
	end)

	it("the higher priority wins whatever the push order", function()
		local tracker = CameraModeTracker.new()
		tracker:push(fixed(1), 10)
		tracker:push(fixed(2), 0)
		expect(tracker:top().def.fov).to.equal(1)
	end)

	it("equal priorities go to the most recent push", function()
		local tracker = CameraModeTracker.new()
		tracker:push(fixed(1), 5)
		tracker:push(fixed(2), 5)
		expect(tracker:top().def.fov).to.equal(2)
	end)

	it("removing the top reveals the next one", function()
		local tracker = CameraModeTracker.new()
		tracker:push(fixed(1), 0)
		local top = tracker:push(fixed(2), 1)
		expect(tracker:remove(top)).to.equal(true)
		expect(tracker:top().def.fov).to.equal(1)
	end)

	it("removes by token from anywhere in the stack", function()
		local tracker = CameraModeTracker.new()
		local bottom = tracker:push(fixed(1), 0)
		tracker:push(fixed(2), 1)
		expect(tracker:remove(bottom)).to.equal(true)
		expect(tracker:top().def.fov).to.equal(2)
		expect(tracker:count()).to.equal(1)
	end)

	it("remove is false for an unknown token", function()
		local tracker = CameraModeTracker.new()
		local token = tracker:push(fixed(1), 0)
		tracker:remove(token)
		expect(tracker:remove(token)).to.equal(false)
	end)

	it("hands out distinct tokens", function()
		local tracker = CameraModeTracker.new()
		expect(tracker:push(fixed(1), 0)).never.to.equal(tracker:push(fixed(2), 0))
	end)
end
