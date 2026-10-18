local RankShiftSystem = require(script.Parent.RankShiftSystem)

local function fakeSignal()
	local handlers = {}
	return {
		Connect = function(_self, fn)
			handlers[fn] = true
			return {
				Disconnect = function()
					handlers[fn] = nil
				end,
			}
		end,
		Fire = function(_self, ...)
			for fn in handlers do
				fn(...)
			end
		end,
	}
end

local function state(phase, shift, quotaMet, outcome)
	return {
		phase = phase,
		-- Only a results state carries one; the tests' reviews end through the clock-out unless they say otherwise.
		outcome = if phase == "results" then outcome or "clockout" else nil,
		sub = "normal",
		stage = "normal",
		tier = 0,
		shift = shift,
		quota = 100,
		quotaMet = quotaMet,
		variant = "A",
	}
end

local function member(userId, extra)
	local entry = { userId = userId, name = `P{userId}`, banked = 10, piles = 0, salvage = 0, caught = 0, items = 3 }
	for key, value in extra or {} do
		entry[key] = value
	end
	return entry
end

return function()
	describe("RankShiftSystem", function()
		local changed, crew, present, calls, stop

		local function begin(award)
			stop = RankShiftSystem.start({
				changed = changed,
				crew = function()
					return crew
				end,
				present = function()
					return present
				end,
			}, award or function(userId, runId, facts)
				table.insert(calls, { userId = userId, runId = runId, facts = facts })
			end, "spec")
		end

		beforeEach(function()
			changed = fakeSignal()
			crew = { member(1), member(2) }
			present = { 1, 2 }
			calls = {}
			begin()
		end)

		afterEach(function()
			stop()
		end)

		it("pays every crew member once when the shift reaches its review", function()
			changed:Fire(state("running", 1, false))
			expect(#calls).to.equal(0)
			changed:Fire(state("results", 1, true))
			expect(#calls).to.equal(2)
			expect(calls[1].runId).to.equal("spec:1")
			expect(calls[1].facts.items).to.equal(3)
			expect(calls[1].facts.quotaMet).to.equal(true)
			expect(calls[1].facts.crewExtracted).to.equal(true)
			changed:Fire(state("results", 1, true))
			expect(#calls).to.equal(2)
		end)

		it("pays the next shift under its own run id", function()
			changed:Fire(state("results", 1, true))
			changed:Fire(state("lobby", 1, true))
			crew = { member(1, { caught = 1 }) }
			present = { 1 }
			changed:Fire(state("results", 2, false))
			expect(#calls).to.equal(3)
			expect(calls[3].runId).to.equal("spec:2")
			expect(calls[3].facts.caught).to.equal(true)
			expect(calls[3].facts.extracted).to.equal(false)
		end)

		it("does not extract a crew member who left before the end", function()
			present = { 1 }
			changed:Fire(state("results", 1, true))
			local byUser = {}
			for _, call in calls do
				byUser[call.userId] = call.facts
			end
			expect(byUser[2].extracted).to.equal(false)
			expect(byUser[1].extracted).to.equal(true)
			expect(byUser[1].crewExtracted).to.equal(false)
		end)

		it(
			"pays the clock-out line to the whole crew still in only when the shift ended through the clock-out",
			function()
				changed:Fire(state("results", 1, true))
				expect(calls[1].facts.extracted).to.equal(true)
				expect(calls[2].facts.extracted).to.equal(true)
				changed:Fire(state("lobby", 1, true))
				changed:Fire(state("results", 2, true, "timeout"))
				expect(#calls).to.equal(4)
				expect(calls[3].facts.worked).to.equal(true)
				expect(calls[3].facts.extracted).to.equal(false)
				expect(calls[4].facts.extracted).to.equal(false)
			end
		)

		it("pays no clock-out line when the results state carries no outcome", function()
			local unknown = state("results", 1, true)
			unknown.outcome = nil
			changed:Fire(unknown)
			expect(#calls).to.equal(2)
			expect(calls[1].facts.extracted).to.equal(false)
		end)

		it("stops listening when stopped", function()
			stop()
			changed:Fire(state("results", 3, true))
			expect(#calls).to.equal(0)
		end)

		it("keeps paying the rest of the crew when one award throws", function()
			stop()
			local seen = {}
			begin(function(userId)
				table.insert(seen, userId)
				if userId == 1 then
					error("spec: award failed on purpose")
				end
			end)
			changed:Fire(state("results", 4, true))
			expect(#seen).to.equal(2)
		end)
	end)
end
