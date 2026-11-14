local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DealRules = require(ReplicatedStorage.Shared.Features.Deal.Rules.DealRules)
local VM = require(ReplicatedStorage.Client.UI.React.Screens.Deal.DealViewModel)

local function ownsOf(list)
	local set = {}
	for _, id in list do
		set[id] = true
	end
	return function(id)
		return set[id] == true
	end
end

return function()
	describe("banner", function()
		it("prices the card in Robux with its honest % off, and says Soon until the product exists", function()
			local ready = VM.banner("pickLegendary", true)
			expect(ready.name).to.equal("PICK A LEGENDARY")
			expect(ready.price).to.equal("R$ 449")
			expect(ready.off).to.equal("-72%")
			expect(ready.buyable).to.equal(true)
			local soon = VM.banner("pickNewHire", false)
			expect(soon.price).to.equal("Soon")
			expect(soon.buyable).to.equal(false)
		end)
	end)

	describe("honest % off", function()
		it("matches today's prices at the best Gleam pack's rate", function()
			local DealConstants = require(ReplicatedStorage.Shared.Features.Deal.Data.DealConstants)
			local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
			local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
			local CosmeticBundleRegistry =
				require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticBundleRegistry)
			local bestRate = math.huge
			for _, pack in ShopConstants.BUNDLES do
				bestRate = math.min(bestRate, pack.robux / pack.gleam)
			end
			-- The cheapest Legendary bundle and hire (so the % is never overstated).
			local legendary, hire = math.huge, math.huge
			for _, bundle in CosmeticBundleRegistry.all() do
				if bundle.rarity == "legendary" then
					legendary = math.min(legendary, bundle.price)
				end
			end
			for _, id in CosmeticRegistry.employees() do
				local item = CosmeticRegistry.get(id)
				if item.price ~= nil then
					hire = math.min(hire, item.price / ShopConstants.TOP_UP.credits)
				end
			end
			local function off(robux, gleam)
				return math.floor((1 - robux / (gleam * bestRate)) * 100 + 0.5)
			end
			local pick = DealConstants.DEALS.pickLegendary
			expect(pick.off).to.equal(off(pick.robux, legendary + pick.gleam))
			local newHire = DealConstants.DEALS.pickNewHire
			expect(newHire.off).to.equal(off(newHire.robux, hire + legendary))
		end)
	end)

	describe("cards", function()
		it("a Legendary pick shows each skin on its employee with its name", function()
			local cards = VM.cards("pickLegendary", ownsOf({ "Pippa", "Cappy" }))
			expect(#cards).to.equal(2)
			expect(cards[1].id).to.equal("Cappy.PJ")
			expect(cards[1].employee).to.equal("Cappy")
			expect(cards[1].skinKey).to.equal("PJ")
			expect(cards[1].title).to.equal("PJ Cappy")
		end)

		it("a New Hire pick shows each employee wearing their Legendary skin", function()
			local cards = VM.cards("pickNewHire", ownsOf({ "Pippa" }))
			expect(#cards).to.equal(2)
			expect(cards[1].id).to.equal("Cappy")
			expect(cards[1].skinKey).to.equal("PJ")
			expect(cards[1].title).to.equal("Cappy")
			expect(cards[1].line).to.equal("+ PJ Cappy")
		end)
	end)

	describe("hireButton", function()
		it("shows the New Hire deal under a locked employee while the deal is offered", function()
			local owns = ownsOf({ "Pippa" })
			expect(VM.hireButton("Cappy", owns, DealRules.fresh(), true)).to.equal("R$ 499 + Legendary")
			expect(VM.hireButton("Pippa", owns, DealRules.fresh(), true)).to.equal(nil)
			local bought = { bought = { pickNewHire = true }, picks = {} }
			expect(VM.hireButton("Cappy", owns, bought, true)).to.equal(nil)
			expect(VM.hireButton("Cappy", owns, DealRules.fresh(), false)).to.equal(nil)
		end)
	end)
end
