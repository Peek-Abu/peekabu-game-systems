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

		it("tags a valuable ??? Gleam until appraised, then its value and jackpot name", function()
			local view = ShiftHotbarViewModel.hotbar({
				inv1 = "wristwatch",
				inv2 = "wristwatch",
				inv2Value = 220,
				inv2Variant = "Gold",
			})
			expect(view.slots[2].tag).to.equal("??? Gleam")
			expect(view.slots[2].name).to.equal("Wristwatch")
			expect(view.slots[3].tag).to.equal("220 Gleam")
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
end
