--!strict
--[=[
	Unit tests for CurrencyServiceClient.

	Mock strategy: patch PlayerDataServiceClient.getProfile/.mutate (the client service
	captures that table at require-time, so method lookups see the patches), and capture
	the CurrencyUpdate handler by patching the packet's `.listen`.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataServiceClient = require(ReplicatedStorage.Client.Services.PlayerDataService.PlayerDataServiceClient)
local CurrencyServiceClient = require(ReplicatedStorage.Client.Services.CurrencyService.CurrencyServiceClient)
local CurrencyEvents = require(ReplicatedStorage.Shared.Events.CurrencyEvents)
local CurrencySignals = require(ReplicatedStorage.Client.Signals.CurrencySignals)

return function()
	describe("CurrencyServiceClient", function()
		local fakeProfile: any
		local origGetProfile
		local origMutate

		beforeAll(function()
			origGetProfile = PlayerDataServiceClient.getProfile
			origMutate = PlayerDataServiceClient.mutate

			PlayerDataServiceClient.getProfile = function(_self: any)
				return fakeProfile
			end
			PlayerDataServiceClient.mutate = function(
				_self: any,
				path: string,
				mutator: (data: any) -> boolean?
			): boolean
				if not fakeProfile then
					return false
				end
				local data = fakeProfile[path]
				if data == nil then
					return false
				end
				return mutator(data) ~= false
			end
		end)

		afterAll(function()
			PlayerDataServiceClient.getProfile = origGetProfile
			PlayerDataServiceClient.mutate = origMutate
		end)

		beforeEach(function()
			fakeProfile = { currency = { gold = 100, gems = 10 }, inventory = {} }
		end)

		-- ---------------------------------------------------------------------
		describe("getCurrency", function()
			it("returns the currency table when a profile is loaded", function()
				local c = CurrencyServiceClient:getCurrency()
				expect(c).to.be.ok()
				expect(c and c.gold).to.equal(100)
			end)

			it("returns nil when no profile is loaded", function()
				fakeProfile = nil
				expect(CurrencyServiceClient:getCurrency()).to.equal(nil)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("getCurrencyAmount", function()
			it("returns the amount for a valid currency", function()
				expect(CurrencyServiceClient:getCurrencyAmount("gold")).to.equal(100)
			end)

			it("returns 0 when no profile is loaded", function()
				fakeProfile = nil
				expect(CurrencyServiceClient:getCurrencyAmount("gold")).to.equal(0)
			end)

			it("throws for an invalid currency type", function()
				expect(function()
					CurrencyServiceClient:getCurrencyAmount("diamonds")
				end).to.throw()
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("hasCurrency", function()
			it("returns true when the player has enough", function()
				expect(CurrencyServiceClient:hasCurrency("gold", 50)).to.equal(true)
				expect(CurrencyServiceClient:hasCurrency("gold", 100)).to.equal(true)
			end)

			it("returns false when the player has too little", function()
				expect(CurrencyServiceClient:hasCurrency("gold", 500)).to.equal(false)
			end)

			it("throws for a non-positive amount", function()
				expect(function()
					CurrencyServiceClient:hasCurrency("gold", 0)
				end).to.throw()
			end)
		end)

		-- ---------------------------------------------------------------------
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

		-- ---------------------------------------------------------------------
		describe("CurrencyUpdate sync (init)", function()
			local capturedHandler: ((any) -> ())?
			local origListen

			beforeEach(function()
				capturedHandler = nil
				origListen = CurrencyEvents.packets.CurrencyUpdate.listen
				CurrencyEvents.packets.CurrencyUpdate.listen = function(handler)
					capturedHandler = handler
					return function() end
				end
				CurrencyServiceClient.init(CurrencyServiceClient)
			end)

			afterEach(function()
				CurrencyEvents.packets.CurrencyUpdate.listen = origListen
				CurrencyServiceClient.stop(CurrencyServiceClient)
			end)

			it("registers a CurrencyUpdate listener", function()
				expect(capturedHandler).to.be.a("function")
			end)

			it("applies the new amount and fires CurrencySignals.Changed", function()
				local firedType, firedAmount, firedDelta
				local conn = CurrencySignals.Changed:Connect(function(t, amt, d)
					firedType, firedAmount, firedDelta = t, amt, d
				end)

				local handler = assert(capturedHandler, "handler was not captured")
				handler({ currencyType = "gold", newAmount = 175, delta = 75 })

				-- SignalPlus fires connections via task.defer; yield once so the connection runs.
				task.wait()
				conn:Disconnect()

				expect(fakeProfile.currency.gold).to.equal(175)
				expect(firedType).to.equal("gold")
				expect(firedAmount).to.equal(175)
				expect(firedDelta).to.equal(75)
			end)
		end)
	end)
end
