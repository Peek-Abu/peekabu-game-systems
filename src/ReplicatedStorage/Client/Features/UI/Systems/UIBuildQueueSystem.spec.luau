local UIBuildQueueSystem = require(script.Parent.UIBuildQueueSystem)

-- A clock the test moves by hand: each job advances it by its own cost.
local function fakeClock()
	local now = 0
	return function()
		return now
	end, function(seconds)
		now += seconds
	end
end

return function()
	describe("UIBuildQueueSystem", function()
		it("runs nothing when queued, then the jobs in order on the next steps", function()
			local clock, advance = fakeClock()
			local queue = UIBuildQueueSystem.new(0.004, clock)
			local ran = {}
			for i = 1, 3 do
				queue:enqueue(function()
					table.insert(ran, i)
					advance(0.001)
				end)
			end
			expect(#ran).to.equal(0)
			expect(queue:pending()).to.equal(3)
			expect(queue:step()).to.equal(3)
			expect(table.concat(ran, ",")).to.equal("1,2,3")
			expect(queue:pending()).to.equal(0)
		end)

		it("stops a step once the frame's budget is spent, always running at least one job", function()
			local clock, advance = fakeClock()
			local queue = UIBuildQueueSystem.new(0.004, clock)
			local ran = 0
			for _ = 1, 12 do
				queue:enqueue(function()
					ran += 1
					-- a card clone measured 2.5-4 ms (Lobby, 2026-11-15)
					advance(0.003)
				end)
			end
			-- 3 ms, then 6 ms: past the 4 ms budget after the second job
			expect(queue:step()).to.equal(2)
			expect(ran).to.equal(2)
			local steps = 1
			while queue:pending() > 0 do
				queue:step()
				steps += 1
			end
			expect(ran).to.equal(12)
			expect(steps).to.equal(6)

			-- one job over the whole budget still runs alone
			queue:enqueue(function()
				advance(0.05)
			end)
			queue:enqueue(function() end)
			expect(queue:step()).to.equal(1)
		end)

		it("never runs a cancelled job, and cancelling twice or after it ran is harmless", function()
			local clock = fakeClock()
			local queue = UIBuildQueueSystem.new(0.004, clock)
			local ran = {}
			local cancelA = queue:enqueue(function()
				table.insert(ran, "a")
			end)
			queue:enqueue(function()
				table.insert(ran, "b")
			end)
			cancelA()
			cancelA()
			expect(queue:pending()).to.equal(1)
			queue:step()
			expect(table.concat(ran, ",")).to.equal("b")

			local cancelC = queue:enqueue(function()
				table.insert(ran, "c")
			end)
			queue:step()
			cancelC()
			expect(table.concat(ran, ",")).to.equal("b,c")
		end)

		it("keeps going after a job errors", function()
			local clock = fakeClock()
			local queue = UIBuildQueueSystem.new(0.004, clock)
			local ran = false
			queue:enqueue(function()
				error("a broken card")
			end)
			queue:enqueue(function()
				ran = true
			end)
			queue:step()
			expect(ran).to.equal(true)
			expect(queue:pending()).to.equal(0)
		end)

		it("runs the shared queue's jobs on later frames, not in the frame they were queued", function()
			local ran = false
			local cancel = UIBuildQueueSystem.enqueue(function()
				ran = true
			end)
			expect(ran).to.equal(false)
			local waited = 0
			while not ran and waited < 1 do
				waited += task.wait()
			end
			expect(ran).to.equal(true)
			cancel()

			local cancelled = false
			local cancelNow = UIBuildQueueSystem.enqueue(function()
				cancelled = true
			end)
			cancelNow()
			task.wait()
			task.wait()
			expect(cancelled).to.equal(false)
		end)
	end)
end
