local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local InventoryViewModel = require(script.Parent.InventoryViewModel)
local VM = require(script.Parent.InventoryItemViewModel)

return function()
	-- Owns every free item plus the ids given.
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

	local function loadout(patch)
		local value = CosmeticConstants.defaultLoadout()
		for key, v in patch or {} do
			value[key] = v
		end
		return value
	end

	local function find(list, id)
		for _, entry in list do
			if entry.id == id then
				return entry
			end
		end
		return nil
	end

	describe("re-export", function()
		it("is what InventoryViewModel hands out as band, action, items and detail", function()
			expect(InventoryViewModel.band).to.equal(VM.band)
			expect(InventoryViewModel.action).to.equal(VM.action)
			expect(InventoryViewModel.items).to.equal(VM.items)
			expect(InventoryViewModel.detail).to.equal(VM.detail)
		end)
	end)

	describe("band", function()
		it("gives owned items no band and the worn one a Wearing band", function()
			expect(VM.band(CosmeticRegistry.get("Pippa.GloomTouched"), true, false)).to.equal(nil)
			local worn = VM.band(CosmeticRegistry.get("Pippa.Default"), true, true)
			expect(worn.kind).to.equal("wearing")
			expect(worn.text).to.equal("Wearing")
		end)

		it("names where a locked item comes from", function()
			local gleam = VM.band(CosmeticRegistry.get("Pippa.BubbleBuddy"), false, false)
			expect(gleam.kind).to.equal("gleam")
			expect(gleam.text).to.equal("1,600")
			expect(VM.band(CosmeticRegistry.get("Prickles.Showstopper"), false, false).kind).to.equal("locker")
			expect(VM.band(CosmeticRegistry.get("Pippa.OwnerSpecial"), false, false).kind).to.equal("missed")
		end)
	end)

	describe("action", function()
		it("says Wear for an owned item and Wearing for the worn one", function()
			local wear = VM.action(CosmeticRegistry.get("Pippa.GloomTouched"), true, false)
			expect(wear.text).to.equal("Wear")
			expect(wear.enabled).to.equal(true)
			local wearing = VM.action(CosmeticRegistry.get("Pippa.Default"), true, true)
			expect(wearing.text).to.equal("Wearing")
			expect(wearing.enabled).to.equal(false)
		end)

		it("sends a buyable item to its Shop page, with its price", function()
			local action = VM.action(CosmeticRegistry.get("Pippa.BubbleBuddy"), false, false)
			expect(action.text).to.equal("See in Shop")
			expect(action.kind).to.equal("shop")
			expect(action.price.currency).to.equal("gleam")
			expect(action.price.amount).to.equal("1,600")
		end)
	end)

	describe("items", function()
		it("lists the employee's skins with the free one first and the worn one marked", function()
			local list = VM.items("skin", "Pippa", loadout(), owner())
			expect(list[1].id).to.equal("Pippa.Default")
			expect(list[1].worn).to.equal(true)
			expect(list[1].band.kind).to.equal("wearing")
			local legendary = find(list, "Pippa.BubbleBuddy")
			expect(legendary.owned).to.equal(false)
			expect(legendary.dim).to.equal(true)
		end)

		it("flags owned items the player has not seen as New", function()
			local list = VM.items("skin", "Pippa", loadout(), owner({ "Pippa.GloomTouched" }))
			expect(find(list, "Pippa.GloomTouched").new).to.equal(true)
			expect(find(list, "Pippa.Default").new).to.equal(false)
		end)

		it("marks the emotes on the wheel with their slot", function()
			local cards = VM.items("emote", "Pippa", loadout(), owner())
			expect(cards[1].id).to.equal("Pippa.Wave")
			expect(cards[1].band.text).to.equal("Slot 1")
		end)
	end)

	describe("detail", function()
		it("shows the Styles row only for skins with real styles", function()
			local bubble = VM.detail(CosmeticRegistry.get("Pippa.BubbleBuddy"), loadout(), owner())
			expect(bubble.styles.visible).to.equal(true)
			expect(bubble.styles.count).to.equal(3)
			expect(VM.detail(CosmeticRegistry.get("Pippa.Default"), loadout(), owner()).styles.visible).to.equal(false)
		end)

		it("adds an owned emote to the first free slot", function()
			local view =
				VM.detail(CosmeticRegistry.get("Pippa.Bubbles"), loadout(), owner({ "Pippa.Bubbles" }), "Pippa")
			expect(view.action.text).to.equal("Add to wheel")
			expect(view.wheelSlot).to.equal(2)
			expect(#view.wheel).to.equal(4)
		end)
	end)
end
