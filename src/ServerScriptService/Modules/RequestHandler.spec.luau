--!strict
--[=[
	Unit tests for RequestHandler module.
	Tests rate limiting, validation, audit, and handler wrapping.
	
	Uses a plain table mock for Player — no Roblox Instance needed since
	RequestHandler only reads player.UserId.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

-- Rate limit data is module-level in RequestHandler. We reset between test
-- suites by calling resetRateLimit after each suite.
local RequestHandler = require(ServerScriptService.Modules.RequestHandler)

-- Minimal Player mock — RequestHandler only accesses .UserId
local function mockPlayer(userId: number): Player
	return { UserId = userId } :: any
end

return function()
	-- -------------------------------------------------------------------------
	describe("wrap — basic handler passthrough", function()
		it("should call the handler and return its result", function()
			local called = false
			local wrapped = RequestHandler.wrap({
				name = "TestAction",
				handler = function(_data, _player)
					called = true
					return 42
				end,
			})

			local result = wrapped({}, mockPlayer(1))
			expect(called).to.equal(true)
			expect(result).to.equal(42)
		end)

		it("should pass data and player to the handler", function()
			local capturedData = nil
			local capturedPlayer = nil
			local player = mockPlayer(99)

			local wrapped = RequestHandler.wrap({
				name = "DataCheck",
				handler = function(data, p)
					capturedData = data
					capturedPlayer = p
				end,
			})

			local payload = { amount = 10 }
			wrapped(payload, player)
			expect(capturedData).to.equal(payload)
			expect(capturedPlayer).to.equal(player)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("wrap — validation", function()
		it("should call handler when validation passes", function()
			local handlerCalled = false
			local wrapped = RequestHandler.wrap({
				name = "ValidationPass",
				validate = function(_data, _player)
					return true, nil
				end,
				handler = function(_data, _player)
					handlerCalled = true
				end,
			})
			wrapped({}, mockPlayer(1))
			expect(handlerCalled).to.equal(true)
		end)

		it("should skip handler and return nil when validation fails", function()
			local handlerCalled = false
			local wrapped = RequestHandler.wrap({
				name = "ValidationFail",
				validate = function(_data, _player)
					return false, "bad input"
				end,
				handler = function(_data, _player)
					handlerCalled = true
				end,
			})
			local result = wrapped({}, mockPlayer(1))
			expect(handlerCalled).to.equal(false)
			expect(result).to.equal(nil)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("wrap — rate limiting", function()
		afterEach(function()
			-- Clean up rate limit state so tests don't bleed into each other
			RequestHandler.resetRateLimit(10)
			RequestHandler.resetRateLimit(11)
		end)

		it("should allow requests within limit", function()
			local callCount = 0
			local wrapped = RequestHandler.wrap({
				name = "RLPass",
				rateLimit = { maxRequests = 3, windowSeconds = 60 },
				handler = function(_data, _player)
					callCount += 1
				end,
			})
			local p = mockPlayer(10)
			wrapped({}, p)
			wrapped({}, p)
			wrapped({}, p)
			expect(callCount).to.equal(3)
		end)

		it("should block requests that exceed the limit", function()
			local callCount = 0
			local wrapped = RequestHandler.wrap({
				name = "RLBlock",
				rateLimit = { maxRequests = 2, windowSeconds = 60 },
				handler = function(_data, _player)
					callCount += 1
				end,
			})
			local p = mockPlayer(11)
			wrapped({}, p)
			wrapped({}, p)
			wrapped({}, p) -- Should be rate limited
			expect(callCount).to.equal(2)
		end)

		it("should track limits per userId independently", function()
			local callsP10 = 0
			local callsP11 = 0
			local wrapped = RequestHandler.wrap({
				name = "RLPerUser",
				rateLimit = { maxRequests = 1, windowSeconds = 60 },
				handler = function(_data, player)
					if player.UserId == 10 then
						callsP10 += 1
					else
						callsP11 += 1
					end
				end,
			})
			wrapped({}, mockPlayer(10))
			wrapped({}, mockPlayer(10)) -- Blocked for user 10
			wrapped({}, mockPlayer(11)) -- Fine for user 11
			expect(callsP10).to.equal(1)
			expect(callsP11).to.equal(1)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("resetRateLimit", function()
		it("should allow requests again after reset", function()
			local callCount = 0
			local wrapped = RequestHandler.wrap({
				name = "RLReset",
				rateLimit = { maxRequests = 1, windowSeconds = 60 },
				handler = function(_data, _player)
					callCount += 1
				end,
			})
			local p = mockPlayer(20)
			wrapped({}, p) -- allowed
			wrapped({}, p) -- blocked

			RequestHandler.resetRateLimit(20, "RLReset")

			wrapped({}, p) -- allowed again after reset
			expect(callCount).to.equal(2)
		end)

		it("should clear all actions when no actionName given", function()
			RequestHandler.resetRateLimit(21)
			local status = RequestHandler.getRateLimitStatus(21, "anything")
			expect(status).to.be.ok()
			expect(status and status.requestsInWindow).to.equal(0)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("getRateLimitStatus", function()
		afterEach(function()
			RequestHandler.resetRateLimit(30)
		end)

		it("should return 0 for new userId/action", function()
			local status = RequestHandler.getRateLimitStatus(30, "NewAction")
			expect(status).to.be.ok()
			expect(status and status.requestsInWindow).to.equal(0)
		end)

		it("should reflect requests made within window", function()
			local wrapped = RequestHandler.wrap({
				name = "StatusCheck",
				rateLimit = { maxRequests = 10, windowSeconds = 60 },
				handler = function() end,
			})
			local p = mockPlayer(30)
			wrapped({}, p)
			wrapped({}, p)
			local status = RequestHandler.getRateLimitStatus(30, "StatusCheck")
			expect(status).to.be.ok()
			expect(status and status.requestsInWindow).to.equal(2)
		end)
	end)
end
