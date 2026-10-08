--!strict
--[=[
	Unit tests for CurrencyUtils module.
	Tests currency validation, amount checking, and formatting.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyUtils = require(script.Parent.CurrencyUtils)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

return function()
	describe("validateCurrency", function()
		it("accepts a well-formed balance", function()
			local ok = CurrencyUtils.validateCurrency({ jaku = 100 })
			expect(ok).to.equal(true)
		end)

		it("rejects an unregistered currency key", function()
			local ok, reason = CurrencyUtils.validateCurrency({ dogecoin = 5 } :: any)
			expect(ok).to.equal(false)
			expect((reason :: string):find("not a registered currency", 1, true)).to.be.ok()
		end)

		it("rejects a negative balance", function()
			local ok = CurrencyUtils.validateCurrency({ jaku = -1 })
			expect(ok).to.equal(false)
		end)

		it("rejects a balance above MAX_CURRENCY", function()
			local ok = CurrencyUtils.validateCurrency({ jaku = CurrencyConstants.MAX_CURRENCY + 1 })
			expect(ok).to.equal(false)
		end)

		it("returns a rejection (does not throw) for a non-table value", function()
			-- As a slice validator it runs in a no-yield region; a malformed value must not throw.
			local ok = CurrencyUtils.validateCurrency("nope" :: any)
			expect(ok).to.equal(false)
		end)
	end)

	describe("getCurrencyAmount", function()
		it("should return correct amount for valid currency", function()
			local currency: PlayerDataTypes.Currency = {
				jaku = 100,
			}

			expect(CurrencyUtils.getCurrencyAmount(currency, "jaku")).to.equal(100)
		end)

		it("should return 0 for missing currency type", function()
			-- A currency table that does not carry the requested key at all (jaku unset).
			local currency: PlayerDataTypes.Currency = {}

			expect(CurrencyUtils.getCurrencyAmount(currency, "jaku")).to.equal(0)
		end)

		it("should return 0 for nil currency table", function()
			expect(CurrencyUtils.getCurrencyAmount(nil, "jaku")).to.equal(0)
		end)

		it("should return 0 for invalid currency type", function()
			local currency: PlayerDataTypes.Currency = {
				jaku = 100,
			}

			-- getCurrencyAmount is typed to CurrencyType; cast an invalid value to exercise the
			-- runtime fallback (an absent key returns 0).
			expect(CurrencyUtils.getCurrencyAmount(currency, "invalid" :: any)).to.equal(0)
		end)
	end)

	describe("hasEnoughCurrency", function()
		local currency: PlayerDataTypes.Currency

		beforeEach(function()
			currency = {
				jaku = 100,
			}
		end)

		it("should return true when player has enough", function()
			expect(CurrencyUtils.hasEnoughCurrency(currency, "jaku", 50)).to.equal(true)
			expect(CurrencyUtils.hasEnoughCurrency(currency, "jaku", 100)).to.equal(true)
		end)

		it("should return false when player lacks funds", function()
			expect(CurrencyUtils.hasEnoughCurrency(currency, "jaku", 150)).to.equal(false)
		end)

		it("should return false for nil currency table", function()
			expect(CurrencyUtils.hasEnoughCurrency(nil, "jaku", 10)).to.equal(false)
		end)

		it("should return false for missing currency type", function()
			local emptyCurrency: PlayerDataTypes.Currency = {}
			expect(CurrencyUtils.hasEnoughCurrency(emptyCurrency, "jaku", 10)).to.equal(false)
		end)

		it("should throw error for non-positive amount", function()
			expect(function()
				CurrencyUtils.hasEnoughCurrency(currency, "jaku", 0)
			end).to.throw()

			expect(function()
				CurrencyUtils.hasEnoughCurrency(currency, "jaku", -10)
			end).to.throw()
		end)

		it("should throw error for non-number amount", function()
			expect(function()
				CurrencyUtils.hasEnoughCurrency(currency, "jaku", "invalid" :: any)
			end).to.throw()
		end)
	end)

	describe("formatCurrency", function()
		it("should format amounts without commas for values < 1000", function()
			expect(CurrencyUtils.formatCurrency(0)).to.equal("0")
			expect(CurrencyUtils.formatCurrency(100)).to.equal("100")
			expect(CurrencyUtils.formatCurrency(999)).to.equal("999")
		end)

		it("should format amounts with commas for values >= 1000", function()
			expect(CurrencyUtils.formatCurrency(1000)).to.equal("1,000")
			expect(CurrencyUtils.formatCurrency(10000)).to.equal("10,000")
			expect(CurrencyUtils.formatCurrency(1000000)).to.equal("1,000,000")
		end)

		it("should floor decimal amounts", function()
			expect(CurrencyUtils.formatCurrency(100.7)).to.equal("100")
			expect(CurrencyUtils.formatCurrency(999.99)).to.equal("999")
		end)

		it("should append currency icon when type is provided", function()
			local jakuDef = CurrencyConstants.getCurrencyDefinition("jaku")

			expect(CurrencyUtils.formatCurrency(100, "jaku")).to.equal("100 " .. jakuDef.icon)
		end)

		it("should not append icon for invalid currency type", function()
			-- formatCurrency is typed to CurrencyType?; cast to exercise the runtime fallback.
			expect(CurrencyUtils.formatCurrency(100, "invalid" :: any)).to.equal("100")
		end)

		it("should throw error for non-number amount", function()
			expect(function()
				CurrencyUtils.formatCurrency("invalid" :: any)
			end).to.throw()
		end)
	end)
end
