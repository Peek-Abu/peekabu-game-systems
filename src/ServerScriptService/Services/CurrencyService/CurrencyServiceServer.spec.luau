--!strict
--[=[
	Unit tests for CurrencyServiceServer.
	
	Mock strategy: patch PlayerDataService methods inside beforeAll/afterAll
	so each spec file owns its mock window and doesn't clash with other specs
	that also patch PlayerDataService (e.g. InventoryServiceServer.spec).
	
	Patching the shared table works because CurrencyServiceServer captures
	the PlayerDataService table reference at require-time, and method lookups
	go through the table — so mutating the table's methods is reflected immediately.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService =
	require(ServerScriptService.Services.PlayerDataService.PlayerDataServiceServer)
local CurrencyService =
	require(ServerScriptService.Services.CurrencyService.CurrencyServiceServer)

-- ============================================================
-- Helpers
-- ============================================================
local function makeProfile(gold: number?, gems: number?)
	return {
		currency = { gold = gold or 0, gems = gems or 0 },
		inventory = {},
	}
end

return function()
	describe("CurrencyServiceServer", function()
		-- In-memory store, reset per test
		local _profiles: { [number]: any } = {}

		-- Save originals so we can restore after this spec
		local _origGetProfile
		local _origMutate

		beforeAll(function()
			_origGetProfile = PlayerDataService.getProfile
			_origMutate = PlayerDataService.mutate

			PlayerDataService.getProfile = function(_self: any, userId: number)
				return _profiles[userId]
			end

			PlayerDataService.mutate = function(
				_self: any,
				userId: number,
				path: string,
				mutator: (data: any) -> boolean?
			): boolean
				local profile = _profiles[userId]
				if not profile then
					return false
				end
				local data = (profile :: any)[path]
				if data == nil then
					return false
				end
				local result = mutator(data)
				return result ~= false
			end
		end)

		afterAll(function()
			PlayerDataService.getProfile = _origGetProfile
			PlayerDataService.mutate = _origMutate
		end)

		beforeEach(function()
			_profiles = {}
		end)

		-- -------------------------------------------------------------------------
		describe("getCurrency", function()
			it("should return currency table for loaded player", function()
				_profiles[1] = makeProfile(100, 50)
				local currency = CurrencyService:getCurrency(1)
				expect(currency).to.be.ok()
				expect(currency and currency.gold).to.equal(100)
			end)

			it("should return nil when profile is not loaded", function()
				expect(CurrencyService:getCurrency(999)).to.equal(nil)
			end)

			it("should throw for non-number userId", function()
				expect(function()
					CurrencyService:getCurrency("bad" :: any)
				end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("getCurrencyAmount", function()
			it("should return correct gold amount", function()
				_profiles[1] = makeProfile(250)
				expect(CurrencyService:getCurrencyAmount(1, "gold")).to.equal(250)
			end)

			it("should return 0 when profile is not loaded", function()
				expect(CurrencyService:getCurrencyAmount(999, "gold")).to.equal(0)
			end)

			it("should throw for invalid currency type", function()
				_profiles[1] = makeProfile(100)
				expect(function()
					CurrencyService:getCurrencyAmount(1, "diamonds" :: any)
				end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("hasCurrency", function()
			it("should return true when player has enough", function()
				_profiles[1] = makeProfile(100)
				expect(CurrencyService:hasCurrency(1, "gold", 50)).to.equal(true)
				expect(CurrencyService:hasCurrency(1, "gold", 100)).to.equal(true)
			end)

			it("should return false when player has insufficient funds", function()
				_profiles[1] = makeProfile(50)
				expect(CurrencyService:hasCurrency(1, "gold", 100)).to.equal(false)
			end)

			it("should return false when profile is not loaded", function()
				expect(CurrencyService:hasCurrency(999, "gold", 1)).to.equal(false)
			end)

			it("should throw for non-positive amount", function()
				_profiles[1] = makeProfile(100)
				expect(function() CurrencyService:hasCurrency(1, "gold", 0) end).to.throw()
				expect(function() CurrencyService:hasCurrency(1, "gold", -10) end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("addCurrency", function()
			it("should add currency to the profile", function()
				_profiles[1] = makeProfile(100)
				local ok = CurrencyService:addCurrency(1, "gold", 50)
				expect(ok).to.equal(true)
				expect(_profiles[1].currency.gold).to.equal(150)
			end)

			it("should return false when profile is not loaded", function()
				expect(CurrencyService:addCurrency(999, "gold", 50)).to.equal(false)
			end)

			it("should throw for invalid currency type", function()
				_profiles[1] = makeProfile(0)
				expect(function()
					CurrencyService:addCurrency(1, "invalid" :: any, 10)
				end).to.throw()
			end)

			it("should throw for non-positive amount", function()
				_profiles[1] = makeProfile(0)
				expect(function() CurrencyService:addCurrency(1, "gold", 0) end).to.throw()
				expect(function() CurrencyService:addCurrency(1, "gold", -5) end).to.throw()
			end)

			it("should handle adding to multiple currency types", function()
				_profiles[1] = makeProfile(0, 0)
				CurrencyService:addCurrency(1, "gold", 100)
				CurrencyService:addCurrency(1, "gems", 25)
				expect(_profiles[1].currency.gold).to.equal(100)
				expect(_profiles[1].currency.gems).to.equal(25)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("removeCurrency", function()
			it("should remove currency from the profile", function()
				_profiles[1] = makeProfile(100)
				local ok = CurrencyService:removeCurrency(1, "gold", 30)
				expect(ok).to.equal(true)
				expect(_profiles[1].currency.gold).to.equal(70)
			end)

			it("should return false when insufficient funds", function()
				_profiles[1] = makeProfile(20)
				local ok = CurrencyService:removeCurrency(1, "gold", 50)
				expect(ok).to.equal(false)
				expect(_profiles[1].currency.gold).to.equal(20)
			end)

			it("should return false when profile is not loaded", function()
				expect(CurrencyService:removeCurrency(999, "gold", 10)).to.equal(false)
			end)

			it("should throw for non-positive amount", function()
				_profiles[1] = makeProfile(100)
				expect(function() CurrencyService:removeCurrency(1, "gold", 0) end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("setCurrency", function()
			it("should set currency to exact amount", function()
				_profiles[1] = makeProfile(50)
				local ok = CurrencyService:setCurrency(1, "gold", 200)
				expect(ok).to.equal(true)
				expect(_profiles[1].currency.gold).to.equal(200)
			end)

			it("should return false when setting to same amount (no change)", function()
				_profiles[1] = makeProfile(100)
				expect(CurrencyService:setCurrency(1, "gold", 100)).to.equal(false)
			end)

			it("should allow setting to 0", function()
				_profiles[1] = makeProfile(100)
				local ok = CurrencyService:setCurrency(1, "gold", 0)
				expect(ok).to.equal(true)
				expect(_profiles[1].currency.gold).to.equal(0)
			end)

			it("should throw for negative amount", function()
				_profiles[1] = makeProfile(100)
				expect(function() CurrencyService:setCurrency(1, "gold", -1) end).to.throw()
			end)

			it("should return false when profile is not loaded", function()
				expect(CurrencyService:setCurrency(999, "gold", 100)).to.equal(false)
			end)
		end)
	end)
end
