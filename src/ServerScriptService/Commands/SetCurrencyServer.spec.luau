--!strict
--[=[
	Unit tests for the SetCurrency Cmdr command implementation.

	Mock strategy: patch CurrencyService.setCurrency plus getCurrency (the read-back the command uses
	to report on observed state) inside beforeAll/afterAll (see AddCurrencyServer.spec for the
	rationale). A shared `stored` table stands in for the player's currency (nil = profile not loaded).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local CurrencyService = require(ServerScriptService.Services.CurrencyService.CurrencyServiceServer)
local setCurrencyCommand = require(ServerScriptService.Commands.SetCurrencyServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("SetCurrencyServer", function()
		local _origSetCurrency
		local _origGetCurrency
		local calls: { { userId: number, currencyType: string, amount: number } } = {}
		local stored: { [string]: number }? = nil

		beforeAll(function()
			_origSetCurrency = CurrencyService.setCurrency
			_origGetCurrency = CurrencyService.getCurrency

			CurrencyService.setCurrency = function(_self: any, userId: number, currencyType: any, amount: number)
				table.insert(calls, { userId = userId, currencyType = currencyType, amount = amount })
				if stored ~= nil then
					stored[currencyType] = amount
				end
				return stored ~= nil
			end
			CurrencyService.getCurrency = function(_self: any, _userId: number)
				return stored
			end
		end)

		afterAll(function()
			CurrencyService.setCurrency = _origSetCurrency
			CurrencyService.getCurrency = _origGetCurrency
		end)

		beforeEach(function()
			calls = {}
			stored = { gold = 0, gems = 0 }
		end)

		it("forwards the target's UserId, currency type, and amount to the service", function()
			setCurrencyCommand(nil, fakePlayer, "gems", 10)
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].currencyType).to.equal("gems")
			expect(calls[1].amount).to.equal(10)
		end)

		it("reports the stored value when the profile is loaded", function()
			local message = setCurrencyCommand(nil, fakePlayer, "gems", 10)
			expect(message:find("TestPlayer")).to.be.ok()
			expect(message:find("10")).to.be.ok()
		end)

		it("reports a not-loaded failure when the profile isn't loaded", function()
			stored = nil
			local message = setCurrencyCommand(nil, fakePlayer, "gems", 10)
			expect(message:find("Failed")).to.be.ok()
		end)
	end)
end
