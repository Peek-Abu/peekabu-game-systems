local ShiftHotbarViewModel = require(script.Parent.ShiftHotbarViewModel)

return function()
	describe("hotbar", function()
		it("puts the vacuum in slot 1 with its canister, and the four item slots after it", function()
			local view = ShiftHotbarViewModel.hotbar({ canister = 2, vacuumEquipped = true })
			expect(#view.slots).to.equal(5)
			expect(view.slots[1].vacuum).to.equal(true)
			expect(view.slots[1].name).to.equal("VACUUM")
			expect(view.slots[1].tag).to.equal("2/3")
			expect(view.slots[1].key).to.equal("1")
			expect(view.slots[1].selected).to.equal(true)
			expect(view.slots[5].key).to.equal("5")
			expect(view.selected).to.equal(1)
			expect(view.locked).to.equal(false)
		end)

		it("tags a valuable $??? until appraised, then its value and jackpot name", function()
			local view = ShiftHotbarViewModel.hotbar({
				inv1 = "wristwatch",
				inv2 = "wristwatch",
				inv2Value = 220,
				inv2Variant = "Gold",
			})
			expect(view.slots[2].tag).to.equal("$???")
			expect(view.slots[2].name).to.equal("Wristwatch")
			expect(view.slots[3].tag).to.equal("$220")
			expect(view.slots[3].name).to.equal("Gold wristwatch")
		end)

		it("tags trash with its clearance", function()
			local view = ShiftHotbarViewModel.hotbar({ inv4 = "rubbishBag", inv4Value = 10 })
			expect(view.slots[5].tag).to.equal("+10")
			expect(view.slots[5].kind).to.equal("rubbishBag")
		end)

		it("marks the hands slot chosen, and a small hands item never locks", function()
			local view = ShiftHotbarViewModel.hotbar({ inv1 = "plaque", inv2 = "keyring", invHands = 2 })
			expect(view.selected).to.equal(3)
			expect(view.slots[3].inHands).to.equal(true)
			expect(view.slots[3].selected).to.equal(true)
			expect(view.slots[2].selected).to.equal(false)
			expect(view.locked).to.equal(false)
			expect(view.slots[3].locked).to.equal(false)
		end)

		it("locks the hotbar while a big item fills the hands: its slot reads HANDS FULL", function()
			local view =
				ShiftHotbarViewModel.hotbar({ inv1 = "plaque", inv4 = "monitor", invHands = 4, vacuumEquipped = false })
			expect(view.locked).to.equal(true)
			expect(view.slots[5].locked).to.equal(true)
			expect(view.slots[5].fragile).to.equal(true)
			expect(view.slots[2].locked).to.equal(false)
		end)

		it("keeps an empty item slot chosen with empty hands, and never a stale vacuum choice", function()
			expect(ShiftHotbarViewModel.hotbar({ invSelected = 4 }).selected).to.equal(4)
			expect(ShiftHotbarViewModel.hotbar({ invSelected = 1 }).selected).to.equal(0)
			expect(ShiftHotbarViewModel.hotbar({}).selected).to.equal(0)
		end)
	end)
end
