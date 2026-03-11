--!strict
--[=[
	Unit tests for CurrencyUtils module.
	Tests currency validation, amount checking, and formatting.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyUtils = require(script.Parent.CurrencyUtils)
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

return function()
	describe("getCurrencyAmount", function()
		it("should return correct amount for valid currency", function()
			local currency: PlayerDataTypes.Currency = {
				gold = 100,
				gems = 50,
			}

			expect(CurrencyUtils.getCurrencyAmount(currency, "gold")).to.equal(100)
			expect(CurrencyUtils.getCurrencyAmount(currency, "gems")).to.equal(50)
		end)

		it("should return 0 for missing currency type", function()
			local currency: PlayerDataTypes.Currency = {
				gold = 100,
			}

			expect(CurrencyUtils.getCurrencyAmount(currency, "gems")).to.equal(0)
		end)

		it("should return 0 for nil currency table", function()
			expect(CurrencyUtils.getCurrencyAmount(nil, "gold")).to.equal(0)
		end)

		it("should return 0 for invalid currency type", function()
			local currency: PlayerDataTypes.Currency = {
				gold = 100,
			}

			expect(CurrencyUtils.getCurrencyAmount(currency, "invalid")).to.equal(0)
		end)
	end)

	describe("hasEnoughCurrency", function()
		local currency: PlayerDataTypes.Currency

		beforeEach(function()
			currency = {
				gold = 100,
				gems = 50,
			}
		end)

		it("should return true when player has enough", function()
			expect(CurrencyUtils.hasEnoughCurrency(currency, "gold", 50)).to.equal(true)
			expect(CurrencyUtils.hasEnoughCurrency(currency, "gold", 100)).to.equal(true)
		end)

		it("should return false when player lacks funds", function()
			expect(CurrencyUtils.hasEnoughCurrency(currency, "gold", 150)).to.equal(false)
		end)

		it("should return false for nil currency table", function()
			expect(CurrencyUtils.hasEnoughCurrency(nil, "gold", 10)).to.equal(false)
		end)

		it("should return false for missing currency type", function()
			local emptyCurrency: PlayerDataTypes.Currency = {}
			expect(CurrencyUtils.hasEnoughCurrency(emptyCurrency, "gold", 10)).to.equal(false)
		end)

		it("should throw error for non-positive amount", function()
			expect(function()
				CurrencyUtils.hasEnoughCurrency(currency, "gold", 0)
			end).to.throw()

			expect(function()
				CurrencyUtils.hasEnoughCurrency(currency, "gold", -10)
			end).to.throw()
		end)

		it("should throw error for non-number amount", function()
			expect(function()
				CurrencyUtils.hasEnoughCurrency(currency, "gold", "invalid" :: any)
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
			local goldDef = CurrencyConstants.getCurrencyDefinition("gold")
			local gemsDef = CurrencyConstants.getCurrencyDefinition("gems")

			expect(CurrencyUtils.formatCurrency(100, "gold")).to.equal("100 " .. goldDef.icon)
			expect(CurrencyUtils.formatCurrency(50, "gems")).to.equal("50 " .. gemsDef.icon)
		end)

		it("should not append icon for invalid currency type", function()
			expect(CurrencyUtils.formatCurrency(100, "invalid")).to.equal("100")
		end)

		it("should throw error for non-number amount", function()
			expect(function()
				CurrencyUtils.formatCurrency("invalid" :: any)
			end).to.throw()
		end)
	end)
end
