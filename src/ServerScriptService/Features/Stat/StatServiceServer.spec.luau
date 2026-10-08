--!strict
--[=[
	Unit tests for StatServiceServer.

	Mock strategy: identical to CurrencyServiceServer.spec — patch PlayerDataService's slot-aware
	surface (getActiveSlot / getSlotEpoch / _getSlotShell / dotted-path mutate) inside
	beforeAll/afterAll so this spec owns its mock window. StatsService captures the PlayerDataService
	table at require-time and looks methods up through it, so patching the table is seen immediately.

	Stats is a SLOT-SCOPED slice, so the fake profile is slot-shaped. StatsService is slot-BLIND
	(PlayerDataSliceSystem resolves the active slot), so tests assert against the ACTIVE slot via activeSlotOf(),
	and move which character is active with setActiveSlot() to prove slot isolation.

	Arithmetic anchors (StatConstants: XP_PER_LEVEL_FACTOR=25, MAX_LEVEL=30, POINTS_PER_LEVEL main=1
	sub=3; xpForLevel(L)=25*(L-1)*L/2):
	  xpForLevel: L1=0, L2=25, L3=75, L4=150, L5=250, L29=10150, L30=10875 (=maxTotalXp).
	  At level 5: earned main=4, sub=12. health(main): base 200, perPoint 5.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local PlayerDataPathUtils = require(PlayerDataServer.Utils.PlayerDataPathUtils)
local StatsService = require(ServerScriptService.Features.Stat.StatServiceServer)
local CharacterReplicationService = require(ServerScriptService.Features.Replication.ReplicationServiceServer)
local StatFormulas = require(ReplicatedStorage.Shared.Features.Stat.Utils.StatFormulas)
local StatConstants = require(ReplicatedStorage.Shared.Features.Stat.Data.StatConstants)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local Charm = require(ReplicatedStorage.Packages.Charm)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local ReplicationBodyObserverSystem =
	require(ServerScriptService.Features.Replication.Systems.ReplicationBodyObserverSystem)

-- A test-only armour item with a HEALTH statBonus — none of ItemContentRegistry.init()'s real fixtures bonus
-- "health" (chambered-helmet only bonuses rotEndurance), so the mirror-subscription tests below need
-- a dedicated fixture to exercise a Humanoid.MaxHealth change. Registered once per VM (ItemRegistry
-- rejects a second registration of the same type), same idempotency guard ItemContentRegistry.init() uses.
local TEST_HEALTH_CHARM_ITEM_TYPE = "test-health-charm"

-- ============================================================
-- Helpers
-- ============================================================
-- A whole slot-aware profile: every slot seeded with the stats slice's registered template default
-- ({ totalXp = 0, investments = {} }), matching what a freshly-created character gets, with the
-- value under test stamped into the ACTIVE slot (slot 1). The empty `equipment` field is carried for
-- uniformity with every other profile fixture in this branch (EquipmentServiceServer.spec,
-- PlayerDataServiceServer.spec) — getDerived reads equipment bonuses off StateSyncServerStore (see
-- StatServiceServer.getDerived's header), NOT off this mocked profile shape, so tests exercising
-- equipment bonuses seed StateSyncServerStore directly instead (see the "getDerived — equipment bonuses" and
-- "mirror subscription" describes below).
local function makeProfile(totalXp: number?, investments: any?)
	local slots = {}
	for index = 1, PlayerDataConstants.MAX_SLOTS do
		slots[index] = {
			currency = { jaku = 100 },
			inventory = { items = {} },
			stats = { totalXp = 0, investments = {} },
			equipment = { slots = {} },
			appearance = { cosmetics = {}, accessories = {}, body = {}, headType = "Uncovered", surfaces = {} },
			equippedTitle = {},
		}
	end
	slots[1].stats = { totalXp = totalXp or 0, investments = investments or {} }
	return {
		slotState = { active = 1, epoch = 1 },
		account = {
			unlockedSlots = { 1 },
			itemMint = { nextUid = 1 },
			entitlements = { cosmetics = {} },
			titles = { earned = {} },
		},
		slots = slots,
	}
end

-- applyToBody pushes the derived maximum health to the replication service (bodies are client-only; the
-- server holds health on the body). The spec captures those calls, patched in beforeAll.
local maxHealthCalls: { { userId: number, maxHealth: number } } = {}

local function lastMaxHealth(userId: number): number?
	for i = #maxHealthCalls, 1, -1 do
		if maxHealthCalls[i].userId == userId then
			return maxHealthCalls[i].maxHealth
		end
	end
	return nil
end

return function()
	describe("StatServiceServer", function()
		local _profiles: { [number]: any } = {}

		local _origGetActiveSlot
		local _origGetSlotEpoch
		local _origGetSlotShell
		local _origGetAccountShell
		local _origMutate
		local _origSetMaxHealth

		local function activeSlotOf(userId: number): any
			local profile = _profiles[userId]
			return profile.slots[profile.slotState.active]
		end

		local function setActiveSlot(userId: number, slotIndex: number)
			_profiles[userId].slotState.active = slotIndex
		end

		beforeAll(function()
			-- Idempotent: ItemContentRegistry.init() no-ops if already seeded in this VM (see its own header).
			ItemContentRegistry.init()
			if not ItemRegistry.isValidItemType(TEST_HEALTH_CHARM_ITEM_TYPE) then
				local healthCharm: PlayerDataTypes.ArmourDefinition = {
					name = "Test Health Charm",
					rarity = "common",
					kind = "armour",
					equipSlot = "pauldrons",
					statBonuses = { health = 20 },
				}
				ItemRegistry.register(TEST_HEALTH_CHARM_ITEM_TYPE, healthCharm)
			end

			_origGetActiveSlot = PlayerDataService.getActiveSlot
			_origGetSlotEpoch = PlayerDataService.getSlotEpoch
			_origGetSlotShell = PlayerDataService._getSlotShell
			_origGetAccountShell = PlayerDataService._getAccountShell
			_origMutate = PlayerDataService.mutate

			PlayerDataService.getActiveSlot = function(_self: any, userId: number): number?
				local profile = _profiles[userId]
				return if profile then profile.slotState.active else nil
			end

			PlayerDataService.getSlotEpoch = function(_self: any, userId: number): number?
				local profile = _profiles[userId]
				return if profile then profile.slotState.epoch else nil
			end

			PlayerDataService._getSlotShell = function(_self: any, userId: number, slotIndex: number, slice: string)
				local profile = _profiles[userId]
				local slot = profile and profile.slots[slotIndex]
				if not slot or slot[slice] == nil then
					return nil
				end
				return slot
			end

			PlayerDataService._getAccountShell = function(_self: any, userId: number, slice: string)
				local profile = _profiles[userId]
				if not profile or profile.account[slice] == nil then
					return nil
				end
				return profile.account
			end

			PlayerDataService.mutate = function(
				_self: any,
				userId: number,
				path: string,
				mutator: (data: any) -> boolean?
			): boolean
				local container: any = _profiles[userId]
				if not container then
					return false
				end
				local segments = PlayerDataPathUtils.segments(path)
				for index = 1, #segments - 1 do
					local segment = segments[index]
					container = container[tonumber(segment) or segment]
					if type(container) ~= "table" then
						return false
					end
				end
				local data = container[segments[#segments]]
				if data == nil then
					return false
				end
				local result = mutator(data)
				return result ~= false
			end

			_origSetMaxHealth = CharacterReplicationService.setMaxHealth
			CharacterReplicationService.setMaxHealth = function(_self: any, userId: number, maxHealth: number)
				table.insert(maxHealthCalls, { userId = userId, maxHealth = maxHealth })
			end
		end)

		afterAll(function()
			PlayerDataService.getActiveSlot = _origGetActiveSlot
			PlayerDataService.getSlotEpoch = _origGetSlotEpoch
			PlayerDataService._getSlotShell = _origGetSlotShell
			PlayerDataService._getAccountShell = _origGetAccountShell
			PlayerDataService.mutate = _origMutate
			CharacterReplicationService.setMaxHealth = _origSetMaxHealth
		end)

		beforeEach(function()
			_profiles = {}
			table.clear(maxHealthCalls)
		end)

		-- -------------------------------------------------------------------------
		describe("getStats", function()
			it("returns the stats slice for a loaded player", function()
				_profiles[1] = makeProfile(250, { health = 2 })
				local stats = StatsService:getStats(1)
				expect(stats).to.be.ok()
				expect(stats and stats.totalXp).to.equal(250)
				expect(stats and stats.investments.health).to.equal(2)
			end)

			it("returns nil when the profile is not loaded", function()
				expect(StatsService:getStats(999)).to.equal(nil)
			end)

			it("throws for a non-number userId", function()
				expect(function()
					StatsService:getStats("bad" :: any)
				end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("getProgress / getDerived / getUnspentPoints", function()
			it("derives progress from totalXp", function()
				_profiles[1] = makeProfile(250) -- level 5, xpForLevel(5)=250, so xpIntoLevel=0
				local progress = StatsService:getProgress(1)
				expect(progress).to.be.ok()
				expect(progress and progress.level).to.equal(5)
				expect(progress and progress.xpIntoLevel).to.equal(0)
				expect(progress and progress.xpToNext).to.equal(5 * 25) -- 125
			end)

			it("derives stat values (health = base 200 + points*5)", function()
				_profiles[1] = makeProfile(250, { health = 2 })
				local derived = StatsService:getDerived(1)
				expect(derived).to.be.ok()
				expect(derived and derived.health).to.equal(210) -- 200 + 2*5
			end)

			it("derives unspent points (earned - spent)", function()
				_profiles[1] = makeProfile(250, { health = 2 }) -- level 5: earned main=4, sub=12
				local unspent = StatsService:getUnspentPoints(1)
				expect(unspent).to.be.ok()
				expect(unspent and unspent.main).to.equal(2) -- 4 - 2
				expect(unspent and unspent.sub).to.equal(12) -- 12 - 0
			end)

			it("returns nil for all three when the profile is not loaded", function()
				expect(StatsService:getProgress(999)).to.equal(nil)
				expect(StatsService:getDerived(999)).to.equal(nil)
				expect(StatsService:getUnspentPoints(999)).to.equal(nil)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("addExperience", function()
			it("accumulates xp", function()
				_profiles[1] = makeProfile(0)
				local changed, leveledUp = StatsService:addExperience(1, 25)
				expect(changed).to.equal(true)
				expect(leveledUp).to.equal(true) -- level 1 -> 2
				expect(activeSlotOf(1).stats.totalXp).to.equal(25)

				changed, leveledUp = StatsService:addExperience(1, 10)
				expect(changed).to.equal(true)
				expect(leveledUp).to.equal(false) -- still level 2 (25..74)
				expect(activeSlotOf(1).stats.totalXp).to.equal(35)
			end)

			it("reports leveledUp true for a single grant crossing several levels", function()
				_profiles[1] = makeProfile(0)
				local changed, leveledUp = StatsService:addExperience(1, 75) -- level 1 -> 3
				expect(changed).to.equal(true)
				expect(leveledUp).to.equal(true)
				expect(activeSlotOf(1).stats.totalXp).to.equal(75)
			end)

			it("clamps at maxTotalXp and still reports the level-up on the clamping grant", function()
				_profiles[1] = makeProfile(10800) -- level 29 (10150..10874)
				local changed, leveledUp = StatsService:addExperience(1, 1000)
				expect(changed).to.equal(true)
				expect(leveledUp).to.equal(true) -- 29 -> 30
				expect(activeSlotOf(1).stats.totalXp).to.equal(StatFormulas.maxTotalXp()) -- 10875, clamped
			end)

			it("returns (false, false) and no change once already capped", function()
				_profiles[1] = makeProfile(StatFormulas.maxTotalXp()) -- 10875
				local changed, leveledUp = StatsService:addExperience(1, 500)
				expect(changed).to.equal(false)
				expect(leveledUp).to.equal(false)
				expect(activeSlotOf(1).stats.totalXp).to.equal(StatFormulas.maxTotalXp())
			end)

			it("returns (false, false) when the profile is not loaded", function()
				local changed, leveledUp = StatsService:addExperience(999, 25)
				expect(changed).to.equal(false)
				expect(leveledUp).to.equal(false)
			end)

			it("rejects non-positive and non-integer amounts", function()
				_profiles[1] = makeProfile(0)
				expect(function()
					StatsService:addExperience(1, 0)
				end).to.throw()
				expect(function()
					StatsService:addExperience(1, -5)
				end).to.throw()
				expect(function()
					StatsService:addExperience(1, 2.5)
				end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("invest", function()
			it("invests into a stat and decrements derived unspent points", function()
				_profiles[1] = makeProfile(250) -- level 5: main=4
				local ok, reason = StatsService:invest(1, "health", 2)
				expect(ok).to.equal(true)
				expect(reason).to.equal(nil)
				expect(activeSlotOf(1).stats.investments.health).to.equal(2)
				local unspent = StatsService:getUnspentPoints(1)
				expect(unspent and unspent.main).to.equal(2) -- 4 - 2
			end)

			it("refuses an unknown statId with a reason and writes nothing", function()
				_profiles[1] = makeProfile(250)
				local ok, reason = StatsService:invest(1, "nonsense", 1)
				expect(ok).to.equal(false)
				expect(typeof(reason)).to.equal("string")
				expect(activeSlotOf(1).stats.investments.nonsense).to.equal(nil)
			end)

			it("refuses when the pool lacks points AND writes nothing", function()
				_profiles[1] = makeProfile(25) -- level 2: main earned = 1
				local ok, reason = StatsService:invest(1, "health", 5) -- health is main; need 5, have 1
				expect(ok).to.equal(false)
				expect(typeof(reason)).to.equal("string")
				expect(activeSlotOf(1).stats.investments.health).to.equal(nil) -- nothing written
			end)

			it("accumulates onto an existing investment", function()
				_profiles[1] = makeProfile(250) -- level 5: main=4
				StatsService:invest(1, "health", 1)
				StatsService:invest(1, "health", 2)
				expect(activeSlotOf(1).stats.investments.health).to.equal(3)
				local unspent = StatsService:getUnspentPoints(1)
				expect(unspent and unspent.main).to.equal(1) -- 4 - 3
			end)

			it("throws for a non-positive points amount", function()
				_profiles[1] = makeProfile(250)
				expect(function()
					StatsService:invest(1, "health", 0)
				end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("respec", function()
			it("clears all investments and returns all points to unspent", function()
				-- level 5: earned main=4, sub=12. Build spends 2 main + 3 sub, both legal.
				_profiles[1] = makeProfile(250, { health = 2, strength = 3 })
				local cleared = StatsService:respec(1)
				expect(cleared).to.equal(true)
				expect(next(activeSlotOf(1).stats.investments)).to.equal(nil) -- table emptied IN PLACE
				local unspent = StatsService:getUnspentPoints(1)
				expect(unspent and unspent.main).to.equal(4) -- back to earned
				expect(unspent and unspent.sub).to.equal(12)
			end)

			it("returns false when there is nothing to clear", function()
				_profiles[1] = makeProfile(250, {})
				expect(StatsService:respec(1)).to.equal(false)
			end)
		end)

		-- -------------------------------------------------------------------------
		-- The registered validator is what makes the conservation invariant hold for ANY write into
		-- the slice — including a raw transaction() op via statsOp that never checks pointsUnspent.
		describe("stats validator", function()
			local function validator()
				local found = PlayerDataConstants.getValidator(PlayerDataPathUtils.forSlot("stats", 1))
				assert(found, "stats must register a data-layer validator")
				return found
			end

			it("accepts a maximal legal build (all earned points spent, xp at cap)", function()
				-- At level 30 (totalXp = maxTotalXp): earned main = 29, sub = 87.
				-- Spend every point across the pools' stats without exceeding either pool.
				local build = {
					health = 15,
					stamina = 14, -- main: 15 + 14 = 29 == earned main
					healthRegen = 87, -- sub: 87 == earned sub
				}
				expect(validator()({ totalXp = StatFormulas.maxTotalXp(), investments = build })).to.equal(true)
			end)

			it("rejects an unknown investment id", function()
				expect(validator()({ totalXp = 250, investments = { nonsense = 1 } })).to.equal(false)
			end)

			it("rejects a negative investment", function()
				expect(validator()({ totalXp = 250, investments = { health = -1 } })).to.equal(false)
			end)

			it("rejects a fractional totalXp", function()
				expect(validator()({ totalXp = 10.5, investments = {} })).to.equal(false)
			end)

			it("rejects a totalXp above the cap", function()
				expect(validator()({ totalXp = StatFormulas.maxTotalXp() + 1, investments = {} })).to.equal(false)
			end)

			it("rejects an over-invested build (spent exceeds earned)", function()
				-- level 5 earns 4 main points; spending 5 into a main stat over-invests.
				expect(validator()({ totalXp = 250, investments = { health = 5 } })).to.equal(false)
			end)
		end)

		-- -------------------------------------------------------------------------
		-- Re-proves the Phase 1 slot-isolation guarantee on a second domain: an invest on the active
		-- slot must not bleed into another character's build.
		describe("slot scoping", function()
			local USER_ID = 42

			it("keeps each character's build separate", function()
				_profiles[USER_ID] = makeProfile(250) -- slot 1: level 5

				StatsService:invest(USER_ID, "health", 2) -- active slot is 1
				expect(activeSlotOf(USER_ID).stats.investments.health).to.equal(2)

				setActiveSlot(USER_ID, 2)
				-- Slot 2 is a fresh character: template default, untouched by slot 1's invest.
				local stats = StatsService:getStats(USER_ID)
				expect(stats and stats.totalXp).to.equal(0)
				expect(stats and next(stats.investments)).to.equal(nil)

				-- Slot 1's stored build is likewise still intact.
				expect(_profiles[USER_ID].slots[1].stats.investments.health).to.equal(2)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("applyToBody", function()
			it("pushes the derived health as the body's maximum", function()
				_profiles[1] = makeProfile(250, { health = 2 }) -- derived health = 210
				StatsService:applyToBody(1)
				expect(lastMaxHealth(1)).to.equal(210)
			end)

			it("pushes nothing when the profile is not loaded", function()
				StatsService:applyToBody(424242)
				expect(lastMaxHealth(424242)).to.equal(nil)
			end)
		end)

		-- -------------------------------------------------------------------------
		-- getDerived now reads equipment bonuses off StateSyncServerStore's "equipment" mirror (see its own
		-- header for why it can't require EquipmentServiceServer), so these tests seed StateSyncServerStore
		-- directly rather than the mocked PlayerDataService profile.
		describe("getDerived — equipment bonuses", function()
			-- Cleared both before AND after each test: makes each test's expectations independent of
			-- execution order (rather than relying on the previous test's afterEach having run first).
			beforeEach(function()
				StateSyncServerStore.remove(1)
			end)

			afterEach(function()
				StateSyncServerStore.remove(1)
			end)

			it("folds in equipment's aggregated bonuses on top of investments", function()
				_profiles[1] = makeProfile(0, {})
				StateSyncServerStore.set(
					"equipment",
					1,
					{ slots = { helmet = { itemType = "chambered-helmet", uid = "h1" } } }
				)

				local derived = StatsService:getDerived(1)
				expect(derived).to.be.ok()
				expect(derived and derived.rotEndurance).to.equal(StatConstants.DEFINITIONS.rotEndurance.base + 8)
			end)

			it("returns the unmodified derived value when nothing is mirrored for the user", function()
				_profiles[1] = makeProfile(250, { health = 2 }) -- StateSyncServerStore has no "equipment" entry for 1
				local derived = StatsService:getDerived(1)
				expect(derived).to.be.ok()
				expect(derived and derived.health).to.equal(210) -- 200 + 2*5, no equipment bonus folded in
			end)
		end)

		-- -------------------------------------------------------------------------
		-- Exercises the EXACT subscription primitives start() wires — Charm.computed wrapping
		-- StateSyncServerStore.getterFor, Charm.subscribe calling applyToBody — against the real StateSyncServerStore/Charm
		-- machinery. start() wraps this in ReplicationServiceServer:observeBodies, which needs a live
		-- body (Studio checklist); this still proves the reactive wiring fires on a real atom write and is
		-- player-isolated.
		describe("mirror subscription (equipment)", function()
			beforeEach(function()
				StateSyncServerStore.remove(1)
				StateSyncServerStore.remove(2)
			end)

			afterEach(function()
				StateSyncServerStore.remove(1)
				StateSyncServerStore.remove(2)
			end)

			it("applyToBody re-runs when the equipment slice changes for a live body", function()
				_profiles[1] = makeProfile(0, {})
				local readEquipment = StateSyncServerStore.getterFor("equipment", 1)
				local equipmentSelector = Charm.computed(function(_previous)
					return readEquipment()
				end)
				local unsubscribe = Charm.subscribe(equipmentSelector, function()
					StatsService:applyToBody(1)
				end)

				-- The mirroring write PlayerDataService performs after a committed equip(): the only thing
				-- that calls applyToBody here is the subscription.
				StateSyncServerStore.set(
					"equipment",
					1,
					{ slots = { pauldrons = { itemType = TEST_HEALTH_CHARM_ITEM_TYPE, uid = "hc1" } } }
				)

				expect(lastMaxHealth(1)).to.equal(StatConstants.DEFINITIONS.health.base + 20) -- 200 + charm's bonus
				unsubscribe()
			end)

			it("does NOT re-apply for an unrelated player's equipment change", function()
				_profiles[1] = makeProfile(0, {})
				_profiles[2] = makeProfile(0, {})
				local readEquipmentB = StateSyncServerStore.getterFor("equipment", 2)
				local equipmentSelectorB = Charm.computed(function(_previous)
					return readEquipmentB()
				end)
				local unsubscribeB = Charm.subscribe(equipmentSelectorB, function()
					StatsService:applyToBody(2)
				end)

				StateSyncServerStore.set(
					"equipment",
					1,
					{ slots = { pauldrons = { itemType = TEST_HEALTH_CHARM_ITEM_TYPE, uid = "hc1" } } }
				)

				expect(lastMaxHealth(2)).to.equal(nil) -- no callback fired for player 2
				unsubscribeB()
			end)
		end)

		-- -------------------------------------------------------------------------
		-- getState's activeSubscriptions counter is a diagnostic over start()'s
		-- observeBodies callback (incremented at its top, decremented in its returned
		-- cleanup) — since start() itself needs a live body it cannot be driven
		-- from the spec environment (see "mirror subscription" above). Its exact rest value is
		-- environment-dependent: 0 on Open Cloud CI (no players), but 1+ in Studio Play mode, where the
		-- local player's body has already triggered the observer by the time this spec runs.
		-- So this only asserts the shape of the counter, not a specific value.
		describe("getState", function()
			it("reports a non-negative integer subscription count", function()
				local state = StatsService:getState()
				expect(type(state.activeSubscriptions)).to.equal("number")
				expect(state.activeSubscriptions >= 0).to.equal(true)
				expect(state.activeSubscriptions == math.floor(state.activeSubscriptions)).to.equal(true)
			end)
		end)

		-- -------------------------------------------------------------------------
		-- #32: start() must be undone by stop(). observeBodies is swapped for the REAL ReplicationBodyObserverSystem over fake
		-- signals, so start() can run here without a live body; the live service is restored afterwards.
		describe("start / stop", function()
			local origObserve
			local spawned, despawned

			beforeEach(function()
				StateSyncServerStore.remove(1)
				spawned, despawned = SignalTyped.new(), SignalTyped.new()
				local live = { { player = { UserId = 1, Name = "user1" }, epoch = 1 } }
				origObserve = CharacterReplicationService.observeBodies
				CharacterReplicationService.observeBodies = function(_self, callback)
					return ReplicationBodyObserverSystem.observe(spawned, despawned, function()
						return live
					end, callback)
				end
				StatsService:stop() -- drops the live service's own observer
				_profiles[1] = makeProfile(0, {})
			end)

			afterEach(function()
				StatsService:stop()
				CharacterReplicationService.observeBodies = origObserve
				StateSyncServerStore.remove(1)
				StatsService:start() -- the real observer again, for the rest of the suite
			end)

			it("stop tears down every body subscription; the counter returns to 0 by itself", function()
				StatsService:start()
				expect(StatsService:getState().activeSubscriptions).to.equal(1)
				StatsService:stop()
				expect(StatsService:getState().activeSubscriptions).to.equal(0)
			end)

			it("start, stop, start leaves one subscription per body and a change applies once", function()
				StatsService:start()
				StatsService:stop()
				StatsService:start()
				expect(StatsService:getState().activeSubscriptions).to.equal(1)
				table.clear(maxHealthCalls)
				StateSyncServerStore.set(
					"equipment",
					1,
					{ slots = { pauldrons = { itemType = TEST_HEALTH_CHARM_ITEM_TYPE, uid = "hc1" } } }
				)
				expect(#maxHealthCalls).to.equal(1)
			end)
		end)
	end)
end
