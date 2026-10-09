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
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)

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

		it("handlers sharing a rateLimitKey draw from one bucket", function()
			local calls = 0
			local function make(name)
				return RequestHandler.wrap({
					name = name,
					rateLimitKey = "RLShared",
					rateLimit = { maxRequests = 2, windowSeconds = 60 },
					handler = function()
						calls += 1
					end,
				})
			end
			local deposit, withdraw = make("RLSharedDeposit"), make("RLSharedWithdraw")
			local p = mockPlayer(10)
			deposit({}, p)
			withdraw({}, p)
			withdraw({}, p) -- the third request of ONE budget, whichever packet carries it
			deposit({}, p)
			expect(calls).to.equal(2)
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
			wrapped({ itemId = "wrench" }, mockPlayer(50))
			unsubscribe()

			expect(#captured).to.equal(1)
			expect(string.find(captured[1].message, "AuditedBuy", 1, true)).to.be.ok()
			-- The payload is JSON-serialized into the line, not logged as "table: 0x...".
			expect(string.find(captured[1].message, "wrench", 1, true)).to.be.ok()
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
			expect(status.tokensRemaining).to.equal(nil)
			expect(status.rejected).to.equal(0)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("getRateLimitStatus", function()
		afterEach(function()
			RequestHandler.resetRateLimit(30)
		end)

		it("reports no bucket and no drops for a new userId/action", function()
			local status = RequestHandler.getRateLimitStatus(30, "NewAction")
			expect(status.tokensRemaining).to.equal(nil)
			expect(status.capacity).to.equal(nil)
			expect(status.rejected).to.equal(0)
		end)

		it("reports the tokens left after requests", function()
			local wrapped = RequestHandler.wrap({
				name = "StatusCheck",
				rateLimit = { maxRequests = 10, windowSeconds = 60 },
				handler = function() end,
			})
			local p = mockPlayer(30)
			wrapped({}, p)
			wrapped({}, p)
			local status = RequestHandler.getRateLimitStatus(30, "StatusCheck")
			expect(status.capacity).to.equal(10)
			expect(status.tokensRemaining).to.be.near(8, 0.01)
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

			local spent = {}
			for _, entry in RequestHandler.getAllRateLimitStatus() do
				-- Only assert on the users this test created; the dump is global.
				if (entry.userId == 701 or entry.userId == 702) and entry.action == "DumpA" then
					spent[entry.userId] = (entry.capacity or 0) - (entry.tokensRemaining or 0)
				end
			end

			expect(spent[701]).to.be.near(2, 0.01)
			expect(spent[702]).to.be.near(1, 0.01)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("wrap — token bucket", function()
		afterEach(function()
			RequestHandler.resetRateLimit(60)
		end)

		-- A custom clock makes refill deterministic: maxRequests = 2 per 1 s → bucket 2, refill 2/s.
		local function bucketed(nowRef)
			local calls = 0
			local wrapped = RequestHandler.wrap({
				name = "Bucket",
				rateLimit = { maxRequests = 2, windowSeconds = 1 },
				clock = function()
					return nowRef.now
				end,
				handler = function()
					calls += 1
				end,
			})
			return wrapped, function()
				return calls
			end
		end

		it("holds maxRequests tokens and refills maxRequests / windowSeconds per second", function()
			local nowRef = { now = 0 }
			local wrapped, calls = bucketed(nowRef)
			local p = mockPlayer(60)
			for _ = 1, 3 do
				wrapped({}, p)
			end
			expect(calls()).to.equal(2)
			nowRef.now = 0.5 -- one token back
			wrapped({}, p)
			wrapped({}, p)
			expect(calls()).to.equal(3)
			nowRef.now = 100 -- refill caps at the bucket size
			for _ = 1, 3 do
				wrapped({}, p)
			end
			expect(calls()).to.equal(5)
		end)

		it("never refills on a clock that moves backwards", function()
			local nowRef = { now = 5 }
			local wrapped, calls = bucketed(nowRef)
			local p = mockPlayer(60)
			wrapped({}, p)
			wrapped({}, p)
			nowRef.now = 4
			wrapped({}, p)
			nowRef.now = 4.9 -- still behind the last clock reading (5): no refill
			wrapped({}, p)
			expect(calls()).to.equal(2)
			nowRef.now = 5.5
			wrapped({}, p)
			expect(calls()).to.equal(3)
		end)

		it("refills nothing on a NaN clock", function()
			local nowRef = { now = 1 }
			local wrapped, calls = bucketed(nowRef)
			local p = mockPlayer(60)
			wrapped({}, p)
			wrapped({}, p)
			nowRef.now = 0 / 0
			wrapped({}, p)
			expect(calls()).to.equal(2)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("wrap — order of validate and rate limit", function()
		afterEach(function()
			RequestHandler.resetRateLimit(61)
		end)

		it("validates before a custom clock reads the packet, and an invalid packet costs no token", function()
			local order = {}
			local wrapped = RequestHandler.wrap({
				name = "ClockOrder",
				rateLimit = { maxRequests = 3, windowSeconds = 1 },
				onReject = "count",
				validate = function(data)
					table.insert(order, "validate")
					return data.ok == true, "bad"
				end,
				clock = function()
					table.insert(order, "clock")
					return 0
				end,
				handler = function() end,
			})
			wrapped({ ok = false }, mockPlayer(61))
			expect(table.concat(order, ",")).to.equal("validate")
			expect(RequestHandler.getRateLimitStatus(61, "ClockOrder").tokensRemaining).to.equal(nil)
			wrapped({ ok = true }, mockPlayer(61))
			expect(table.concat(order, ",")).to.equal("validate,validate,clock")
			expect(RequestHandler.getRateLimitStatus(61, "ClockOrder").tokensRemaining).to.be.near(2, 1e-9)
		end)

		it("without a clock, a rate-limited request never reaches validate", function()
			local validations = 0
			local wrapped = RequestHandler.wrap({
				name = "PlainOrder",
				rateLimit = { maxRequests = 1, windowSeconds = 60 },
				onReject = "count",
				validate = function()
					validations += 1
					return true
				end,
				handler = function() end,
			})
			wrapped({}, mockPlayer(61))
			wrapped({}, mockPlayer(61))
			expect(validations).to.equal(1)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("wrap — decode once", function()
		it("passes the validator's third return to the handler", function()
			local seen = nil
			local wrapped = RequestHandler.wrap({
				name = "Decode",
				validate = function(data)
					return true, nil, { doubled = data.value * 2 }
				end,
				handler = function(_data, _player, decoded)
					seen = decoded
				end,
			})
			wrapped({ value = 21 }, mockPlayer(62))
			expect(seen).to.be.ok()
			expect(seen.doubled).to.equal(42)
		end)

		it("leaves the third argument nil for a two-return validator", function()
			-- Captured into outer locals and asserted after the call: RequestHandler swallows handler errors,
			-- so an expect() inside the handler could never fail the test.
			local argumentCount = -1
			local capturedDecoded = "unset"
			local wrapped = RequestHandler.wrap({
				name = "TwoReturn",
				validate = function()
					return true, nil
				end,
				handler = function(...)
					argumentCount = select("#", ...)
					local _, _, decoded = ...
					capturedDecoded = decoded
				end,
			})
			wrapped({}, mockPlayer(62))
			expect(argumentCount).to.equal(3)
			expect(capturedDecoded).to.equal(nil)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("wrap — onReject", function()
		afterEach(function()
			RequestHandler.resetRateLimit(63)
		end)

		local function countWarnings(fn)
			local warnings = 0
			local unsubscribe = Logger.subscribe(function(entry)
				if entry.level == "WARN" then
					warnings += 1
				end
			end)
			fn()
			unsubscribe()
			return warnings
		end

		it("count mode counts drops without logging a warning", function()
			local wrapped = RequestHandler.wrap({
				name = "Counted",
				rateLimit = { maxRequests = 1, windowSeconds = 60 },
				onReject = "count",
				validate = function(data)
					return data.ok == true, "bad"
				end,
				handler = function() end,
			})
			local warnings = countWarnings(function()
				wrapped({ ok = true }, mockPlayer(63))
				wrapped({ ok = true }, mockPlayer(63)) -- rate limited
				wrapped({ ok = false }, mockPlayer(63)) -- rate limited before validation (no clock)
			end)
			expect(warnings).to.equal(0)
			expect(RequestHandler.getRateLimitStatus(63, "Counted").rejected).to.equal(2)
		end)

		it("warn mode (the default) logs a warning per drop", function()
			local prev = Logger.getGlobalLevel()
			Logger.setGlobalLevel("WARN")
			local wrapped = RequestHandler.wrap({
				name = "Warned",
				validate = function()
					return false, "bad"
				end,
				handler = function() end,
			})
			local warnings = countWarnings(function()
				wrapped({}, mockPlayer(63))
				wrapped({}, mockPlayer(63))
			end)
			Logger.setGlobalLevel(prev)
			expect(warnings).to.equal(2)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("wrap — per-call cost", function()
		afterEach(function()
			RequestHandler.resetRateLimit(64)
		end)

		it("allocates nothing per accepted call", function()
			local wrapped = RequestHandler.wrap({
				name = "Cheap",
				rateLimit = { maxRequests = 100000, windowSeconds = 1 },
				validate = function()
					return true
				end,
				handler = function() end,
			})
			local payload = {}
			local player = mockPlayer(64)
			for _ = 1, 100 do
				wrapped(payload, player) -- warm: the (user, action) bucket is created once
			end
			local before = collectgarbage("count")
			for _ = 1, 2000 do
				wrapped(payload, player)
			end
			local grownKb = collectgarbage("count") - before
			-- A closure or table per call would be >= 64 KB here.
			expect(grownKb < 16).to.equal(true)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- #32: a custom clock reads packet bytes; one that throws must reject the packet, not escape the listener.
	describe("wrap — a throwing custom clock", function()
		afterEach(function()
			RequestHandler.resetRateLimit(64)
		end)

		it("rejects the packet, counts it, and never calls the handler", function()
			local handled = 0
			local wrapped = RequestHandler.wrap({
				name = "ClockThrows",
				rateLimit = { maxRequests = 3, windowSeconds = 1 },
				onReject = "count",
				validate = function()
					return true
				end,
				clock = function()
					error("clock exploded")
				end,
				handler = function()
					handled += 1
				end,
			})
			local ok = pcall(wrapped, {}, mockPlayer(64))
			expect(ok).to.equal(true)
			expect(handled).to.equal(0)
			expect(RequestHandler.getRateLimitStatus(64, "ClockThrows").rejected).to.equal(1)
		end)

		it("still accepts the next packet when the clock recovers", function()
			local handled = 0
			local broken = true
			local wrapped = RequestHandler.wrap({
				name = "ClockRecovers",
				rateLimit = { maxRequests = 3, windowSeconds = 1 },
				onReject = "count",
				validate = function()
					return true
				end,
				clock = function()
					if broken then
						error("clock exploded")
					end
					return 1
				end,
				handler = function()
					handled += 1
				end,
			})
			wrapped({}, mockPlayer(64))
			broken = false
			wrapped({}, mockPlayer(64))
			expect(handled).to.equal(1)
			expect(RequestHandler.getRateLimitStatus(64, "ClockRecovers").rejected).to.equal(1)
		end)
	end)
end
