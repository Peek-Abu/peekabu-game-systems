local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local VM = require(script.Parent.CharacterPickViewModel)

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

	local function find(list, id)
		for _, entry in list do
			if entry.id == id then
				return entry
			end
		end
		return nil
	end

	describe("cards", function()
		it("lists every employee, the free one first, marking the selected one", function()
			local cards = VM.cards(owner(), "Pippa")
			expect(#cards).to.equal(#CosmeticRegistry.employees())
			expect(cards[1].id).to.equal("Pippa")
			expect(cards[1].selected).to.equal(true)
			expect(cards[1].tag).to.equal("Free!")
			expect(cards[1].locked).to.equal(false)
		end)

		it("shows a locked employee's hire price", function()
			local prickles = find(VM.cards(owner(), "Pippa"), "Prickles")
			expect(prickles.locked).to.equal(true)
			expect(prickles.tag).to.equal("2,500")
			expect(prickles.selected).to.equal(false)
			expect(find(VM.cards(owner({ "Prickles" }), "Pippa"), "Prickles").locked).to.equal(false)
		end)
	end)

	describe("start", function()
		it("starts as an owned employee", function()
			local start = VM.start("Pippa", owner())
			expect(start.text).to.equal("Start as Pippa!")
			expect(start.enabled).to.equal(true)
		end)

		it("can only preview a locked employee until the Shop exists", function()
			local start = VM.start("Prickles", owner())
			expect(start.enabled).to.equal(false)
			expect(start.text).to.equal("Hire in the Shop soon")
		end)
	end)

	describe("shouldOpen", function()
		it("opens only after the loadout synced, when not picked, in the depot", function()
			local value = CosmeticConstants.defaultLoadout()
			expect(VM.shouldOpen(value, true, true)).to.equal(true)
			expect(VM.shouldOpen(value, false, true)).to.equal(false)
			expect(VM.shouldOpen(value, true, false)).to.equal(false)
			value.picked = true
			expect(VM.shouldOpen(value, true, true)).to.equal(false)
		end)
	end)

	it("defaults the selection to the default employee", function()
		expect(VM.DEFAULT).to.equal(CosmeticConstants.DEFAULT_EMPLOYEE)
	end)
end
