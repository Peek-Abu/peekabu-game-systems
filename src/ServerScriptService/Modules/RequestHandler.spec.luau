--!strict
--[=[
	Unit tests for RequestHandler module.
	Tests rate limiting, validation, audit, and handler wrapping.
	
	Uses a plain table mock for Player — no Roblox Instance needed since
	RequestHandler only reads player.UserId.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Rate limit data is module-level in RequestHandler. We reset between test
-- suites by calling resetRateLimit after each suite.
local RequestHandler = require(ServerScriptService.Modules.RequestHandler)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

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
	describe("wrap — input validation", function()
		it("throws when name is missing", function()
			expect(function()
				RequestHandler.wrap({ handler = function() end } :: any)
			end).to.throw()
		end)

		it("throws when handler is not a function", function()
			expect(function()
				RequestHandler.wrap({ name = "BadHandler", handler = 5 :: any })
			end).to.throw()
		end)

		it("throws when validate is not a function", function()
			expect(function()
				RequestHandler.wrap({ name = "BadValidate", handler = function() end, validate = 7 :: any })
			end).to.throw()
		end)

		it("throws for a non-positive rate limit", function()
			expect(function()
				RequestHandler.wrap({
					name = "BadRate",
					handler = function() end,
					rateLimit = { maxRequests = 0, windowSeconds = 10 },
				})
			end).to.throw()
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
	describe("wrap — handler error isolation", function()
		local prevLogLevel: Logger.LogLevel

		beforeEach(function()
			-- Silence the log:error noise the isolation path emits by design.
			prevLogLevel = Logger.getGlobalLevel()
			Logger.setGlobalLevel("NONE")
		end)

		afterEach(function()
			Logger.setGlobalLevel(prevLogLevel)
		end)

		it("returns nil instead of propagating when the handler throws", function()
			local wrapped = RequestHandler.wrap({
				name = "Boom",
				handler = function(_data, _player)
					error("boom")
				end,
			})
			local result: any = "sentinel"
			expect(function()
				result = wrapped({}, mockPlayer(40))
			end).never.to.throw()
			expect(result).to.equal(nil)
		end)

		it("keeps serving subsequent requests after a handler error", function()
			local calls = 0
			local wrapped = RequestHandler.wrap({
				name = "BoomOnce",
				handler = function(_data, _player)
					calls += 1
					if calls == 1 then
						error("boom")
					end
					return 7
				end,
			})
			wrapped({}, mockPlayer(41)) -- errors, isolated
			local result = wrapped({}, mockPlayer(41))
			expect(calls).to.equal(2)
			expect(result).to.equal(7)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("wrap — audit logging", function()
		local prevLogLevel: Logger.LogLevel

		beforeEach(function()
			-- AUDIT is the highest emitted level, so this records audit lines while
			-- suppressing every other level's console noise.
			prevLogLevel = Logger.getGlobalLevel()
			Logger.setGlobalLevel("AUDIT")
		end)

		afterEach(function()
			Logger.setGlobalLevel(prevLogLevel)
		end)

		it("records an AUDIT entry carrying the action name and serialized payload", function()
			local captured: { Logger.LogEntry } = {}
			local unsubscribe = Logger.subscribe(function(entry)
				if entry.level == "AUDIT" then
					table.insert(captured, entry)
				end
			end)

			local wrapped = RequestHandler.wrap({
				name = "AuditedBuy",
				audit = true,
				handler = function(_data, _player) end,
			})
			wrapped({ itemId = "iron-sword" }, mockPlayer(50))
			unsubscribe()

			expect(#captured).to.equal(1)
			expect(string.find(captured[1].message, "AuditedBuy", 1, true)).to.be.ok()
			-- The payload is JSON-serialized into the line, not logged as "table: 0x...".
			expect(string.find(captured[1].message, "iron-sword", 1, true)).to.be.ok()
		end)

		it("records no AUDIT entry when audit is not enabled", function()
			local auditCount = 0
			local unsubscribe = Logger.subscribe(function(entry)
				if entry.level == "AUDIT" then
					auditCount += 1
				end
			end)

			local wrapped = RequestHandler.wrap({
				name = "Unaudited",
				handler = function(_data, _player) end,
			})
			wrapped({}, mockPlayer(51))
			unsubscribe()

			expect(auditCount).to.equal(0)
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

		it("counts only requests within the given window when windowSeconds is passed", function()
			local wrapped = RequestHandler.wrap({
				name = "WindowCheck",
				rateLimit = { maxRequests = 10, windowSeconds = 60 },
				handler = function() end,
			})
			local p = mockPlayer(30)
			wrapped({}, p)
			wrapped({}, p)
			-- Both timestamps are fresh, so a 60s window still sees both.
			expect(RequestHandler.getRateLimitStatus(30, "WindowCheck", 60).requestsInWindow).to.equal(2)
			-- A zero-length window excludes everything recorded before "now".
			expect(RequestHandler.getRateLimitStatus(30, "WindowCheck", 0).requestsInWindow).to.equal(0)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("getAllRateLimitStatus", function()
		afterEach(function()
			RequestHandler.resetRateLimit(701)
			RequestHandler.resetRateLimit(702)
		end)

		it("returns an entry for every tracked (user, action) pair", function()
			local wrapped = RequestHandler.wrap({
				name = "DumpA",
				rateLimit = { maxRequests = 10, windowSeconds = 60 },
				handler = function() end,
			})
			wrapped({}, mockPlayer(701))
			wrapped({}, mockPlayer(701))
			wrapped({}, mockPlayer(702))

			local found = {}
			for _, entry in RequestHandler.getAllRateLimitStatus() do
				-- Only assert on the users this test created; the dump is global.
				if entry.userId == 701 and entry.action == "DumpA" then
					found[701] = entry.requestsInWindow
				elseif entry.userId == 702 and entry.action == "DumpA" then
					found[702] = entry.requestsInWindow
				end
			end

			expect(found[701]).to.equal(2)
			expect(found[702]).to.equal(1)
		end)
	end)
end
