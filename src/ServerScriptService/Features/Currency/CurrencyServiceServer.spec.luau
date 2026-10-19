--!strict
--[=[
	Unit tests for CurrencyServiceServer.
	
	Mock strategy: patch PlayerDataService methods inside beforeAll/afterAll
	so each spec file owns its mock window and doesn't clash with other specs
	that also patch PlayerDataService (e.g. InventoryServiceServer.spec).

	Patching the shared table works because CurrencyServiceServer captures
	the PlayerDataService table reference at require-time, and method lookups
	go through the table — so mutating the table's methods is reflected immediately.

	Currency is a SLOT-SCOPED slice, so the fake profile is slot-shaped and the mocks reproduce the
	slot-aware read/write surface (getActiveSlot / _getSlotShell / _getAccountShell / a dotted-path
	mutate). CurrencyService itself is deliberately slot-BLIND — PlayerDataSliceSystem resolves the active slot —
	so these tests only ever assert against the ACTIVE slot, via activeSlotOf().
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local PlayerDataPathUtils = require(PlayerDataServer.Utils.PlayerDataPathUtils)
local CurrencyService = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)

-- ============================================================
-- Helpers
-- ============================================================
-- A whole slot-aware profile: every slot (PlayerDataConstants.MAX_SLOTS of them) seeded with the
-- slice's registered shape (see CurrencyServiceServer's PlayerDataSliceSystem.registerSlot call), with
-- a distinct credits balance of 100 on the other slots so slot isolation shows, and the value under test
-- stamped into the ACTIVE slot.
local function makeProfile(credits: number?)
	local slots = {}
	for index = 1, PlayerDataConstants.MAX_SLOTS do
		slots[index] = {
			currency = { credits = 100 },
			inventory = { items = {} },
			equippedTitle = {},
		}
	end
	slots[1].currency = { credits = credits or 0 }
	return {
		slotState = { active = 1, epoch = 1 },
		account = {
			itemMint = { nextUid = 1 },
			premium = { balance = 0 },
			receipts = { ids = {} },
			firstSeen = { at = 0 },
			entitlements = { owned = {} },
			settings = { values = {} },
			dailyReward = { lastDay = 0, streak = 0 },
			rank = { season = "mvp-1", xp = 0, lastAwardedRunId = "" },
			titles = { earned = {} },
		},
		slots = slots,
	}
end

