--!strict
--[=[
	Unit tests for StateSyncSliceRegistry — the one declaration site for replicated slices.
	NAMES must stay a faithful, deterministic derivation of DEFINITIONS: every downstream registry
	(StateSyncConstants.SLICES, StateSyncServerStore, StateSyncClientStore's boot assert) trusts it.
]=]

local StateSyncSliceRegistry = require(script.Parent.StateSyncSliceRegistry)

return function()
	describe("NAMES", function()
		it("contains exactly the DEFINITIONS keys, sorted", function()
			local expected: { string } = {}
			for name in StateSyncSliceRegistry.DEFINITIONS do
				table.insert(expected, name)
			end
			table.sort(expected)

			expect(#StateSyncSliceRegistry.NAMES).to.equal(#expected)
			for i, name in expected do
				expect(StateSyncSliceRegistry.NAMES[i]).to.equal(name)
			end
		end)
	end)

	describe("DEFINITIONS", function()
		it("each entry's read() extracts its own slice off the active slot", function()
			local fakeSlot = {
				currency = { coins = 5 },
				inventory = { items = { { itemType = "wrench", quantity = 1 } } },
				equippedTitle = {},
			}
			local fakeProfile = {
				slotState = { active = 1, epoch = 1 },
				account = {
					itemMint = { nextUid = 1 },
					titles = { earned = {} },
					premium = { balance = 7 },
					receipts = { ids = {} },
				},
				slots = { fakeSlot },
			} :: any

			-- Slices that read off `profile.account` instead of the active slot. Listed EXPLICITLY
			-- rather than accepting "whichever scope happens to match", so a reader pointed at the
			-- wrong SCOPE (account data replicated as if it were per-slot, or vice versa) still
			-- fails loudly here — that would silently replicate the wrong data.
			local ACCOUNT_SCOPED: { [string]: boolean } = { titles = true, premium = true }

			for name, definition in StateSyncSliceRegistry.DEFINITIONS do
				local value = definition.read(fakeProfile)
				local expected = if ACCOUNT_SCOPED[name] then fakeProfile.account[name] else fakeSlot[name]
				expect(value).to.equal(expected)
			end
		end)

		it("declares exactly the currency, inventory, premium, titles and equippedTitle slices", function()
			local expected = { "currency", "equippedTitle", "inventory", "premium", "titles" }
			expect(#StateSyncSliceRegistry.NAMES).to.equal(#expected)
			for i, name in expected do
				expect(StateSyncSliceRegistry.NAMES[i]).to.equal(name)
			end
		end)

		-- Earning is about the PLAYER (account-wide); only what is WORN is per-slot.
		-- The registry readers are pure, so a hand-built two-slot profile exercises the active-slot
		-- projection regardless of PlayerDataConstants.MAX_SLOTS.
		it("reads titles off the ACCOUNT but equippedTitle off the ACTIVE slot", function()
			local earned = { veteran = true }
			-- Distinguishable per-slot equippedTitle values: this is what lets the assertions below
			-- actually FAIL if the reader picked the wrong slot (or the account) instead of the
			-- active one.
			local slot1Equipped = { equipped = "veteran" }
			local slot2Equipped = { equipped = "champion" }
			local fakeProfile = {
				slotState = { active = 1, epoch = 1 },
				account = {
					itemMint = { nextUid = 1 },
					titles = { earned = earned },
				},
				slots = { { equippedTitle = slot1Equipped }, { equippedTitle = slot2Equipped } },
			} :: any

			expect(StateSyncSliceRegistry.DEFINITIONS.titles.read(fakeProfile).earned).to.equal(earned)
			fakeProfile.slotState.active = 2
			expect(StateSyncSliceRegistry.DEFINITIONS.titles.read(fakeProfile).earned).to.equal(earned)

			-- equippedTitle must follow the ACTIVE slot specifically, not just "not the account" —
			-- a reader that returned slot 1's value regardless of `active`, or the account's data,
			-- would fail these.
			expect(StateSyncSliceRegistry.DEFINITIONS.equippedTitle.read(fakeProfile)).to.equal(slot2Equipped)
			fakeProfile.slotState.active = 1
			expect(StateSyncSliceRegistry.DEFINITIONS.equippedTitle.read(fakeProfile)).to.equal(slot1Equipped)
		end)
	end)

	-- These readers are pure functions of the profile they are handed, so hand-built three-slot
	-- profiles exercise the active-slot projection even while PlayerDataConstants.MAX_SLOTS = 1.
	describe("slot-scoped readers", function()
		local function slot(coins)
			return {
				currency = { coins = coins },
				inventory = { items = {} },
				equippedTitle = {},
			}
		end

		local function profileWith(activeSlot)
			return {
				slotState = { active = activeSlot, epoch = 1 },
				account = {
					itemMint = { nextUid = 1 },
					titles = { earned = {} },
				},
				slots = { slot(1), slot(2), slot(3) },
			}
		end

		it("reads currency from the ACTIVE slot", function()
			expect(StateSyncSliceRegistry.DEFINITIONS.currency.read(profileWith(2)).coins).to.equal(2)
		end)

		it("follows the active slot", function()
			expect(StateSyncSliceRegistry.DEFINITIONS.currency.read(profileWith(3)).coins).to.equal(3)
		end)

		it("never exposes an inactive slot's value", function()
			local mirrored = StateSyncSliceRegistry.DEFINITIONS.currency.read(profileWith(1))
			expect(mirrored.coins).to.equal(1)
			expect(mirrored.coins).to.never.equal(2)
		end)

		-- Inventory is `{ items = { InventoryEntry } }`, not a bare entry array. The reader must hand
		-- back the WRAPPER as-is (it projects the slice, it does not unwrap it) — a reader that
		-- silently returned `.items` instead would desync from every other slice's "hand back exactly
		-- what's on the slot" contract and break StateSyncClientStore's atom shape.
		it("reads the inventory WRAPPER (not the bare items array) from the ACTIVE slot", function()
			local profile = profileWith(2)
			profile.slots[2].inventory = { items = { { itemType = "wrench", quantity = 3 } } }
			local mirrored = StateSyncSliceRegistry.DEFINITIONS.inventory.read(profile)
			expect(mirrored.items).to.be.ok()
			expect(#mirrored.items).to.equal(1)
			expect(mirrored.items[1].itemType).to.equal("wrench")
		end)
	end)
end
