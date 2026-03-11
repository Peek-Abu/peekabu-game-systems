--!strict
--[=[
	Unit tests for the AddCurrency Cmdr command implementation.

	Mock strategy: patch CurrencyService.addCurrency plus the read-backs the command uses
	(getCurrency for the loaded check, getCurrencyAmount for before/after) inside beforeAll/afterAll —
	the command captures the service table at require time and looks methods up through it, same
	convention as the domain service specs. A shared `stored` table stands in for the player's
	currency (nil = profile not loaded); the mock addCurrency applies the cap so the "at cap" path is
	exercised realistically. Cmdr passes a real Player; the command only touches UserId/Name, so a
	shaped fake suffices.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurrencyService = require(ServerScriptService.Services.CurrencyService.CurrencyServiceServer)
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)
local addCurrencyCommand = require(ServerScriptService.Commands.AddCurrencyServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("AddCurrencyServer", function()
		local _origAddCurrency
		local _origGetCurrency
		local _origGetCurrencyAmount
		local calls: { { userId: number, currencyType: string, amount: number } } = {}
		local stored: { [string]: number }? = nil

		beforeAll(function()
			_origAddCurrency = CurrencyService.addCurrency
			_origGetCurrency = CurrencyService.getCurrency
			_origGetCurrencyAmount = CurrencyService.getCurrencyAmount

			CurrencyService.addCurrency = function(_self: any, userId: number, currencyType: any, amount: number)
				table.insert(calls, { userId = userId, currencyType = currencyType, amount = amount })
				if stored == nil then
					return false
				end
				local before = stored[currencyType] or 0
				stored[currencyType] = math.min(before + amount, CurrencyConstants.MAX_CURRENCY)
				return stored[currencyType] ~= before
			end
			CurrencyService.getCurrency = function(_self: any, _userId: number)
				return stored
			end
			CurrencyService.getCurrencyAmount = function(_self: any, _userId: number, currencyType: any)
				if stored == nil then
					return 0
				end
				return stored[currencyType] or 0
			end
		end)

		afterAll(function()
			CurrencyService.addCurrency = _origAddCurrency
			CurrencyService.getCurrency = _origGetCurrency
			CurrencyService.getCurrencyAmount = _origGetCurrencyAmount
		end)

		beforeEach(function()
			calls = {}
			stored = { gold = 0, gems = 0 }
		end)

		it("forwards the target's UserId, currency type, and amount to the service", function()
			addCurrencyCommand(nil, fakePlayer, "gold", 250)
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].currencyType).to.equal("gold")
			expect(calls[1].amount).to.equal(250)
		end)

		it("reports the amount added and the new total when the profile is loaded", function()
			local message = addCurrencyCommand(nil, fakePlayer, "gold", 250)
			expect(message:find("Added")).to.be.ok()
			expect(message:find("250")).to.be.ok()
			expect(message:find("TestPlayer")).to.be.ok()
		end)

		it("reports a not-loaded failure when the profile isn't loaded", function()
			stored = nil
			local message = addCurrencyCommand(nil, fakePlayer, "gold", 250)
			expect(message:find("Failed")).to.be.ok()
		end)

		it("reports the cap (nothing added) when the player is already at MAX_CURRENCY", function()
			stored = { gold = CurrencyConstants.MAX_CURRENCY, gems = 0 }
			local message = addCurrencyCommand(nil, fakePlayer, "gold", 500)
			expect(message:find("cap")).to.be.ok()
		end)
	end)
end
