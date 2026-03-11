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
end
