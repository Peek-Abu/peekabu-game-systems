--!strict
--[=[
	Unit tests for CustomizationServiceServer. Same strategy as the Inventory/Equipment/Bank specs:
	seed REAL fake profiles via `_setProfileForTesting` and drive the REAL mutate()/validator machinery,
	so the ownership gate and the data-layer invariants are exercised rather than mocked.

	The `observeBodies` default-backfill seam is NOT driven here — it needs a live body from
	ReplicationServiceServer (Studio checklist). Appearance is not applied server-side under
	client-only bodies; R4 applies it on the client, and the logic deciding WHAT to apply is fully specced
	in CustomizationPlanUtils.spec.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local sift = require(ReplicatedStorage.Packages.sift)

local function fakeSignal()
	local handlers: { [(...any) -> ()]: boolean } = {}
	return {
		Connect = function(_self, fn: (...any) -> ())
			handlers[fn] = true
			return {
				Disconnect = function()
					handlers[fn] = nil
				end,
			}
		end,
		Fire = function(_self, ...)
			local snapshot = {}
			for fn in handlers do
				table.insert(snapshot, fn)
			end
			for _, fn in snapshot do
				fn(...)
			end
		end,
	}
end

local function makeFakeProfile(data: any)
	return {
		Data = data,
		LastSavedData = sift.Dictionary.copyDeep(data),
		OnSave = fakeSignal(),
		OnAfterSave = fakeSignal(),
		IsActive = function()
			return true
		end,
		Save = function() end,
	}
end

local function makeProfileData(): PlayerDataTypes.PlayerProfile
	local slots: { PlayerDataTypes.PlayerSlot } = {}
	for index = 1, PlayerDataConstants.MAX_SLOTS do
		slots[index] = {
			currency = {},
			inventory = { items = {} },
			stats = { totalXp = 0, investments = {} },
			equipment = { slots = {} },
			bank = { items = {}, currency = {} },
			appearance = { cosmetics = {}, accessories = {}, body = {}, headType = "Uncovered", surfaces = {} },
			equippedTitle = {},
		}
	end
	return {
		_schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION,
		slotState = { active = 1, epoch = 1 },
		account = {
			unlockedSlots = { 1, 2 },
			itemMint = { nextUid = 1 },
			entitlements = { cosmetics = {} },
			titles = { earned = {} },
		},
		slots = slots,
	}
end

local function rgb(r: number, g: number, b: number): PlayerDataTypes.Color
	return { source = "rgb", r = r, g = g, b = b }
end

return function()
	describe("CustomizationServiceServer", function()
		local profiles: { [number]: any } = {}

		local function seed(userId: number)
			local profile = makeFakeProfile(makeProfileData())
			profiles[userId] = profile
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile
		end

		beforeEach(function()
			StateSyncPublicPlayerStore._resetVersionsForTesting() -- other spec files publish without resetting
		end)

		afterEach(function()
			for userId in profiles do
				PlayerDataService:_setProfileForTesting(userId, nil)
				StateSyncServerStore.remove(userId)
				StateSyncPublicPlayerStore.remove(userId)
			end
			profiles = {}
			CustomizationService:_resetPublicationsForTesting()
			StateSyncPublicPlayerStore._resetVersionsForTesting()
			-- Reset any scope override a test installed, so ordering cannot leak policy between tests.
			CustomizationService:_setEntitlementScopeForTesting("accessory", nil)
		end)

		describe("equipCosmetic", function()
			it("equips a FREE cosmetic and persists it", function()
				seed(1)
				local ok = CustomizationService:equipCosmetic(1, "eyebrows", "Eyebrows2")
				expect(ok).to.equal(true)

				local appearance = CustomizationService:getAppearance(1)
				expect(appearance.cosmetics.eyebrows).to.be.ok()
				expect(appearance.cosmetics.eyebrows.id).to.equal("Eyebrows2")
			end)

			it("refuses an unregistered cosmetic and writes nothing", function()
				seed(1)
				local ok, reason = CustomizationService:equipCosmetic(1, "hair", "Hair999")
				expect(ok).to.equal(false)
				expect(string.find(reason, "Hair999") ~= nil).to.equal(true)
				expect(CustomizationService:getAppearance(1).cosmetics.eyebrows).to.equal(nil)
			end)

			it("refuses the accessory category (accessories are slot-based)", function()
				seed(1)
				local ok = CustomizationService:equipCosmetic(1, "accessory", "WizardHat")
				expect(ok).to.equal(false)
			end)

			it("clears a cosmetic back to none", function()
				seed(1)
				CustomizationService:equipCosmetic(1, "eyebrows", "Eyebrows2")
				expect(CustomizationService:clearCosmetic(1, "eyebrows")).to.equal(true)
				expect(CustomizationService:getAppearance(1).cosmetics.eyebrows).to.equal(nil)
			end)
		end)

		describe("ownership gate", function()
			it("refuses a LOCKABLE cosmetic that is not unlocked, and writes nothing", function()
				seed(1)
				local ok, reason = CustomizationService:equipAccessory(1, 1, "WizardHat")
				expect(ok).to.equal(false)
				expect(string.find(reason, "locked") ~= nil).to.equal(true)
				expect(#CustomizationService:getAppearance(1).accessories).to.equal(0)
			end)

			it("allows the same cosmetic once unlocked", function()
				seed(1)
				expect(CustomizationService:unlockCosmetic(1, "accessory", "WizardHat")).to.equal(true)
				expect(CustomizationService:equipAccessory(1, 1, "WizardHat")).to.equal(true)
				expect(CustomizationService:getAppearance(1).accessories[1].id).to.equal("WizardHat")
			end)

			it("allows a FREE accessory with no unlock at all", function()
				seed(1)
				expect(CustomizationService:equipAccessory(1, 1, "FishingHat")).to.equal(true)
			end)

			it("refuses unlocking a FREE cosmetic (free ids are never stored)", function()
				seed(1)
				local ok, reason = CustomizationService:unlockCosmetic(1, "accessory", "FishingHat")
				expect(ok).to.equal(false)
				expect(string.find(reason, "free") ~= nil).to.equal(true)
			end)

			it("is idempotent: unlocking twice reports no change", function()
				seed(1)
				expect(CustomizationService:unlockCosmetic(1, "accessory", "Tabard")).to.equal(true)
				local ok, reason = CustomizationService:unlockCosmetic(1, "accessory", "Tabard")
				expect(ok).to.equal(false)
				expect(reason).to.equal("already unlocked")
			end)

			-- Regression: a no-profile bail used to be reported as "already unlocked", telling an
			-- operator the grant was effectively fine when it had actually failed.
			it("reports no-profile as a LOAD failure, never as 'already unlocked'", function()
				local ok, reason = CustomizationService:unlockCosmetic(999, "accessory", "Tabard")
				expect(ok).to.equal(false)
				expect(reason).to.never.equal("already unlocked")
				expect(string.find(reason, "profile") ~= nil).to.equal(true)
			end)
		end)

		-- Guard.slotIndex is an ASSERT (the numeric shape of a slot is a developer contract), so a
		-- malformed index throws rather than returning a reason — matching invest/equip.
		describe("slot index guarding", function()
			it("throws for an out-of-range or non-integer accessory slot", function()
				seed(1)
				expect(function()
					CustomizationService:equipAccessory(1, 99, "FishingHat")
				end).to.throw()
				expect(function()
					CustomizationService:equipAccessory(1, 1.5, "FishingHat")
				end).to.throw()
				expect(function()
					CustomizationService:clearAccessory(1, 0)
				end).to.throw()
			end)
		end)

		-- Guards the extensibility seam (design spec, Decision 1a): the ownership check must route
		-- through the category's SCOPE POLICY, not assume account-wide. Flipping a category to "slot"
		-- must change where the check looks — proven here by it refusing rather than silently
		-- consulting the account store, without a per-slot entitlement store existing yet.
		describe("entitlement scope policy", function()
			it("routes the ownership check through the category's scope", function()
				seed(1)
				CustomizationService:unlockCosmetic(1, "accessory", "WizardHat")
				expect(CustomizationService:equipAccessory(1, 1, "WizardHat")).to.equal(true)

				CustomizationService:_setEntitlementScopeForTesting("accessory", "slot")
				local ok, reason = CustomizationService:equipAccessory(1, 2, "WizardHat")
				expect(ok).to.equal(false)
				expect(string.find(reason, "slot") ~= nil).to.equal(true)
			end)
		end)

		-- The registration default (not the spec's own fixture) is what new profiles actually get, so
		-- this asserts against the sealed PROFILE_TEMPLATE that CustomizationServiceServer stamped.
		describe("new-character defaults", function()
			it("seeds a starting hair so nobody spawns bald", function()
				local template = PlayerDataConstants.PROFILE_TEMPLATE.slots[1].appearance
				expect(template.headType).to.equal("Uncovered")
				expect(template.cosmetics.hair).to.be.ok()
				expect(template.cosmetics.hair.id).to.equal("Hair9")
			end)
		end)

		describe("setHeadType", function()
			it("switches the head type", function()
				seed(1)
				expect(CustomizationService:setHeadType(1, "Covered")).to.equal(true)
				expect(CustomizationService:getAppearance(1).headType).to.equal("Covered")
			end)

			it("refuses an unregistered head type and writes nothing", function()
				seed(1)
				local before = CustomizationService:getAppearance(1).headType
				local ok, reason = CustomizationService:setHeadType(1, "Partial")
				expect(ok).to.equal(false)
				expect(string.find(reason, "not a registered head type") ~= nil).to.equal(true)
				expect(CustomizationService:getAppearance(1).headType).to.equal(before)
			end)

			it("reports no change when already in that mode", function()
				seed(1)
				CustomizationService:setHeadType(1, "Covered")
				local ok, reason = CustomizationService:setHeadType(1, "Covered")
				expect(ok).to.equal(false)
				expect(string.find(reason, "already") ~= nil).to.equal(true)
			end)

			it("leaves compatible cosmetics alone when switching", function()
				seed(1)
				CustomizationService:equipCosmetic(1, "eyebrows", "Eyebrows2")
				expect(CustomizationService:setHeadType(1, "Covered")).to.equal(true)
				expect(CustomizationService:getAppearance(1).cosmetics.eyebrows.id).to.equal("Eyebrows2")
			end)

			-- Hair is STRICTLY partitioned by head type (5b content pass), so a switch always
			-- invalidates the equipped hair. Auto-clearing rather than refusing is deliberate: the
			-- player asked for the head change (design spec, Decision 3). Head type is a MENU-time
			-- choice, so losing the hair is a re-pick in a list already filtered to the new mode.
			it("SUBSTITUTES the new mode's default hair rather than leaving the player bald", function()
				seed(1)
				CustomizationService:setHeadType(1, "Covered")
				expect(CustomizationService:equipCosmetic(1, "hair", "Hair2")).to.equal(true)

				local ok, reason = CustomizationService:setHeadType(1, "Uncovered")
				expect(ok).to.equal(true)
				-- Uncovered declares a default, so the invalid Hair2 is replaced, not just removed.
				expect(CustomizationService:getAppearance(1).cosmetics.hair.id).to.equal("Hair9")
				expect(string.find(reason, "Hair9", 1, true) ~= nil).to.equal(true)
			end)

			it("clears with NO substitute when the target mode declares no default", function()
				seed(1)
				expect(CustomizationService:equipCosmetic(1, "hair", "Hair9")).to.equal(true)

				-- Covered deliberately has no default hair, so this one goes bald.
				expect(CustomizationService:setHeadType(1, "Covered")).to.equal(true)
				expect(CustomizationService:getAppearance(1).cosmetics.hair).to.equal(nil)
			end)

			-- Bald is never a resting state where the target mode declares a default. This is the round
			-- trip: Covered has no default so the player ends up bald there, but switching BACK must
			-- restore hair even though this switch cleared nothing of its own.
			it("re-hairs a player who arrives bald from a mode with no default", function()
				seed(1)
				expect(CustomizationService:setHeadType(1, "Covered")).to.equal(true)
				expect(CustomizationService:getAppearance(1).cosmetics.hair).to.equal(nil)

				expect(CustomizationService:setHeadType(1, "Uncovered")).to.equal(true)
				expect(CustomizationService:getAppearance(1).cosmetics.hair.id).to.equal("Hair9")
			end)

			it("fills an empty defaulted category even when the switch cleared nothing", function()
				seed(1)
				CustomizationService:clearCosmetic(1, "hair")
				expect(CustomizationService:getAppearance(1).cosmetics.hair).to.equal(nil)

				-- Switching to a mode WITH a default re-hairs them; nothing was cleared by this switch.
				CustomizationService:setHeadType(1, "Covered")
				expect(CustomizationService:setHeadType(1, "Uncovered")).to.equal(true)
				expect(CustomizationService:getAppearance(1).cosmetics.hair.id).to.equal("Hair9")
			end)

			it("leaves unrestricted accessories untouched by a switch", function()
				seed(1)
				CustomizationService:setHeadType(1, "Covered")
				CustomizationService:equipCosmetic(1, "hair", "Hair2")
				CustomizationService:equipAccessory(1, 1, "FishingHat")

				expect(CustomizationService:setHeadType(1, "Uncovered")).to.equal(true)
				-- The accessory is unrestricted, so it SURVIVES; only the hair is swapped.
				expect(CustomizationService:getAppearance(1).accessories[1].id).to.equal("FishingHat")
				expect(CustomizationService:getAppearance(1).cosmetics.hair.id).to.equal("Hair9")
			end)

			-- The cleared write and the head-type write happen in ONE mutation, so the validator never
			-- sees the incompatible intermediate state — if it did, the whole switch would roll back.
			it("commits the switch even though the pre-clear state would be invalid", function()
				seed(1)
				CustomizationService:setHeadType(1, "Covered")
				CustomizationService:equipCosmetic(1, "hair", "Hair2")
				expect(CustomizationService:setHeadType(1, "Uncovered")).to.equal(true)
				expect(CustomizationService:getAppearance(1).headType).to.equal("Uncovered")
			end)
		end)

		describe("setSoulColor", function()
			it("stores a single-hue and a multi-hue soul colour", function()
				seed(1)
				expect(CustomizationService:setSoulColor(1, "blue")).to.equal(true)
				expect(CustomizationService:getAppearance(1).soulColor).to.equal("blue")

				expect(CustomizationService:setSoulColor(1, "blue-green")).to.equal(true)
				expect(CustomizationService:getAppearance(1).soulColor).to.equal("blue-green")
			end)

			it("refuses an unregistered id and writes nothing", function()
				seed(1)
				local ok, reason = CustomizationService:setSoulColor(1, "chartreuse")
				expect(ok).to.equal(false)
				expect(string.find(reason, "chartreuse") ~= nil).to.equal(true)
				expect(CustomizationService:getAppearance(1).soulColor).to.equal(nil)
			end)

			it("clears when passed nil", function()
				seed(1)
				CustomizationService:setSoulColor(1, "blue")
				expect(CustomizationService:setSoulColor(1, nil)).to.equal(true)
				expect(CustomizationService:getAppearance(1).soulColor).to.equal(nil)
			end)

			it("reports no change when already that value", function()
				seed(1)
				CustomizationService:setSoulColor(1, "blue")
				local ok, reason = CustomizationService:setSoulColor(1, "blue")
				expect(ok).to.equal(false)
				expect(string.find(reason, "already") ~= nil).to.equal(true)
			end)
		end)

		describe("setSurface", function()
			it("stores a pattern and texture on a registered channel", function()
				seed(1)
				expect(CustomizationService:setSurface(1, "backpack1", "Back2", "Fern")).to.equal(true)
				local surface = CustomizationService:getAppearance(1).surfaces.backpack1
				expect(surface.pattern).to.equal("Back2")
				expect(surface.texture).to.equal("Fern")
			end)

			it("refuses an unregistered channel", function()
				seed(1)
				local ok, reason = CustomizationService:setSurface(1, "kneepads", "Skin2")
				expect(ok).to.equal(false)
				expect(string.find(reason, "kneepads") ~= nil).to.equal(true)
			end)

			it("is refused by the validator for a pattern from the wrong catalog", function()
				seed(1)
				-- Back2 is a backpack pattern, not a clothing one — the data layer is the backstop.
				expect(CustomizationService:setSurface(1, "clothing1", "Back2")).to.equal(false)
				expect(CustomizationService:getAppearance(1).surfaces.clothing1).to.equal(nil)
			end)

			it("clears the channel when both aspects are nil", function()
				seed(1)
				CustomizationService:setSurface(1, "backpack1", "Back2", "Fern")
				expect(CustomizationService:setSurface(1, "backpack1")).to.equal(true)
				expect(CustomizationService:getAppearance(1).surfaces.backpack1).to.equal(nil)
			end)
		end)

		describe("setBodyColor", function()
			it("stores a free rgb on a registered channel", function()
				seed(1)
				expect(CustomizationService:setBodyColor(1, "color1", rgb(10, 20, 30))).to.equal(true)
				expect(CustomizationService:getAppearance(1).body.color1.r).to.equal(10)
			end)

			it("refuses an unregistered channel", function()
				seed(1)
				local ok, reason = CustomizationService:setBodyColor(1, "elbows", rgb(1, 2, 3))
				expect(ok).to.equal(false)
				expect(string.find(reason, "elbows") ~= nil).to.equal(true)
			end)

			-- The data-layer validator (not the method) is the real backstop: an out-of-range component
			-- is rejected and rolled back no matter which path built it.
			it("is refused by the slice validator for an out-of-range component", function()
				seed(1)
				local ok, reason = CustomizationService:setBodyColor(1, "color1", rgb(999, 0, 0))
				expect(ok).to.equal(false)
				expect(CustomizationService:getAppearance(1).body.color1).to.equal(nil)
				-- The VALIDATOR's message must reach the caller, not a generic "no profile loaded":
				-- dropping mutate's second return value used to hide the actual cause.
				expect(string.find(reason, "255", 1, true) ~= nil).to.equal(true)
			end)
		end)

		describe("scoping", function()
			it("keeps appearance PER-SLOT while entitlements are shared account-wide", function()
				local profile = seed(1)
				CustomizationService:unlockCosmetic(1, "accessory", "WizardHat")
				CustomizationService:equipCosmetic(1, "eyebrows", "Eyebrows2")

				-- Switch the active slot the way the data layer sees it, then observe slot 2.
				profile.Data.slotState.active = 2

				expect(CustomizationService:getAppearance(1).cosmetics.eyebrows).to.equal(nil)
				-- ...but the account-wide unlock is still there, so the lockable id equips on slot 2 too.
				expect(CustomizationService:equipAccessory(1, 1, "WizardHat")).to.equal(true)

				profile.Data.slotState.active = 1
				expect(CustomizationService:getAppearance(1).cosmetics.eyebrows.id).to.equal("Eyebrows2")
			end)
		end)

		describe("public-slice appearance publishing", function()
			it("publishes the default look with version 1 on first spawn", function()
				seed(1)
				CustomizationService:_onBodySpawnForTesting(1)
				local entry = StateSyncPublicPlayerStore.get(1)
				expect(entry).to.be.ok()
				expect(entry.appearanceVersion).to.equal(1)
				expect(entry.appearance.headType).to.equal("Uncovered")
			end)

			it("increments the version on every validated appearance change", function()
				seed(1)
				CustomizationService:_onBodySpawnForTesting(1)
				CustomizationService:equipCosmetic(1, "eyebrows", "Eyebrows2")
				expect(StateSyncPublicPlayerStore.get(1).appearanceVersion).to.equal(2)
				expect(StateSyncPublicPlayerStore.get(1).appearance.cosmetics.eyebrows.id).to.equal("Eyebrows2")
				CustomizationService:setBodyColor(1, "color1", rgb(10, 20, 30))
				expect(StateSyncPublicPlayerStore.get(1).appearanceVersion).to.equal(3)
				expect(StateSyncPublicPlayerStore.get(1).appearance.body.color1.r).to.equal(10)
				CustomizationService:clearCosmetic(1, "eyebrows")
				expect(StateSyncPublicPlayerStore.get(1).appearanceVersion).to.equal(4)
				expect(StateSyncPublicPlayerStore.get(1).appearance.cosmetics.eyebrows).to.equal(nil)
			end)

			it("publishes a copy: mutating the profile's live appearance afterwards changes nothing", function()
				local profile = seed(1)
				CustomizationService:_onBodySpawnForTesting(1)
				-- Snapshot the VALUES: comparing against the published table itself would be tautological.
				local published = StateSyncPublicPlayerStore.get(1).appearance
				local headTypeBefore = published.headType
				local hairBefore = published.cosmetics.hair.id -- the spawn default
				profile.Data.slots[1].appearance.headType = "Covered"
				profile.Data.slots[1].appearance.cosmetics.hair = { id = "Hair2", colors = {} }
				expect(StateSyncPublicPlayerStore.get(1).appearance.headType).to.equal(headTypeBefore)
				expect(StateSyncPublicPlayerStore.get(1).appearance.cosmetics.hair.id).to.equal(hairBefore)
				expect(hairBefore).never.to.equal("Hair2")
			end)

			it("publishes again with a new version on a slot switch", function()
				local profile = seed(1)
				CustomizationService:_onBodySpawnForTesting(1)
				profile.Data.slotState.active = 2
				CustomizationService:_onBodySpawnForTesting(1)
				expect(StateSyncPublicPlayerStore.get(1).appearanceVersion).to.equal(2)
				expect(StateSyncPublicPlayerStore.get(1).appearance.headType).to.equal("Uncovered")
			end)

			it("does not bump the version on a plain respawn (same slot, nothing to fill)", function()
				seed(1)
				CustomizationService:_onBodySpawnForTesting(1)
				CustomizationService:equipCosmetic(1, "eyebrows", "Eyebrows2")
				local version = StateSyncPublicPlayerStore.get(1).appearanceVersion
				CustomizationService:_onBodySpawnForTesting(1)
				expect(StateSyncPublicPlayerStore.get(1).appearanceVersion).to.equal(version)
			end)

			-- Found in staging: a player who left and rejoined the same server was drawn bald and barefoot
			-- by everyone else, because the leave dropped the public entry but the "already published" record
			-- survived, so the rejoin's first spawn published nothing and viewers dressed the empty placeholder.
			it("publishes again after the player left and rejoined the same server", function()
				seed(1)
				CustomizationService:_onBodySpawnForTesting(1)
				StateSyncPublicPlayerStore.remove(1) -- the leave (ReplicationServiceServer drops the entry)
				CustomizationService:_onBodySpawnForTesting(1) -- the rejoin's first spawn, same slot
				local entry = StateSyncPublicPlayerStore.get(1)
				expect(entry).to.be.ok()
				expect(entry.appearanceVersion).to.equal(2) -- the sequence continues across the leave
				expect(entry.appearance.cosmetics.hair).to.be.ok()
				expect(entry.appearance.cosmetics.shoes).to.be.ok()
			end)

			-- Found in review of the staging fixes: the body can spawn before the profile loads (the client's
			-- Ready does not wait for data; a same-server rejoin waits on the old session's lock), and then the
			-- spawn has no look to publish. The profile's arrival must publish it.
			it("publishes the real look when the profile loads after the body spawned", function()
				StateSyncPublicPlayerStore.set(1, { health = 100, maxHealth = 100 }) -- the join's vitals placeholder
				CustomizationService:_onBodySpawnForTesting(1) -- no profile yet: nothing to publish
				expect(StateSyncPublicPlayerStore.get(1).appearanceVersion).to.equal(0)
				seed(1)
				CustomizationService:_onProfileLoadedForTesting(1)
				local entry = StateSyncPublicPlayerStore.get(1)
				expect(entry.appearanceVersion).to.equal(1)
				expect(entry.appearance.cosmetics.hair).to.be.ok()
				expect(entry.appearance.cosmetics.shoes).to.be.ok()
			end)

			it("publishes nothing on a profile load before the player has a public entry", function()
				seed(1)
				CustomizationService:_onProfileLoadedForTesting(1)
				expect(StateSyncPublicPlayerStore.get(1)).to.equal(nil)
			end)

			it("does not republish on a profile load once a look is published", function()
				seed(1)
				CustomizationService:_onBodySpawnForTesting(1)
				CustomizationService:_onProfileLoadedForTesting(1)
				expect(StateSyncPublicPlayerStore.get(1).appearanceVersion).to.equal(1)
			end)

			it("publishes over a vitals-only placeholder entry on the rejoin's first spawn", function()
				seed(1)
				CustomizationService:_onBodySpawnForTesting(1)
				StateSyncPublicPlayerStore.remove(1)
				StateSyncPublicPlayerStore.set(1, { health = 100, maxHealth = 100 }) -- vitals land before the spawn
				expect(StateSyncPublicPlayerStore.get(1).appearanceVersion).to.equal(0)
				CustomizationService:_onBodySpawnForTesting(1)
				expect(StateSyncPublicPlayerStore.get(1).appearanceVersion).to.equal(2)
				expect(StateSyncPublicPlayerStore.get(1).appearance.cosmetics.shoes).to.be.ok()
			end)
		end)
	end)
end
