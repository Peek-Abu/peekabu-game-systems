local EventPaySystem = require(script.Parent.EventPaySystem)

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

return function()
	local EVENT = { id = "harvest" }
	local changed, results, present, training, live, paid, payResult, waits, stop

	local function source()
		return {
			changed = changed,
			results = function()
				return results
			end,
			present = function()
				return present
			end,
			training = function()
				return training
			end,
			live = function()
				return live
			end,
		}
	end

	local function pay(userId, event, review, crew)
		table.insert(paid, { userId = userId, event = event, review = review, crew = crew })
		return payResult(userId)
	end

	-- Runs scheduled retries at once (and records the delay).
	local function wait(seconds, fn)
		table.insert(waits, seconds)
		fn()
	end

	beforeEach(function()
		changed = fakeSignal()
		results = { quotaMet = true }
		present = { 1, 2 }
		training = false
		live = EVENT
		paid = {}
		waits = {}
		payResult = function()
			return true
		end
		-- The spec runs each payment inline (the real system spawns them so a friend check may yield).
		stop = EventPaySystem.start(source(), pay, wait, function(fn)
			fn()
		end)
	end)

	afterEach(function()
		stop()
	end)

	it("pays every crew member once when the review opens, while an event is live", function()
		changed:Fire({ phase = "results", shift = 1 })
		changed:Fire({ phase = "results", shift = 1 })
		expect(#paid).to.equal(2)
		expect(paid[1].event).to.equal(EVENT)
		expect(paid[1].review).to.equal(results)
		expect(table.concat(paid[1].crew, ",")).to.equal("1,2")
	end)

	it("pays the next shift again", function()
		changed:Fire({ phase = "results", shift = 1 })
		changed:Fire({ phase = "results", shift = 2 })
		expect(#paid).to.equal(4)
	end)

	it("pays nothing outside the review, with no event, or in training", function()
		changed:Fire({ phase = "running", shift = 1 })
		expect(#paid).to.equal(0)
		live = nil
		changed:Fire({ phase = "results", shift = 1 })
		expect(#paid).to.equal(0)
		live = EVENT
		training = true
		changed:Fire({ phase = "results", shift = 2 })
		expect(#paid).to.equal(0)
	end)

	it("pays a player listed twice only once", function()
		present = { 1, 1 }
		changed:Fire({ phase = "results", shift = 1 })
		expect(#paid).to.equal(1)
	end)

	it("retries a refused payment while the player is still here, up to 5 tries", function()
		local tries = 0
		payResult = function()
			tries += 1
			return tries >= 3
		end
		present = { 1 }
		changed:Fire({ phase = "results", shift = 1 })
		expect(tries).to.equal(3)
		expect(waits[1]).to.equal(1)

		tries = -100
		changed:Fire({ phase = "results", shift = 2 })
		expect(tries).to.equal(-95)
	end)

	it("stops retrying once the player leaves, and keeps paying others after a throw", function()
		payResult = function(userId)
			if userId == 1 then
				present = { 2 }
				error("boom")
			end
			return true
		end
		changed:Fire({ phase = "results", shift = 1 })
		local ones, twos = 0, 0
		for _, entry in paid do
			if entry.userId == 1 then
				ones += 1
			else
				twos += 1
			end
		end
		expect(ones).to.equal(1)
		expect(twos).to.equal(1)
	end)
end
