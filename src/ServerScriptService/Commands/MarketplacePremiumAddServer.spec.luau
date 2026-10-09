--[[
	Unit tests for the premiumadd Cmdr command. Mock strategy (the CurrencyAddServer.spec convention):
	patch the MarketplaceService premium methods inside beforeAll/afterAll; `stored` stands in for the
	balance (nil = profile not loaded).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local MarketplaceService = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local premiumAdd = require(ServerScriptService.Commands.MarketplacePremiumAddServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("MarketplacePremiumAddServer", function()
		local originalGet
		local originalAdd
		local stored = nil
		local refuse = false

		beforeAll(function()
			originalGet = MarketplaceService.getPremium
			originalAdd = MarketplaceService.addPremium
			MarketplaceService.getPremium = function()
				return stored
			end
			MarketplaceService.addPremium = function(_self, _userId, amount)
				if stored == nil or refuse then
					return false, "over the cap"
				end
				stored += amount
				return true
			end
		end)

		afterAll(function()
			MarketplaceService.getPremium = originalGet
			MarketplaceService.addPremium = originalAdd
		end)

		beforeEach(function()
			stored = 0
			refuse = false
		end)

		it("adds premium and reports the new balance", function()
			local message = premiumAdd(nil, fakePlayer, 25)
			expect(stored).to.equal(25)
			expect(message:find("Added 25")).to.be.ok()
			expect(message:find("now 25")).to.be.ok()
		end)

		it("reports an unloaded profile", function()
			stored = nil
			expect(premiumAdd(nil, fakePlayer, 5):find("isn't loaded")).to.be.ok()
		end)

		it("reports a refusal with its reason", function()
			refuse = true
			expect(premiumAdd(nil, fakePlayer, 5):find("over the cap")).to.be.ok()
		end)

		it("refuses a non-positive amount", function()
			expect(premiumAdd(nil, fakePlayer, 0):find("must be positive")).to.be.ok()
			expect(stored).to.equal(0)
		end)
	end)
end
