local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftPaySystem = require(script.Parent.ShiftPaySystem)

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

-- A review with those counters and crew lines for 1, 2, 3 (`extra` overrides a line's fields by user id).
local function review(cleared, dust, bonus, extra)
	local crew = {}
	for userId = 1, 3 do
		local line = { userId = userId, name = `P{userId}`, banked = 0, piles = 0, salvage = 0, caught = 0, items = 0 }
		for key, value in (extra and extra[userId]) or {} do
			line[key] = value
		end
		table.insert(crew, line)
	end
	return {
		outcome = "clockout",
		quota = 100,
		cleared = cleared,
		dust = dust,
		bonus = bonus,
		salvage = 0,
		piles = 0,
		catches = 0,
		offered = 0,
		rating = "A",
		quotaMet = true,
		crew = crew,
		awards = {},
	}
end

return function()
	describe("ShiftPaySystem", function()
		local changed, present, reviewNow, calls, failFor, stop, refusals, attempts, queue

		beforeEach(function()
			changed = fakeSignal()
			present = {}
			reviewNow = nil
			calls = {}
			failFor = nil
			refusals = 0
			attempts = 0
			queue = {}
			stop = ShiftPaySystem.start({
				changed = changed,
				results = function()
					return reviewNow
				end,
				present = function()
					return present
				end,
			}, function(userId, amounts)
				if userId == failFor then
					error("boom")
				end
				attempts += 1
				if attempts <= refusals then
					return false
				end
				table.insert(calls, { userId = userId, amounts = amounts })
				return true
			end, function(_seconds, fn)
				table.insert(queue, fn)
			end)
		end)

		local function runQueue()
			local batch = queue
			queue = {}
			for _, fn in batch do
				fn()
			end
		end

		afterEach(function()
			stop()
		end)

		it("saves a tenth of the Gloom removed, rounded down", function()
			expect(ShiftConstants.SAVED_GLOOM_PER_CLEARED).to.equal(0.1)
			expect(ShiftPaySystem.amounts(review(340, 260, 420)).gloom).to.equal(34)
			expect(ShiftPaySystem.amounts(review(9, 9, 0)).gloom).to.equal(0)
			expect(ShiftPaySystem.amounts(review(19, 19, 0)).gloom).to.equal(1)
		end)

		it("pays every present crew member the full Credits and saved Gloom when the review opens", function()
			present = { 1, 2 } -- 3 left mid-shift
			reviewNow = review(340, 260, 420)
			changed:Fire(state("results", 1, true, "clockout"))
			expect(#calls).to.equal(2)
			for _, call in calls do
				expect(call.amounts.credits).to.equal(340 * ShiftConstants.CREDITS_PER_GLOOM + 420)
				expect(call.amounts.gloom).to.equal(34)
				expect(call.userId).never.to.equal(3)
			end
		end)

		it("pays a knocked-out member in full", function()
			present = { 1, 2 }
			reviewNow = review(100, 100, 0, { [2] = { caught = 1 } })
			changed:Fire(state("results", 1, false, "clockout"))
			expect(#calls).to.equal(2)
		end)

		it("pays a member once even when listed twice", function()
			present = { 1, 1 }
			reviewNow = review(100, 100, 0)
			changed:Fire(state("results", 1, false, "clockout"))
			expect(#calls).to.equal(1)
		end)

		it("pays on a timeout too", function()
			present = { 1 }
			reviewNow = review(50, 50, 0)
			changed:Fire(state("results", 1, false, "timeout"))
			expect(#calls).to.equal(1)
		end)

		it("pays each shift once, and the next shift again", function()
			present = { 1 }
			reviewNow = review(50, 50, 0)
			changed:Fire(state("results", 1, false, "clockout"))
			changed:Fire(state("results", 1, false, "clockout"))
			expect(#calls).to.equal(1)
			changed:Fire(state("results", 2, false, "clockout"))
			expect(#calls).to.equal(2)
		end)

		it("pays nothing outside the review, without a review, or for an empty shift", function()
			present = { 1 }
			reviewNow = review(50, 50, 0)
			changed:Fire(state("running", 1, false))
			reviewNow = nil
			changed:Fire(state("results", 2, false, "clockout"))
			reviewNow = review(0, 0, 0)
			changed:Fire(state("results", 3, false, "clockout"))
			expect(#calls).to.equal(0)
		end)

		it("keeps paying the rest when one payment throws", function()
			present = { 1, 2 }
			reviewNow = review(50, 50, 0)
			failFor = 1
			changed:Fire(state("results", 1, false, "clockout"))
			expect(#calls).to.equal(1)
			expect(calls[#calls].userId).to.equal(2)
		end)

		it("retries a refused payment until it lands, and pays once", function()
			present = { 1 }
			reviewNow = review(50, 50, 0)
			refusals = 2
			changed:Fire(state("results", 1, false, "clockout"))
			expect(#calls).to.equal(0)
			runQueue()
			expect(#calls).to.equal(0)
			runQueue()
			expect(#calls).to.equal(1)
			expect(#queue).to.equal(0)
			runQueue()
			expect(#calls).to.equal(1)
		end)

		it("gives up after 5 attempts", function()
			present = { 1 }
			reviewNow = review(50, 50, 0)
			refusals = 99
			changed:Fire(state("results", 1, false, "clockout"))
			for _ = 1, 10 do
				runQueue()
			end
			expect(attempts).to.equal(5)
			expect(#calls).to.equal(0)
		end)

		it("stops retrying when the player leaves mid-retry", function()
			present = { 1 }
			reviewNow = review(50, 50, 0)
			refusals = 99
			changed:Fire(state("results", 1, false, "clockout"))
			runQueue()
			expect(attempts).to.equal(2)
			present = {}
			runQueue()
			runQueue()
			expect(attempts).to.equal(2)
			expect(#calls).to.equal(0)
		end)

		it("stops paying once stopped", function()
			stop()
			present = { 1 }
			reviewNow = review(50, 50, 0)
			changed:Fire(state("results", 9, false, "clockout"))
			expect(#calls).to.equal(0)
		end)
	end)
end
