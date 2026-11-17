local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local VM = require(script.Parent.ShopListViewModel)

return function()
	local function owner(ids)
		local set = {}
		for _, id in ids or {} do
			set[id] = true
		end
		return function(id)
			local item = CosmeticRegistry.get(id)
			return item ~= nil and (item.source == "default" or set[id] == true)
		end
	end
	local rich = { gleam = 99999, credits = 99999 }

	describe("hire tab", function()
		it("lists every employee for sale and nothing else, hired ones last", function()
			local employees = 0
			for _, offer in ShopRegistry.all() do
				if CosmeticRegistry.get(offer.items[1]).kind == "employee" then
					employees += 1
				end
			end
			expect(employees > 0).to.equal(true)
			local cards = VM.hires(owner(), rich)
			expect(#cards).to.equal(employees)
			for _, card in cards do
				expect(card.kind).to.equal("employee")
				expect(card.currency).to.equal("credits")
			end
			local hired = VM.hires(owner({ cards[1].id }), rich)
			expect(hired[#hired].id).to.equal(cards[1].id)
			expect(hired[#hired].state).to.equal("owned")
		end)
	end)

	describe("skins tab", function()
		it("lists every offer but employees, filters by employee, puts what you own last", function()
			local all = VM.skins(owner({ "Pippa.BubbleBuddy" }), rich, nil)
			for _, card in all do
				expect(card.kind ~= "employee").to.equal(true)
			end
			expect(all[#all].state).to.equal("owned")
			for _, card in VM.skins(owner(), rich, "Cappy") do
				-- A bundle's card is checked by its hero item.
				local item = CosmeticRegistry.get(ShopRegistry.get(card.id).items[1])
				expect(item.employee == nil or item.employee == "Cappy").to.equal(true)
				-- Vacuum skins have their own filter (owner, 2026-11-13).
				expect(item.kind).never.to.equal("vacuum")
			end
		end)

		it("has a Vacuums filter right after All, before the employees, showing only vacuum skins", function()
			local filters = VM.skinFilters({ "Pippa", "Cappy", "Prickles" })
			expect(filters[1].text).to.equal("All")
			expect(filters[1].value).to.equal(nil)
			expect(filters[2].text).to.equal("Vacuums")
			expect(filters[2].value).to.equal(VM.VACUUMS)
			expect(filters[3].text).to.equal("Pippa")
			expect(filters[3].value).to.equal("Pippa")
			expect(#filters).to.equal(5)
			local vacuums = VM.skins(owner(), rich, VM.VACUUMS)
			expect(#vacuums > 0).to.equal(true)
			for _, card in vacuums do
				expect(card.kind).to.equal("vacuum")
			end
		end)
	end)
end
