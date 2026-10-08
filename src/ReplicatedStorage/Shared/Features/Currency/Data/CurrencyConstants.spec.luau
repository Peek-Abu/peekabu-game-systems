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
		it("defines jaku with a name and icon", function()
			expect(CurrencyConstants.CURRENCIES.jaku).to.be.ok()
			expect(CurrencyConstants.CURRENCIES.jaku.name).to.equal("Jaku")
			expect(type(CurrencyConstants.CURRENCIES.jaku.icon)).to.equal("string")
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
			expect(seen.jaku).to.equal(true)
			expect(#valid).to.equal(1)
		end)
	end)

	describe("isValidCurrencyType", function()
		it("returns true for a defined currency", function()
			expect(CurrencyConstants.isValidCurrencyType("jaku")).to.equal(true)
		end)

		it("returns false for an unknown string", function()
			expect(CurrencyConstants.isValidCurrencyType("diamonds")).to.equal(false)
			expect(CurrencyConstants.isValidCurrencyType("")).to.equal(false)
		end)
	end)

	describe("toCurrencyType", function()
		it("narrows a valid string to the matching currency key", function()
			expect(CurrencyConstants.toCurrencyType("jaku")).to.equal("jaku")
		end)

		it("returns nil for an unknown string", function()
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
			local ok, message = CurrencyConstants.validateSync({ "tickets", "jaku" }, { "jaku", "tickets" })
			expect(ok).to.equal(true)
			expect(message).to.equal(nil)
		end)

		it("fails when a union member has no CURRENCIES entry", function()
			-- The drift limitations.md #1 describes: currency removed from the table, left in the union.
			local ok, message = CurrencyConstants.validateSync({ "jaku" }, { "jaku", "tickets" })
			expect(ok).to.equal(false)
			expect(string.find(message :: string, "tickets", 1, true)).to.be.ok()
		end)

		it("fails when CURRENCIES grew past the union mirror", function()
			local ok, message = CurrencyConstants.validateSync({ "jaku", "tickets", "medals" }, { "jaku", "tickets" })
			expect(ok).to.equal(false)
			expect(string.find(message :: string, "in sync", 1, true)).to.be.ok()
		end)
	end)

	describe("getCurrencyDefinition", function()
		it("returns the definition for a defined currency", function()
			local def = CurrencyConstants.getCurrencyDefinition("jaku")
			expect(def).to.be.ok()
			expect(def.name).to.equal("Jaku")
		end)

		it("throws for an undefined currency", function()
			expect(function()
				-- getCurrencyDefinition is typed to CurrencyType; cast to exercise the runtime assert.
				CurrencyConstants.getCurrencyDefinition("diamonds" :: any)
			end).to.throw()
		end)
	end)
end
