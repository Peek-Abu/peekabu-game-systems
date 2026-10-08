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
				currency = { jaku = 5 },
				inventory = { items = { { itemType = "rusted-saw", quantity = 1 } } },
				stats = { totalXp = 0, investments = {} },
				equipment = { slots = {} },
				bank = { items = {}, currency = {} },
				appearance = { cosmetics = {}, accessories = {}, body = {}, headType = "Uncovered", surfaces = {} },
				equippedTitle = {},
			}
			local fakeProfile = {
				slotState = { active = 1, epoch = 1 },
				account = {
					unlockedSlots = { 1 },
					itemMint = { nextUid = 1 },
					entitlements = { cosmetics = {} },
					titles = { earned = {} },
				},
				slots = { fakeSlot },
			} :: any

			-- Slices that read off `profile.account` instead of the active slot. Listed EXPLICITLY
			-- rather than accepting "whichever scope happens to match", so a reader pointed at the
			-- wrong SCOPE (account data replicated as if it were per-character, or vice versa) still
			-- fails loudly here — that would silently replicate the wrong data.
			local ACCOUNT_SCOPED: { [string]: boolean } = { entitlements = true, titles = true }

			for name, definition in StateSyncSliceRegistry.DEFINITIONS do
				local value = definition.read(fakeProfile)
				local expected = if ACCOUNT_SCOPED[name] then fakeProfile.account[name] else fakeSlot[name]
				expect(value).to.equal(expected)
			end
		end)

		-- Guards the customization design spec's Decision 1: what a player has UNLOCKED is account-wide
		-- (earned once, shared by every character), unlike `appearance`, which is per-slot.
		it("reads entitlements off the ACCOUNT, not the active slot", function()
			local accountEntitlements = { cosmetics = { accessory = { WizardHat = true } } }
			local fakeProfile = {
				slotState = { active = 2, epoch = 1 },
				account = {
					unlockedSlots = { 1 },
					itemMint = { nextUid = 1 },
					entitlements = accountEntitlements,
				},
				slots = {
					{
						appearance = {
							cosmetics = {},
							accessories = {},
							body = {},
							headType = "Uncovered",
							surfaces = {},
						},
					},
					{
						appearance = {
							cosmetics = {},
							accessories = {},
							body = {},
							headType = "Uncovered",
							surfaces = {},
						},
					},
				},
			} :: any

			-- Same value regardless of which character is active — that is what account-wide means.
			expect(StateSyncSliceRegistry.DEFINITIONS.entitlements.read(fakeProfile)).to.equal(accountEntitlements)
			fakeProfile.slotState.active = 1
			expect(StateSyncSliceRegistry.DEFINITIONS.entitlements.read(fakeProfile)).to.equal(accountEntitlements)
		end)

		-- Guards titles design spec Decision 2: earning is about the PLAYER (account-wide); only
		-- what is WORN is per-character.
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
					unlockedSlots = { 1 },
					itemMint = { nextUid = 1 },
					entitlements = { cosmetics = {} },
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

	describe("slot-scoped readers", function()
		local function profileWith(activeSlot)
			return {
				slotState = { active = activeSlot, epoch = 1 },
				account = {
					unlockedSlots = { 1 },
					itemMint = { nextUid = 1 },
					entitlements = { cosmetics = {} },
					titles = { earned = {} },
				},
				slots = {
					{
						currency = { jaku = 1 },
						inventory = { items = {} },
						stats = { totalXp = 0, investments = {} },
						equipment = { slots = {} },
						bank = { items = {}, currency = {} },
						appearance = {
							cosmetics = {},
							accessories = {},
							body = {},
							headType = "Uncovered",
							surfaces = {},
						},
						equippedTitle = {},
					},
					{
						currency = { jaku = 2 },
						inventory = { items = {} },
						stats = { totalXp = 0, investments = {} },
						equipment = { slots = {} },
						bank = { items = {}, currency = {} },
						appearance = {
							cosmetics = {},
							accessories = {},
							body = {},
							headType = "Uncovered",
							surfaces = {},
						},
						equippedTitle = {},
					},
					{
						currency = { jaku = 3 },
						inventory = { items = {} },
						stats = { totalXp = 0, investments = {} },
						equipment = { slots = {} },
						bank = { items = {}, currency = {} },
						appearance = {
							cosmetics = {},
							accessories = {},
							body = {},
							headType = "Uncovered",
							surfaces = {},
						},
						equippedTitle = {},
					},
				},
			}
		end

		it("reads currency from the ACTIVE slot", function()
			expect(StateSyncSliceRegistry.DEFINITIONS.currency.read(profileWith(2)).jaku).to.equal(2)
		end)

		it("follows the active slot", function()
			expect(StateSyncSliceRegistry.DEFINITIONS.currency.read(profileWith(3)).jaku).to.equal(3)
		end)

		it("never exposes an inactive slot's value", function()
			local mirrored = StateSyncSliceRegistry.DEFINITIONS.currency.read(profileWith(1))
			expect(mirrored.jaku).to.equal(1)
			expect(mirrored.jaku).to.never.equal(2)
		end)

		it("reads stats from the ACTIVE slot", function()
			local profile = profileWith(2)
			profile.slots[2].stats = { totalXp = 777, investments = { health = 1 } }
			expect(StateSyncSliceRegistry.DEFINITIONS.stats.read(profile).totalXp).to.equal(777)
		end)

		-- Task 3: inventory is now `{ items = { InventoryEntry } }`, not a bare entry array. The
		-- reader must hand back the WRAPPER as-is (it projects the slice, it does not unwrap it) —
		-- a reader that silently returned `.items` instead would desync from every other slice's
		-- "hand back exactly what's on the slot" contract and break StateSyncClientStore's atom shape.
		it("reads the inventory WRAPPER (not the bare items array) from the ACTIVE slot", function()
			local profile = profileWith(2)
			profile.slots[2].inventory = { items = { { itemType = "rusted-saw", quantity = 3 } } }
			local mirrored = StateSyncSliceRegistry.DEFINITIONS.inventory.read(profile)
			expect(mirrored.items).to.be.ok()
			expect(#mirrored.items).to.equal(1)
			expect(mirrored.items[1].itemType).to.equal("rusted-saw")
		end)
	end)
end
