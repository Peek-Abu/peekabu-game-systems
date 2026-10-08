--!strict
--[=[
	Unit tests for CurrencyServiceClient — a thin read-facade over StateSyncClientStore.currency.
	Seeds the atom directly and asserts the accessors read it. There is no listener/signal to
	exercise anymore; replication is covered by the StateSync/StateSyncClientStore specs.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyServiceClient = require(ReplicatedStorage.Client.Features.Currency.CurrencyServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

return function()
	describe("CurrencyServiceClient", function()
		afterEach(function()
			StateSyncClientStore.currency(nil) -- restore the loading state for other specs
		end)

		describe("getCurrency", function()
			it("returns the currency snapshot from the store", function()
				StateSyncClientStore.currency({ coins = 100 })
				local c = CurrencyServiceClient:getCurrency()
				expect(c).to.be.ok()
				expect(c and c.coins).to.equal(100)
			end)

			it("returns nil before the first sync", function()
				StateSyncClientStore.currency(nil)
				expect(CurrencyServiceClient:getCurrency()).to.equal(nil)
			end)
		end)

		describe("getCurrencyAmount", function()
			it("returns the amount for a valid currency", function()
				StateSyncClientStore.currency({ coins = 100 })
				expect(CurrencyServiceClient:getCurrencyAmount("coins")).to.equal(100)
			end)

			it("returns 0 before the first sync", function()
				StateSyncClientStore.currency(nil)
				expect(CurrencyServiceClient:getCurrencyAmount("coins")).to.equal(0)
			end)

			it("throws for an invalid currency type", function()
				expect(function()
					CurrencyServiceClient:getCurrencyAmount("diamonds")
				end).to.throw()
			end)
		end)

		describe("hasCurrency", function()
			beforeEach(function()
				StateSyncClientStore.currency({ coins = 100 })
			end)

			it("returns true when the player has enough", function()
				expect(CurrencyServiceClient:hasCurrency("coins", 50)).to.equal(true)
				expect(CurrencyServiceClient:hasCurrency("coins", 100)).to.equal(true)
			end)

			it("returns false when the player has too little", function()
				expect(CurrencyServiceClient:hasCurrency("coins", 500)).to.equal(false)
			end)

			it("throws for a non-positive amount", function()
				expect(function()
					CurrencyServiceClient:hasCurrency("coins", 0)
				end).to.throw()
			end)
		end)

		describe("formatCurrency", function()
			it("formats large numbers with commas", function()
				expect(CurrencyServiceClient:formatCurrency(1000)).to.equal("1,000")
			end)

			it("throws for a non-number amount", function()
				expect(function()
					CurrencyServiceClient:formatCurrency("lots" :: any)
				end).to.throw()
			end)
		end)
	end)
end
