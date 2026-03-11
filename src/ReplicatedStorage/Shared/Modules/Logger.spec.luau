--!strict
--[=[
	Unit tests for Logger module.
	Tests log level filtering, context prefixes, and message formatting.
]=]
local Logger = require(script.Parent.Logger)

return function()
	local originalGlobalLevel: string

	beforeEach(function()
		originalGlobalLevel = Logger.getGlobalLevel()
		Logger.setGlobalLevel("DEBUG")
	end)

	afterEach(function()
		Logger.setGlobalLevel(originalGlobalLevel :: any)
	end)

	describe("setGlobalLevel", function()
		it("should set global log level", function()
			Logger.setGlobalLevel("WARN")
			expect(Logger.getGlobalLevel()).to.equal("WARN")
		end)

		it("should throw error for invalid log level", function()
			expect(function()
				Logger.setGlobalLevel("INVALID" :: any)
			end).to.throw()
		end)
	end)

	describe("getGlobalLevel", function()
		it("should return current global log level", function()
			Logger.setGlobalLevel("ERROR")
			expect(Logger.getGlobalLevel()).to.equal("ERROR")
		end)
	end)

	describe("new", function()
		it("should create logger without context", function()
			local log = Logger.new()
			expect(log).to.be.ok()
			expect(log.debug).to.be.ok()
			expect(log.info).to.be.ok()
			expect(log.warn).to.be.ok()
			expect(log.error).to.be.ok()
		end)

		it("should create logger with context", function()
			local log = Logger.new("TestService")
			expect(log).to.be.ok()
		end)
	end)

	describe("instance log levels", function()
		it("should allow instance-specific log level", function()
			Logger.setGlobalLevel("DEBUG")
			local log = Logger.new("Test")

			log:setLevel("ERROR")
			expect(log.setLevel).to.be.ok()
		end)

		it("should throw error for invalid instance log level", function()
			local log = Logger.new("Test")
			expect(function()
				log:setLevel("INVALID" :: any)
			end).to.throw()
		end)
	end)

	describe("log methods", function()
		it("should have all log level methods", function()
			local log = Logger.new("Test")

			expect(typeof(log.debug)).to.equal("function")
			expect(typeof(log.info)).to.equal("function")
			expect(typeof(log.warn)).to.equal("function")
			expect(typeof(log.error)).to.equal("function")
		end)

		it("should accept multiple arguments", function()
			local log = Logger.new("Test")

			expect(function()
				log:debug("arg1", "arg2", "arg3")
				log:info("single arg")
				log:warn("number:", 123)
				log:error("table:", { key = "value" })
			end).never.to.throw()
		end)
	end)

	describe("log level hierarchy", function()
		it("should filter logs based on level", function()
			local log = Logger.new("Test")
			log:setLevel("WARN")

			expect(function()
				log:debug("This is debug")
				log:info("This is info")
				log:warn("This is warn")
				log:error("This is error")
			end).never.to.throw()
		end)

		it("should show all logs at DEBUG level", function()
			local log = Logger.new("Test")
			log:setLevel("DEBUG")

			expect(function()
				log:debug("Debug message")
				log:info("Info message")
				log:warn("Warn message")
				log:error("Error message")
			end).never.to.throw()
		end)

		it("should show no logs at NONE level", function()
			local log = Logger.new("Test")
			log:setLevel("NONE")

			expect(function()
				log:debug("Debug message")
				log:info("Info message")
				log:warn("Warn message")
				log:error("Error message")
			end).never.to.throw()
		end)
	end)

	describe("context prefixes", function()
		it("should create logger with context prefix", function()
			local log = Logger.new("MyService")
			expect(log).to.be.ok()
		end)

		it("should create logger without context prefix", function()
			local log = Logger.new()
			expect(log).to.be.ok()
		end)
	end)

	describe("history ring buffer", function()
		beforeEach(function()
			Logger.setGlobalLevel("DEBUG")
			Logger.clearHistory()
		end)

		it("should record emitted lines with structured fields", function()
			local log = Logger.new("BufferTest")
			log:info("hello", 42)

			local history = Logger.getHistory()
			expect(#history).to.equal(1)
			expect(history[1].level).to.equal("INFO")
			expect(history[1].context).to.equal("BufferTest")
			expect(history[1].message).to.equal("hello 42")
			expect(typeof(history[1].clock)).to.equal("number")
		end)

		it("should record blank context for a logger without one", function()
			local log = Logger.new()
			log:warn("no context")

			local history = Logger.getHistory()
			expect(history[1].context).to.equal("")
		end)

		it("should NOT record lines filtered out by level", function()
			local log = Logger.new("Filtered")
			log:setLevel("ERROR")
			log:debug("dropped")
			log:info("dropped")
			log:error("kept")

			local history = Logger.getHistory()
			expect(#history).to.equal(1)
			expect(history[1].message).to.equal("kept")
		end)

		it("should return lines in chronological order", function()
			local log = Logger.new("Order")
			log:info("first")
			log:info("second")
			log:info("third")

			local history = Logger.getHistory()
			expect(history[1].message).to.equal("first")
			expect(history[2].message).to.equal("second")
			expect(history[3].message).to.equal("third")
		end)

		it("should notify and unsubscribe subscribers", function()
			local received = {}
			local unsubscribe = Logger.subscribe(function(entry)
				table.insert(received, entry.message)
			end)

			local log = Logger.new("Sub")
			log:info("one")
			unsubscribe()
			log:info("two")

			expect(#received).to.equal(1)
			expect(received[1]).to.equal("one")
		end)

		it("should record audit entries (the audit trail's in-memory sink)", function()
			local log = Logger.new("AuditTest")
			log:audit("userId=1", "MUTATE_SUCCESS", "path=currency")

			local history = Logger.getHistory()
			expect(#history).to.equal(1)
			expect(history[1].level).to.equal("AUDIT")
			expect(history[1].message).to.equal("userId=1 MUTATE_SUCCESS path=currency")
		end)

		it("should keep audit entries at the AUDIT threshold while dropping lower levels", function()
			-- AUDIT deliberately ranks above ERROR so a deployment can run audit-only (see the
			-- console-policy comment in Logger.luau).
			local log = Logger.new("AuditOnly")
			log:setLevel("AUDIT")
			log:error("dropped")
			log:audit("kept")

			local history = Logger.getHistory()
			expect(#history).to.equal(1)
			expect(history[1].level).to.equal("AUDIT")
		end)

		it("should drop audit entries at the NONE threshold", function()
			local log = Logger.new("AuditSilenced")
			log:setLevel("NONE")
			log:audit("dropped")

			expect(#Logger.getHistory()).to.equal(0)
		end)

		it("should clear history", function()
			Logger.new("Clear"):info("x")
			expect(#Logger.getHistory()).to.equal(1)
			Logger.clearHistory()
			expect(#Logger.getHistory()).to.equal(0)
		end)
	end)

	describe("getLevels", function()
		it("should return the emittable levels in severity order", function()
			local levels = Logger.getLevels()
			expect(levels[1]).to.equal("DEBUG")
			expect(levels[2]).to.equal("INFO")
			expect(levels[3]).to.equal("WARN")
			expect(levels[4]).to.equal("ERROR")
			expect(levels[5]).to.equal("AUDIT")
		end)

		it("should exclude the NONE sentinel", function()
			for _, level in Logger.getLevels() do
				expect(level).never.to.equal("NONE")
			end
		end)

		it("should return a fresh copy each call", function()
			local first = Logger.getLevels()
			table.clear(first)
			expect(#Logger.getLevels()).to.equal(5)
		end)
	end)
end
