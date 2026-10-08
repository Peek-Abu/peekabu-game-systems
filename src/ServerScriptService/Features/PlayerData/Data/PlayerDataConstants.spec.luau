--!strict
--[=[
	Unit tests for PlayerDataConstants — the profile-template registry.

	Covers the slot-aware profile shape: MAX_SLOTS, and the PROFILE_TEMPLATE's slotState / account /
	slots skeleton that registerSlotPath / registerAccountPath build on.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataConstants = require(ServerScriptService.Features.PlayerData.Data.PlayerDataConstants)
local PlayerDataPathUtils = require(ServerScriptService.Features.PlayerData.Utils.PlayerDataPathUtils)

return function()
	-- Multi-slot behaviour is dormant while MAX_SLOTS = 1; these re-enable when a game raises it.
	local itMultiSlot = if PlayerDataConstants.MAX_SLOTS >= 2 then it else itSKIP

	describe("PlayerDataConstants", function()
		describe("slot-aware template", function()
			it("exposes MAX_SLOTS", function()
				expect(PlayerDataConstants.MAX_SLOTS).to.equal(1)
			end)

			it("starts new profiles on slot 1", function()
				expect(PlayerDataConstants.PROFILE_TEMPLATE.slotState.active).to.equal(1)
			end)

			it("gives new profiles MAX_SLOTS slot tables", function()
				expect(#PlayerDataConstants.PROFILE_TEMPLATE.slots).to.equal(PlayerDataConstants.MAX_SLOTS)
			end)

			itMultiSlot("gives each slot its OWN table (no shared-reference aliasing)", function()
				local slots = PlayerDataConstants.PROFILE_TEMPLATE.slots
				for index = 2, PlayerDataConstants.MAX_SLOTS do
					expect(slots[index - 1]).to.never.equal(slots[index])
				end
			end)

			-- itemMint IS an owned ACCOUNT-wide slice (InventoryServiceServer registers and validates it
			-- via PlayerDataSliceSystem.registerAccount) — its default is just stamped directly onto the
			-- skeleton rather than left as an empty `{}`, because ItemMint requires `nextUid` and an empty
			-- table wouldn't typecheck. nextUid must start at 1, not 0 (0 could read as falsy/absent).
			it("stamps a default itemMint onto new profiles' account", function()
				expect(PlayerDataConstants.PROFILE_TEMPLATE.account.itemMint).to.be.ok()
				expect(PlayerDataConstants.PROFILE_TEMPLATE.account.itemMint.nextUid).to.equal(1)
			end)
		end)

		describe("registerSlotPath", function()
			it("stamps the default into EVERY slot", function()
				PlayerDataConstants.registerSlotPath("testStamped", { level = 1 })
				for index = 1, PlayerDataConstants.MAX_SLOTS do
					expect(PlayerDataConstants.PROFILE_TEMPLATE.slots[index].testStamped.level).to.equal(1)
				end
			end)

			itMultiSlot("deep-copies the default per slot, so slots never alias one table", function()
				PlayerDataConstants.registerSlotPath("testAlias", { level = 1 })
				local slots = PlayerDataConstants.PROFILE_TEMPLATE.slots
				expect(slots[1].testAlias).to.never.equal(slots[2].testAlias)

				slots[1].testAlias.level = 99
				expect(slots[2].testAlias.level).to.equal(1)
			end)

			it("registers the validator against EVERY slot, not just slot 1", function()
				PlayerDataConstants.registerSlotPath("testValidated", { n = 0 }, function(value)
					return value.n >= 0, "n must be non-negative"
				end)

				-- One registration; the validator must be found for any concrete slot path.
				for index = 1, PlayerDataConstants.MAX_SLOTS do
					local validator =
						PlayerDataConstants.getValidator(PlayerDataPathUtils.forSlot("testValidated", index))
					expect(validator).to.be.ok()
					expect(validator({ n = -1 })).to.equal(false)
				end
			end)
		end)

		describe("registerAccountPath", function()
			it("stamps the default under account", function()
				PlayerDataConstants.registerAccountPath("testSettings", { sfx = true })
				expect(PlayerDataConstants.PROFILE_TEMPLATE.account.testSettings.sfx).to.equal(true)
			end)

			it("registers a validator found by the account path", function()
				PlayerDataConstants.registerAccountPath("testAccountValidated", { n = 0 }, function(value)
					return value.n >= 0, "n must be non-negative"
				end)
				local validator =
					PlayerDataConstants.getValidator(PlayerDataPathUtils.forAccount("testAccountValidated"))
				expect(validator).to.be.ok()
				expect(validator({ n = -1 })).to.equal(false)
			end)
		end)

		-- A bare ROOT key (slotState) is registered by the core skeleton itself, so it carries a
		-- data-layer validator exactly like a slice — it is not the one writable path where any value
		-- goes (see PlayerDataConstants' registerRootPath header).
		describe("registerRootPath", function()
			it("resolves the validator by the BARE key", function()
				expect(PlayerDataConstants.getValidator("slotState")).to.be.ok()
			end)

			it("accepts an in-range integer active slot", function()
				local validator = PlayerDataConstants.getValidator("slotState")
				expect(validator({ active = 1, epoch = 1 })).to.equal(true)
				expect(validator({ active = PlayerDataConstants.MAX_SLOTS, epoch = 7 })).to.equal(true)
			end)

			it("rejects an active slot above MAX_SLOTS", function()
				local validator = PlayerDataConstants.getValidator("slotState")
				expect(validator({ active = PlayerDataConstants.MAX_SLOTS + 1, epoch = 1 })).to.equal(false)
			end)

			it("rejects a zero / negative active slot", function()
				local validator = PlayerDataConstants.getValidator("slotState")
				expect(validator({ active = 0, epoch = 1 })).to.equal(false)
				expect(validator({ active = -1, epoch = 1 })).to.equal(false)
			end)

			it("rejects a non-integer active slot", function()
				local validator = PlayerDataConstants.getValidator("slotState")
				expect(validator({ active = 2.5, epoch = 1 })).to.equal(false)
			end)

			it("rejects a non-number active slot", function()
				local validator = PlayerDataConstants.getValidator("slotState")
				expect(validator({ active = "2", epoch = 1 })).to.equal(false)
				expect(validator({})).to.equal(false)
			end)

			-- The epoch is the generation counter transaction()'s stale-op guard reads: a slotState whose
			-- epoch is missing/fractional/below 1 would make a staleness comparison meaningless, so the
			-- data layer refuses to store one — on ANY path into the key, not just a slot switch's.
			it("rejects a non-number epoch", function()
				local validator = PlayerDataConstants.getValidator("slotState")
				expect(validator({ active = 1, epoch = "1" })).to.equal(false)
				expect(validator({ active = 1 })).to.equal(false)
			end)

			it("rejects a non-integer epoch", function()
				local validator = PlayerDataConstants.getValidator("slotState")
				expect(validator({ active = 1, epoch = 2.5 })).to.equal(false)
			end)

			it("rejects an epoch below 1", function()
				local validator = PlayerDataConstants.getValidator("slotState")
				expect(validator({ active = 1, epoch = 0 })).to.equal(false)
				expect(validator({ active = 1, epoch = -1 })).to.equal(false)
			end)

			-- Monotonic, and NOT tied to the slot index: any slot may carry any epoch >= 1.
			it("accepts a large epoch on any slot", function()
				local validator = PlayerDataConstants.getValidator("slotState")
				expect(validator({ active = 1, epoch = 9999 })).to.equal(true)
			end)

			it("stamps the default onto the template", function()
				expect(PlayerDataConstants.PROFILE_TEMPLATE.slotState.active).to.equal(1)
			end)

			it("seeds slotState with epoch 1", function()
				expect(PlayerDataConstants.PROFILE_TEMPLATE.slotState.epoch).to.equal(1)
			end)

			it("stamps a registered root default and finds its validator", function()
				PlayerDataConstants.registerRootPath("testRoot", { n = 0 }, function(value)
					return value.n >= 0, "n must be non-negative"
				end)
				local template: any = PlayerDataConstants.PROFILE_TEMPLATE
				expect(template.testRoot.n).to.equal(0)
				local validator = PlayerDataConstants.getValidator("testRoot")
				expect(validator).to.be.ok()
				expect(validator({ n = -1 })).to.equal(false)
			end)

			it("rejects a dotted key (a root key is bare)", function()
				expect(function()
					PlayerDataConstants.registerRootPath("bad.key", { n = 0 })
				end).to.throw()
			end)

			it("rejects the reserved skeleton keys", function()
				expect(function()
					PlayerDataConstants.registerRootPath("slots", {})
				end).to.throw()
				expect(function()
					PlayerDataConstants.registerRootPath("account", {})
				end).to.throw()
			end)

			it("rejects re-registering an already-registered root key", function()
				expect(function()
					PlayerDataConstants.registerRootPath("slotState", { active = 1 })
				end).to.throw()
			end)

			it("rejects a slice whose name collides with a root key", function()
				expect(function()
					PlayerDataConstants.registerSlotPath("slotState", { n = 0 })
				end).to.throw()
			end)
		end)

		describe("double registration", function()
			it("rejects registering the same slot slice twice", function()
				PlayerDataConstants.registerSlotPath("testDupe", { n = 0 })
				expect(function()
					PlayerDataConstants.registerSlotPath("testDupe", { n = 0 })
				end).to.throw()
			end)

			it("rejects registering the same account slice twice", function()
				PlayerDataConstants.registerAccountPath("testAccountDupe", { n = 0 })
				expect(function()
					PlayerDataConstants.registerAccountPath("testAccountDupe", { n = 0 })
				end).to.throw()
			end)

			-- The guard is keyed by PATTERN internally (`slots.*.x` vs `account.x`), so these two would
			-- BOTH register — yet they mirror into the SAME StateSyncServerStore atom (keyed by slice NAME) and the
			-- manifest's reader would silently decide the collision means the slot one. A slice name is
			-- unique across BOTH registrars, in either order.
			it("rejects a slot slice whose name is already an account slice", function()
				PlayerDataConstants.registerAccountPath("testCollideA", { n = 0 })
				expect(function()
					PlayerDataConstants.registerSlotPath("testCollideA", { n = 0 })
				end).to.throw()
			end)

			it("rejects an account slice whose name is already a slot slice", function()
				PlayerDataConstants.registerSlotPath("testCollideB", { n = 0 })
				expect(function()
					PlayerDataConstants.registerAccountPath("testCollideB", { n = 0 })
				end).to.throw()
			end)

			it("names the SLICE (not the internal pattern key) in the error", function()
				PlayerDataConstants.registerSlotPath("testMessage", { n = 0 })
				local ok, err = pcall(function()
					PlayerDataConstants.registerSlotPath("testMessage", { n = 0 })
				end)
				expect(ok).to.equal(false)
				expect(string.find(tostring(err), '"testMessage"', 1, true)).to.be.ok()
			end)
		end)

		describe("assertAllSlicesOwned", function()
			it("does not throw for the current tree (every declared field is registered)", function()
				expect(function()
					PlayerDataConstants.assertAllSlicesOwned()
				end).never.to.throw()
			end)

			it("throws when a slot field is declared but never registered", function()
				PlayerDataConstants.PROFILE_TEMPLATE.slots[1].bogusUnregisteredField = "x"
				local ok = pcall(function()
					expect(function()
						PlayerDataConstants.assertAllSlicesOwned()
					end).to.throw()
				end)
				PlayerDataConstants.PROFILE_TEMPLATE.slots[1].bogusUnregisteredField = nil
				expect(ok).to.equal(true)
			end)

			it("throws when an account field is declared but never registered", function()
				PlayerDataConstants.PROFILE_TEMPLATE.account.bogusUnregisteredField = "x"
				local ok = pcall(function()
					expect(function()
						PlayerDataConstants.assertAllSlicesOwned()
					end).to.throw()
				end)
				PlayerDataConstants.PROFILE_TEMPLATE.account.bogusUnregisteredField = nil
				expect(ok).to.equal(true)
			end)
		end)
	end)
end
