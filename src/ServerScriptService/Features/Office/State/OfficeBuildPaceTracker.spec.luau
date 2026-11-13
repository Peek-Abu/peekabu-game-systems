local OfficeBuildPaceTracker = require(script.Parent.OfficeBuildPaceTracker)

return function()
	-- A fake clock the test moves by hand, and a wait that counts its calls (a yield takes one "frame", 0.016).
	local function rig(budget)
		local state = { now = 0, waits = 0 }
		local pace = OfficeBuildPaceTracker.new(budget, function()
			return state.now
		end, function()
			state.waits += 1
			state.now += 0.016
		end)
		return pace, state
	end

	it("never yields while the stretch is under budget", function()
		local pace, state = rig(0.1)
		for _ = 1, 9 do
			state.now += 0.01
			expect(pace:step()).to.equal(false)
		end
		expect(state.waits).to.equal(0)
	end)

	it("yields once the stretch reaches the budget, and starts a new stretch after", function()
		local pace, state = rig(0.1)
		state.now += 0.1
		expect(pace:step()).to.equal(true)
		expect(state.waits).to.equal(1)
		-- The new stretch counts from the resumption, not from the start.
		state.now += 0.05
		expect(pace:step()).to.equal(false)
		state.now += 0.05
		expect(pace:step()).to.equal(true)
		expect(state.waits).to.equal(2)
	end)

	it("keeps the longest stretch and how many times it yielded", function()
		local pace, state = rig(0.1)
		state.now += 0.13
		pace:step()
		state.now += 0.02
		pace:step()
		state.now += 0.2
		pace:step()
		local stats = pace:stats()
		expect(stats.yields).to.equal(2)
		expect(stats.longest).to.be.near(0.2, 1e-9)
	end)

	it("restarts the stretch on begin, so time spent elsewhere is not charged to the build", function()
		local pace, state = rig(0.1)
		state.now += 5
		pace:begin()
		state.now += 0.05
		expect(pace:step()).to.equal(false)
		expect(state.waits).to.equal(0)
		expect(pace:stats().longest).to.equal(0)
	end)

	it("counts the last stretch when the stats are read", function()
		local pace, state = rig(0.1)
		pace:begin()
		state.now += 0.07
		expect(pace:stats().longest).to.be.near(0.07, 1e-9)
	end)

	it("has a shared pace the build passes step through", function()
		expect(type(OfficeBuildPaceTracker.step)).to.equal("function")
		expect(type(OfficeBuildPaceTracker.shared:stats().yields)).to.equal("number")
	end)
end