return function()
	-- Multi-slot behaviour is dormant while MAX_SLOTS = 1; these re-enable when a game raises it.
	local describeMultiSlot = if PlayerDataConstants.MAX_SLOTS >= 2 then describe else describeSKIP

	describe("CurrencyServiceServer", function()
		-- In-memory store, reset per test
		local _profiles: { [number]: any } = {}
		-- Counts the mocked mutate calls (one per currency-slice write) so a test can pin "one write".
		local writes = 0

		-- Save originals so we can restore after this spec
		local _origGetActiveSlot
		local _origGetSlotEpoch
		local _origGetSlotShell
		local _origGetAccountShell
		local _origMutate

		-- Change events collected from CurrencyService.changed.
		local events: { CurrencyConstants.CurrencyChange } = {}
		local changedConnection

		-- The slot the service's reads and writes must land in.
		local function activeSlotOf(userId: number): any
			local profile = _profiles[userId]
			return profile.slots[profile.slotState.active]
		end

		-- Switches which slot is "active" for a fake profile -- mirrors the effect of a game's
		-- slot-switch flow without needing one to exist. CurrencyService is slot-blind, so this is the
		-- only lever these tests have to move which slot its reads/writes land on.
		local function setActiveSlot(userId: number, slotIndex: number)
			_profiles[userId].slotState.active = slotIndex
		end

		beforeAll(function()
			_origGetActiveSlot = PlayerDataService.getActiveSlot
			_origGetSlotEpoch = PlayerDataService.getSlotEpoch
			_origGetSlotShell = PlayerDataService._getSlotShell
			_origGetAccountShell = PlayerDataService._getAccountShell
			_origMutate = PlayerDataService.mutate

			PlayerDataService.getActiveSlot = function(_self: any, userId: number): number?
				local profile = _profiles[userId]
				return if profile then profile.slotState.active else nil
			end

			-- PlayerDataSliceSystem.op stamps the op with the player's current slot epoch (and asserts it is
			-- non-nil), so currencyOp needs this mocked or every op-minting test below would throw.
			PlayerDataService.getSlotEpoch = function(_self: any, userId: number): number?
				local profile = _profiles[userId]
				return if profile then profile.slotState.epoch else nil
			end

			-- PlayerDataSliceSystem.get reads through _getSlotShell (the per-slice snapshot path). The mock
			-- mirrors its nil contract (unloaded profile / missing slot / missing slice) and returns
			-- the slot directly — the reader projects the slice out of it, same as production.
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

			-- Walks the DOTTED path as PlayerDataService.resolvePath does — including tonumber'ing the
			-- slot segment, because `slots` is an array and a string key would silently miss.
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
				writes += 1
				local result = mutator(data)
				return result ~= false
			end
		end)

		afterAll(function()
			PlayerDataService.getActiveSlot = _origGetActiveSlot
			PlayerDataService.getSlotEpoch = _origGetSlotEpoch
			PlayerDataService._getSlotShell = _origGetSlotShell
			PlayerDataService._getAccountShell = _origGetAccountShell
			PlayerDataService.mutate = _origMutate
		end)

		beforeEach(function()
			_profiles = {}
			events = {}
			writes = 0
			changedConnection = CurrencyService.changed:Connect(function(change)
				table.insert(events, change)
			end)
		end)

		afterEach(function()
			changedConnection:Disconnect()
		end)

		-- -------------------------------------------------------------------------
		describe("change events", function()
			it("reports a source with the amount, ending balance and reason", function()
				_profiles[1] = makeProfile(100)
				expect(CurrencyService:addCurrency(1, "credits", 40, "admin")).to.equal(true)
				expect(#events).to.equal(1)
				local e = events[1]
				expect(e.userId).to.equal(1)
				expect(e.currency).to.equal("credits")
				expect(e.flow).to.equal("source")
				expect(e.amount).to.equal(40)
				expect(e.balance).to.equal(140)
				expect(e.reason).to.equal("admin")
			end)

			it("reports a sink on remove and defaults the reason to other", function()
				_profiles[1] = makeProfile(100)
				CurrencyService:removeCurrency(1, "credits", 30)
				expect(events[1].flow).to.equal("sink")
				expect(events[1].amount).to.equal(30)
				expect(events[1].balance).to.equal(70)
				expect(events[1].reason).to.equal("other")
			end)

			it("reports setCurrency as the delta with the given reason", function()
				_profiles[1] = makeProfile(100)
				CurrencyService:setCurrency(1, "credits", 60, "admin")
				expect(events[1].flow).to.equal("sink")
				expect(events[1].amount).to.equal(40)
				expect(events[1].balance).to.equal(60)
				expect(events[1].reason).to.equal("admin")
			end)

			it("reports nothing for a refused or no-change write", function()
				_profiles[1] = makeProfile(100)
				CurrencyService:removeCurrency(1, "credits", 500)
				CurrencyService:setCurrency(1, "credits", 100)
				expect(#events).to.equal(0)
			end)

			it("grants Credits and Gloom in one write, one event each", function()
				_profiles[1] = makeProfile(0)
				expect(CurrencyService:grant(1, { credits = 760, gloom = 340 }, "shiftPay")).to.equal(true)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(760)
				expect(CurrencyService:getCurrencyAmount(1, "gloom")).to.equal(340)
				expect(#events).to.equal(2)
				expect(writes).to.equal(1) -- the mutate stub counts data-layer writes
			end)

			it("reports the clamped delta at the cap, and nothing once fully absorbed", function()
				_profiles[1] = makeProfile(CurrencyConstants.MAX_CURRENCY - 10)
				CurrencyService:grant(1, { credits = 50 }, "shiftPay")
				expect(events[1].amount).to.equal(10)
				expect(events[1].balance).to.equal(CurrencyConstants.MAX_CURRENCY)
				expect(CurrencyService:grant(1, { credits = 50 }, "shiftPay")).to.equal(false)
				expect(#events).to.equal(1)
			end)

			it("grants nothing for all-zero amounts and refuses bad input", function()
				_profiles[1] = makeProfile(0)
				expect(CurrencyService:grant(1, { credits = 0, gloom = 0 }, "shiftPay")).to.equal(false)
				expect(function()
					CurrencyService:grant(1, { credits = -1 }, "shiftPay")
				end).to.throw()
				expect(function()
					CurrencyService:grant(1, { coins = 1 } :: any, "shiftPay")
				end).to.throw()
				expect(#events).to.equal(0)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("fresh save", function()
			it("starts with 0 Gloom and 0 Credits", function()
				local currency = PlayerDataConstants.PROFILE_TEMPLATE.slots[1].currency
				expect((currency :: any).gloom).to.equal(0)
				expect((currency :: any).credits).to.equal(0)
				expect((currency :: any).coins).to.equal(nil)
			end)
		end)

		describe("getCurrency", function()
			it("should return currency table for loaded player", function()
				_profiles[1] = makeProfile(100)
				local currency = CurrencyService:getCurrency(1)
				expect(currency).to.be.ok()
				expect(currency and (currency :: any).credits).to.equal(100)
			end)

			it("should return nil when profile is not loaded", function()
				expect(CurrencyService:getCurrency(999)).to.equal(nil)
			end)

			it("should throw for non-number userId", function()
				expect(function()
					CurrencyService:getCurrency("bad" :: any)
				end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("getCurrencyAmount", function()
			it("should return correct credits amount", function()
				_profiles[1] = makeProfile(250)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(250)
			end)

			it("should return 0 when profile is not loaded", function()
				expect(CurrencyService:getCurrencyAmount(999, "credits")).to.equal(0)
			end)

			it("should throw for invalid currency type", function()
				_profiles[1] = makeProfile(100)
				expect(function()
					CurrencyService:getCurrencyAmount(1, "diamonds" :: any)
				end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("hasCurrency", function()
			it("should return true when player has enough", function()
				_profiles[1] = makeProfile(100)
				expect(CurrencyService:hasCurrency(1, "credits", 50)).to.equal(true)
				expect(CurrencyService:hasCurrency(1, "credits", 100)).to.equal(true)
			end)

			it("should return false when player has insufficient funds", function()
				_profiles[1] = makeProfile(50)
				expect(CurrencyService:hasCurrency(1, "credits", 100)).to.equal(false)
			end)

			it("should return false when profile is not loaded", function()
				expect(CurrencyService:hasCurrency(999, "credits", 1)).to.equal(false)
			end)

			it("should throw for non-positive amount", function()
				_profiles[1] = makeProfile(100)
				expect(function()
					CurrencyService:hasCurrency(1, "credits", 0)
				end).to.throw()
				expect(function()
					CurrencyService:hasCurrency(1, "credits", -10)
				end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("addCurrency", function()
			it("should add currency to the profile", function()
				_profiles[1] = makeProfile(100)
				local ok = CurrencyService:addCurrency(1, "credits", 50)
				expect(ok).to.equal(true)
				expect(activeSlotOf(1).currency.credits).to.equal(150)
			end)

			it("should return false when profile is not loaded", function()
				expect(CurrencyService:addCurrency(999, "credits", 50)).to.equal(false)
			end)

			it("should throw for invalid currency type", function()
				_profiles[1] = makeProfile(0)
				expect(function()
					CurrencyService:addCurrency(1, "invalid" :: any, 10)
				end).to.throw()
			end)

			it("should throw for non-positive amount", function()
				_profiles[1] = makeProfile(0)
				expect(function()
					CurrencyService:addCurrency(1, "credits", 0)
				end).to.throw()
				expect(function()
					CurrencyService:addCurrency(1, "credits", -5)
				end).to.throw()
			end)

			-- The base ships a single currency, so an "adds to two currency types independently"
			-- case cannot exist. What it would cover — successive adds each land on the slice
			-- rather than the last write clobbering the balance — is kept here.
			it("should accumulate across successive adds", function()
				_profiles[1] = makeProfile(0)
				CurrencyService:addCurrency(1, "credits", 100)
				CurrencyService:addCurrency(1, "credits", 25)
				expect(activeSlotOf(1).currency.credits).to.equal(125)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("removeCurrency", function()
			it("should remove currency from the profile", function()
				_profiles[1] = makeProfile(100)
				local ok = CurrencyService:removeCurrency(1, "credits", 30)
				expect(ok).to.equal(true)
				expect(activeSlotOf(1).currency.credits).to.equal(70)
			end)

			it("should return false when insufficient funds", function()
				_profiles[1] = makeProfile(20)
				local ok = CurrencyService:removeCurrency(1, "credits", 50)
				expect(ok).to.equal(false)
				expect(activeSlotOf(1).currency.credits).to.equal(20)
			end)

			it("should return false when profile is not loaded", function()
				expect(CurrencyService:removeCurrency(999, "credits", 10)).to.equal(false)
			end)

			it("should throw for non-positive amount", function()
				_profiles[1] = makeProfile(100)
				expect(function()
					CurrencyService:removeCurrency(1, "credits", 0)
				end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("setCurrency", function()
			it("should set currency to exact amount", function()
				_profiles[1] = makeProfile(50)
				local ok = CurrencyService:setCurrency(1, "credits", 200)
				expect(ok).to.equal(true)
				expect(activeSlotOf(1).currency.credits).to.equal(200)
			end)

			it("should return false when setting to same amount (no change)", function()
				_profiles[1] = makeProfile(100)
				expect(CurrencyService:setCurrency(1, "credits", 100)).to.equal(false)
			end)

			it("should allow setting to 0", function()
				_profiles[1] = makeProfile(100)
				local ok = CurrencyService:setCurrency(1, "credits", 0)
				expect(ok).to.equal(true)
				expect(activeSlotOf(1).currency.credits).to.equal(0)
			end)

			it("should clamp the set amount to MAX_CURRENCY", function()
				_profiles[1] = makeProfile(0)
				local ok = CurrencyService:setCurrency(1, "credits", CurrencyConstants.MAX_CURRENCY + 5_000)
				expect(ok).to.equal(true)
				-- Cap invariant holds for setCurrency, not just addCurrency.
				expect(activeSlotOf(1).currency.credits).to.equal(CurrencyConstants.MAX_CURRENCY)
			end)

			it("should report no change when already at MAX_CURRENCY and setting above it", function()
				_profiles[1] = makeProfile(CurrencyConstants.MAX_CURRENCY)
				-- Clamps to MAX_CURRENCY, which equals the current value, so there is no change.
				expect(CurrencyService:setCurrency(1, "credits", CurrencyConstants.MAX_CURRENCY + 1)).to.equal(false)
				expect(activeSlotOf(1).currency.credits).to.equal(CurrencyConstants.MAX_CURRENCY)
			end)

			it("should throw for negative amount", function()
				_profiles[1] = makeProfile(100)
				expect(function()
					CurrencyService:setCurrency(1, "credits", -1)
				end).to.throw()
			end)

			it("should return false when profile is not loaded", function()
				expect(CurrencyService:setCurrency(999, "credits", 100)).to.equal(false)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("grant", function()
			it("credits Gloom and Credits in one write", function()
				_profiles[1] = makeProfile(0)
				expect(CurrencyService:grant(1, { credits = 760, gloom = 340 }, "shiftPay")).to.equal(true)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(760)
				expect(CurrencyService:getCurrencyAmount(1, "gloom")).to.equal(340)
				expect(writes).to.equal(1)
			end)

			it("adds to the existing balance", function()
				_profiles[1] = makeProfile(100)
				expect(CurrencyService:grant(1, { credits = 40 }, "shiftPay")).to.equal(true)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(140)
			end)

			it("caps at MAX_CURRENCY, and reports false once fully absorbed", function()
				_profiles[1] = makeProfile(CurrencyConstants.MAX_CURRENCY - 10)
				expect(CurrencyService:grant(1, { credits = 50 }, "shiftPay")).to.equal(true)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(CurrencyConstants.MAX_CURRENCY)
				expect(CurrencyService:grant(1, { credits = 50 }, "shiftPay")).to.equal(false)
			end)

			it("writes nothing for all-zero or empty amounts", function()
				_profiles[1] = makeProfile(0)
				expect(CurrencyService:grant(1, { credits = 0, gloom = 0 }, "shiftPay")).to.equal(false)
				expect(CurrencyService:grant(1, {}, "shiftPay")).to.equal(false)
				expect(writes).to.equal(0)
			end)

			it("refuses a negative amount, an unknown currency and a bad user id before writing", function()
				_profiles[1] = makeProfile(0)
				expect(function()
					CurrencyService:grant(1, { credits = -1 }, "shiftPay")
				end).to.throw()
				expect(function()
					CurrencyService:grant(1, { coins = 1 } :: any, "shiftPay")
				end).to.throw()
				expect(function()
					CurrencyService:grant("bad" :: any, { credits = 1 }, "shiftPay")
				end).to.throw()
				expect(writes).to.equal(0)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(0)
			end)

			it("returns false when the profile is not loaded", function()
				expect(CurrencyService:grant(999, { credits = 5 }, "shiftPay")).to.equal(false)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("currencyOp", function()
			-- The op path is derived from the ACTIVE slot, so these tests need a loaded profile —
			-- without one PlayerDataSliceSystem.op asserts (see "throws when the profile is not loaded").
			it("mints a transaction operation targeting the active slot's currency path", function()
				_profiles[7] = makeProfile(100)
				local mutator = function(c: any)
					c.credits = 1
					return true
				end
				local op = CurrencyService:currencyOp(7, mutator)
				expect(op.userId).to.equal(7)
				-- Asserted via PlayerDataPathUtils, not a literal, so the test tracks the path algebra instead
				-- of duplicating it. makeProfile's active slot is 1.
				expect(op.path).to.equal(PlayerDataPathUtils.forSlot("currency", 1))
				expect(op.mutator).to.equal(mutator)
				-- Pins the epoch stamp (see PlayerDataSliceSystem.registerSlot's `op`): makeProfile(7) is minted
				-- under slotState.epoch = 1.
				expect(op.epoch).to.equal(1)
			end)

			it("is pure packaging — the mutator does not run when the op is minted", function()
				_profiles[7] = makeProfile(100)
				local ran = false
				CurrencyService:currencyOp(7, function()
					ran = true
					return true
				end)
				expect(ran).to.equal(false)
				expect(activeSlotOf(7).currency.credits).to.equal(100)
			end)

			it("throws when the profile is not loaded", function()
				-- No active slot -> no path. Minting a bogus op would silently drop a leg of an
				-- all-or-nothing transaction, so it must throw instead.
				expect(function()
					CurrencyService:currencyOp(999, function()
						return true
					end)
				end).to.throw()
			end)

			it("throws for a non-number userId", function()
				_profiles[7] = makeProfile(100)
				expect(function()
					CurrencyService:currencyOp("bad" :: any, function()
						return true
					end)
				end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		-- The proof: CurrencyService is registered via PlayerDataSliceSystem.registerSlot (not .register), so its
		-- reads/writes transparently follow the player's ACTIVE slot without the service ever branching
		-- on which one it is. Needs a second slot, so it is dormant while MAX_SLOTS = 1.
		describeMultiSlot("slot scoping", function()
			local USER_ID = 42

			it("keeps each character's currency separate", function()
				_profiles[USER_ID] = makeProfile(100)

				CurrencyService:addCurrency(USER_ID, "credits", 50) -- active slot is 1
				expect(CurrencyService:getCurrencyAmount(USER_ID, "credits")).to.equal(150)

				setActiveSlot(USER_ID, 2)
				-- Slot 2 is a fresh character: it has the template default, not slot 1's balance.
				expect(CurrencyService:getCurrencyAmount(USER_ID, "credits")).to.equal(100)

				CurrencyService:addCurrency(USER_ID, "credits", 5)
				expect(CurrencyService:getCurrencyAmount(USER_ID, "credits")).to.equal(105)

				setActiveSlot(USER_ID, 1)
				expect(CurrencyService:getCurrencyAmount(USER_ID, "credits")).to.equal(150)
			end)

			it("enforces the currency cap on a non-first slot", function()
				_profiles[USER_ID] = makeProfile(100)
				-- addCurrency clamps to MAX_CURRENCY (see its `math.min`), so a starting balance below
				-- the cap always "succeeds" (clamped upward). To exercise the cap's true no-op path —
				-- newAmount == oldAmount — slot 2 must already BE at the cap before the call.
				_profiles[USER_ID].slots[2].currency.credits = CurrencyConstants.MAX_CURRENCY

				setActiveSlot(USER_ID, 2)
				local ok = CurrencyService:addCurrency(USER_ID, "credits", CurrencyConstants.MAX_CURRENCY + 1)
				expect(ok).to.equal(false)
				expect(CurrencyService:getCurrencyAmount(USER_ID, "credits")).to.equal(CurrencyConstants.MAX_CURRENCY)
			end)
		end)
	end)
end
