--!strict
--[=[
	Unit tests for CurrencyConstants — the single source of truth for currency definitions.
	Constants/validation modules are pure and cheap to cover exhaustively (see docs/testing.md's
	module-level coverage policy), so this exercises every exported helper, including the
	string→union narrowing boundary and the fallbacks.
]=]

local CurrencyConstants = require(script.Parent.CurrencyConstants)

return function()
	describe("CURRENCIES / MAX_CURRENCY", function()
		it("defines gloom and credits with a name and icon", function()
			local gloom = CurrencyConstants.getCurrencyDefinition("gloom")
			local credits = CurrencyConstants.getCurrencyDefinition("credits")
			expect(gloom.name).to.equal("Gloom")
			expect(credits.name).to.equal("Credits")
			expect(type(gloom.icon)).to.equal("string")
			expect(type(credits.icon)).to.equal("string")
		end)

		it("exposes a positive numeric MAX_CURRENCY", function()
			expect(type(CurrencyConstants.MAX_CURRENCY)).to.equal("number")
			expect(CurrencyConstants.MAX_CURRENCY > 0).to.equal(true)
		end)
	end)

	describe("getValidCurrencies", function()
		it("returns one entry per defined currency", function()
			local valid = CurrencyConstants.getValidCurrencies()
			expect(type(valid)).to.equal("table")

			local seen: { [string]: boolean } = {}
			for _, key in valid do
				seen[key] = true
			end
			expect(seen.gloom).to.equal(true)
			expect(seen.credits).to.equal(true)
			expect(#valid).to.equal(2)
		end)
	end)

	describe("isValidCurrencyType", function()
		it("returns true for a defined currency", function()
			expect(CurrencyConstants.isValidCurrencyType("credits")).to.equal(true)
			expect(CurrencyConstants.isValidCurrencyType("gloom")).to.equal(true)
		end)

		it("returns false for an unknown string", function()
			expect(CurrencyConstants.isValidCurrencyType("coins")).to.equal(false)
			expect(CurrencyConstants.isValidCurrencyType("diamonds")).to.equal(false)
			expect(CurrencyConstants.isValidCurrencyType("")).to.equal(false)
		end)
	end)

	describe("toCurrencyType", function()
		it("narrows a valid string to the matching currency key", function()
			expect(CurrencyConstants.toCurrencyType("credits")).to.equal("credits")
		end)

		it("returns nil for an unknown string", function()
			expect(CurrencyConstants.toCurrencyType("coins")).to.equal(nil)
			expect(CurrencyConstants.toCurrencyType("diamonds")).to.equal(nil)
			expect(CurrencyConstants.toCurrencyType("")).to.equal(nil)
		end)
	end)

	describe("validateSync / validateCurrencyTypes", function()
		it("passes for the real definitions (union mirror in sync with CURRENCIES)", function()
			expect(function()
				CurrencyConstants.validateCurrencyTypes()
			end).never.to.throw()
		end)

		it("passes when keys and members match regardless of order", function()
			local ok, message = CurrencyConstants.validateSync({ "tickets", "coins" }, { "coins", "tickets" })
			expect(ok).to.equal(true)
			expect(message).to.equal(nil)
		end)

		it("fails when a union member has no CURRENCIES entry", function()
			-- The drift limitations.md #1 describes: currency removed from the table, left in the union.
			local ok, message = CurrencyConstants.validateSync({ "coins" }, { "coins", "tickets" })
			expect(ok).to.equal(false)
			expect(string.find(message :: string, "tickets", 1, true)).to.be.ok()
		end)

		it("fails when CURRENCIES grew past the union mirror", function()
			local ok, message = CurrencyConstants.validateSync({ "coins", "tickets", "medals" }, { "coins", "tickets" })
			expect(ok).to.equal(false)
			expect(string.find(message :: string, "in sync", 1, true)).to.be.ok()
		end)
	end)

	describe("getCurrencyDefinition", function()
		it("returns the definition for a defined currency", function()
			local def = CurrencyConstants.getCurrencyDefinition("credits")
			expect(def).to.be.ok()
			expect(def.name).to.equal("Credits")
		end)

		it("throws for an undefined currency", function()
			expect(function()
				-- getCurrencyDefinition is typed to CurrencyType; cast to exercise the runtime assert.
				CurrencyConstants.getCurrencyDefinition("diamonds" :: any)
			end).to.throw()
		end)
	end)
end
