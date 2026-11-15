local ShiftHotbarViewModel = require(script.Parent.ShiftHotbarViewModel)

return function()
	describe("hotbar", function()
		it("puts the vacuum in slot 1 with the contract's Gloom gauge, and the four item slots after it", function()
			local view = ShiftHotbarViewModel.hotbar({ vacuumEquipped = true }, 340, 500)
			expect(#view.slots).to.equal(5)
			expect(view.slots[1].vacuum).to.equal(true)
			expect(view.slots[1].name).to.equal("VACUUM")
			expect(view.slots[1].tag).to.equal("340/500")
			expect(ShiftHotbarViewModel.hotbar({}).slots[1].tag).to.equal("")
			expect(view.slots[1].key).to.equal("1")
			expect(view.slots[1].selected).to.equal(true)
			expect(view.slots[5].key).to.equal("5")
			expect(view.selected).to.equal(1)
			expect(view.locked).to.equal(false)
		end)

		it("tags a valuable ??? Credits until appraised, then its value and jackpot name", function()
			local view = ShiftHotbarViewModel.hotbar({
				inv1 = "wristwatch",
				inv2 = "wristwatch",
				inv2Value = 220,
				inv2Variant = "Gold",
			})
			expect(view.slots[2].tag).to.equal("??? Credits")
			expect(view.slots[2].name).to.equal("Wristwatch")
			expect(view.slots[3].tag).to.equal("220 Credits")
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
	describe("V1 slots", function()
		it("gives the vacuum its Gloom gauge as a share and a percent caption", function()
			local view = ShiftHotbarViewModel.hotbar({ vacuumEquipped = true }, 290, 500)
			expect(view.slots[1].gauge).to.equal(0.58)
			expect(view.slots[1].caption).to.equal("58%")
			local over = ShiftHotbarViewModel.hotbar({}, 620, 500)
			expect(over.slots[1].gauge).to.equal(1)
			expect(over.slots[1].caption).to.equal("100%")
			expect(ShiftHotbarViewModel.hotbar({}).slots[1].gauge).to.equal(nil)
		end)

		it("captions a valuable with its worth (no unit: the coin says Credits), trash with its clearance", function()
			local view = ShiftHotbarViewModel.hotbar({ inv1 = "wristwatch", inv2 = "wristwatch", inv2Value = 220 })
			expect(view.slots[2].caption).to.equal("???")
			expect(view.slots[2].coin).to.equal(true)
			expect(view.slots[3].caption).to.equal("220")
			local trash = ShiftHotbarViewModel.hotbar({ inv4 = "rubbishBag", inv4Value = 10 })
			expect(trash.slots[5].caption).to.equal("+10")
			expect(trash.slots[5].coin).to.equal(false)
			expect(trash.slots[4].caption).to.equal(nil)
		end)

		it("has no kit renders for items: every item draws its live model, like the rest (P1 placeholders)", function()
			expect(ShiftHotbarViewModel.iconFor).to.equal(nil)
		end)
	end)

	describe("metrics", function()
		-- The first hotbar's cards (96 x 112 desktop, 62 x 70 phone): the user asked for them half the size.
		local desktop = ShiftHotbarViewModel.metrics(false)
		local phone = ShiftHotbarViewModel.metrics(true)

		it("draws the desktop cards and their art at half the first hotbar's size", function()
			expect(desktop.width).to.equal(48)
			expect(desktop.height).to.equal(56)
			expect(desktop.icon).to.equal(24)
			expect(desktop.gap).to.equal(5)
			expect(desktop.lift).to.equal(5)
		end)

		it("keeps every desktop text at 11 px or more, and drops the name a half-size card cannot fit", function()
			expect(desktop.key >= 11).to.equal(true)
			expect(desktop.tag >= 11).to.equal(true)
			expect(desktop.stamp >= 11).to.equal(true)
			expect(desktop.name).to.equal(0)
		end)

		it("keeps a 44 px tap target on phone, smaller than before", function()
			expect(phone.width >= 44).to.equal(true)
			expect(phone.height + phone.lift >= 44).to.equal(true)
			expect(phone.width < 62 and phone.height < 70).to.equal(true)
			expect(phone.key >= 10 and phone.tag >= 10 and phone.stamp >= 10).to.equal(true)
		end)

		it("fits the art and the tag inside each card", function()
			for _, size in { desktop, phone } do
				local inner = size.height - 2 * size.padding
				expect(size.iconTop + size.icon <= inner - (size.tag + 6)).to.equal(true)
				expect(size.icon <= size.width - 2 * size.padding).to.equal(true)
			end
		end)

		it("measures the whole bar: five cards and four gaps wide, a card and its lift tall", function()
			local bar = ShiftHotbarViewModel.barSize(false, 5)
			expect(bar.X).to.equal(5 * 48 + 4 * 5)
			expect(bar.Y).to.equal(56 + 5)
		end)
	end)
	describe("droppable", function()
		local function slot(extra)
			local value = { slot = 2, vacuum = false, kind = "coffeeMug", inHands = true }
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end

		it("drops on a long press only from the slot whose item is in the hands", function()
			expect(ShiftHotbarViewModel.droppable(slot())).to.equal(true)
			expect(ShiftHotbarViewModel.droppable(slot({ inHands = false }))).to.equal(false)
		end)

		it("never drops the vacuum or an empty slot", function()
			expect(ShiftHotbarViewModel.droppable(slot({ vacuum = true, kind = nil }))).to.equal(false)
			expect(ShiftHotbarViewModel.droppable(slot({ kind = nil, inHands = false }))).to.equal(false)
		end)

		it("holds about half a second, past a tap and short of a long wait", function()
			expect(ShiftHotbarViewModel.DROP_HOLD >= 0.35 and ShiftHotbarViewModel.DROP_HOLD <= 0.8).to.equal(true)
		end)
	end)
end
