--!strict
--[=[
	Unit tests for PlayerDataSliceSystem — the shared slice-owner scaffolding.

	Mock strategy mirrors the service specs: patch PlayerDataService's slot-aware read surface
	(getActiveSlot / _getSlotShell / _getAccountShell) and .mutate inside beforeAll/afterAll, so this
	file owns its mock window. PlayerDataSliceSystem looks those methods up through the table at CALL time, so
	the patch is seen.

	The fake profile is a deep copy of the REAL PROFILE_TEMPLATE, taken after the spec's slices are
	registered. That is what makes the slot assertions honest: the defaults these tests read back out
	of every slot are the ones registerSlotPath actually stamped, not ones the spec re-invented.
	The mocks reproduce production's two load-bearing behaviours — the dotted-path walk (slot index is
	an ARRAY key, so it must be tonumber'd) and the frozen slice copy handed back by the shells — so a
	regression in either is caught here rather than only in Studio.

	Tests that need a second slot (switching the active slot, cross-slot isolation) are gated on
	MAX_SLOTS >= 2 and skip while the game runs a single save per player.

	Synthetic slice names ("__sliceOwnerSpec*") keep these registrations from colliding with the real
	"currency"/"inventory" ones in the same test place.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local PlayerDataPathUtils = require(PlayerDataServer.Utils.PlayerDataPathUtils)
local PlayerDataSliceSystem = require(PlayerDataServer.Systems.PlayerDataSliceSystem)
local sift = require(ReplicatedStorage.Packages.sift)

local USER_ID = 1

-- Registered at module scope (once per require, like the real services) rather than in beforeAll, so
-- re-running the suite in the same session can't trip the "already registered" guard.
local testSlice = PlayerDataSliceSystem.registerSlot("__sliceOwnerSpecTest", { amount = 0 }, function(slot)
	return (slot :: any).__sliceOwnerSpecTest
end)

local followSlice = PlayerDataSliceSystem.registerSlot("__sliceOwnerSpecFollow", { amount = 0 }, function(slot)
	return (slot :: any).__sliceOwnerSpecFollow
end)

local flagsSlice = PlayerDataSliceSystem.registerAccount("__sliceOwnerSpecFlags", { premium = false }, function(account)
	return (account :: any).__sliceOwnerSpecFlags
end)

local sharedSlice = PlayerDataSliceSystem.registerAccount("__sliceOwnerSpecShared", { n = 0 }, function(account)
	return (account :: any).__sliceOwnerSpecShared
end)

return function()
	-- Multi-slot behaviour is dormant while MAX_SLOTS = 1; these re-enable when a game raises it.
	local itMultiSlot = if PlayerDataConstants.MAX_SLOTS >= 2 then it else itSKIP

	describe("PlayerDataSliceSystem", function()
		local _profiles: { [number]: any } = {}
		local _origGetActiveSlot
		local _origGetSlotEpoch
		local _origGetSlotShell
		local _origGetAccountShell
		local _origMutate

		-- Test helper: switch the character the player is "currently playing", the way a real slot
		-- switch does — by writing profile.slotState.active. Nothing else about the slices changes.
		local function setActiveSlot(userId: number, slotIndex: number)
			_profiles[userId].slotState.active = slotIndex
		end

		-- Mirrors _getSlotShell/_getAccountShell's contract: a shallow shell of the container with ONLY
		-- the requested slice swapped for a frozen deep copy.
		local function shellOf(container: any, slice: string): any?
			local live = container[slice]
			if live == nil then
				return nil
			end
			local shell = table.clone(container)
			shell[slice] = if type(live) == "table" then sift.Dictionary.freezeDeep(live) else live
			return shell
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

			-- registerSlot's `op` stamps the epoch it was minted under, so the mock must serve it from
			-- the same fake slotState the active-slot mock reads (they move together in production —
			-- a slot switch writes both in one atomic mutate of slotState).
			PlayerDataService.getSlotEpoch = function(_self: any, userId: number): number?
				local profile = _profiles[userId]
				return if profile then profile.slotState.epoch else nil
			end

			PlayerDataService._getSlotShell = function(_self: any, userId: number, slotIndex: number, slice: string)
				local profile = _profiles[userId]
				local slot = profile and profile.slots[slotIndex]
				return if slot then shellOf(slot, slice) else nil
			end

			PlayerDataService._getAccountShell = function(_self: any, userId: number, slice: string)
				local profile = _profiles[userId]
				return if profile then shellOf(profile.account, slice) else nil
			end

			-- Walks the DOTTED path exactly as PlayerDataService.resolvePath does — including
			-- tonumber'ing the slot segment, because `slots` is an array and a string key would
			-- silently miss.
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
				return mutator(data) ~= false
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
			-- A fresh profile straight off the (now spec-slice-bearing) template: every slot seeded
			-- with each registered slice's default, active slot 1.
			_profiles[USER_ID] = sift.Dictionary.copyDeep(PlayerDataConstants.PROFILE_TEMPLATE)
		end)

		describe("registerSlot", function()
			it("reads and writes the ACTIVE slot without the caller naming a slot", function()
				testSlice.mutate(USER_ID, function(slice)
					slice.amount = 42
					return true
				end)

				expect(testSlice.get(USER_ID).amount).to.equal(42)
				-- The active slot is 1, so the write must have landed in slot 1.
				expect(testSlice.getForSlot(USER_ID, 1).amount).to.equal(42)
			end)

			itMultiSlot("writes ONLY the active slot, leaving the others untouched", function()
				testSlice.mutate(USER_ID, function(slice)
					slice.amount = 42
					return true
				end)

				expect(testSlice.getForSlot(USER_ID, 1).amount).to.equal(42)
				expect(testSlice.getForSlot(USER_ID, 2).amount).to.equal(0)
			end)

			itMultiSlot("follows the active slot when it changes", function()
				followSlice.mutate(USER_ID, function(value)
					value.amount = 1
					return true
				end)

				setActiveSlot(USER_ID, 2)

				expect(followSlice.get(USER_ID).amount).to.equal(0) -- slot 2 is untouched
				followSlice.mutate(USER_ID, function(value)
					value.amount = 2
					return true
				end)
				expect(followSlice.getForSlot(USER_ID, 1).amount).to.equal(1)
				expect(followSlice.getForSlot(USER_ID, 2).amount).to.equal(2)
			end)

			it("returns a frozen read — mutating it throws", function()
				local value = testSlice.get(USER_ID)
				expect(function()
					value.amount = 1
				end).to.throw()
			end)

			itMultiSlot("mints an op against the ACTIVE slot's path", function()
				setActiveSlot(USER_ID, 2)
				local operation = testSlice.op(USER_ID, function()
					return true
				end)
				expect(operation.userId).to.equal(USER_ID)
				expect(operation.path).to.equal(PlayerDataPathUtils.forSlot("__sliceOwnerSpecTest", 2))
			end)

			it("stamps the current epoch onto a slot-scoped op", function()
				-- The epoch is what makes a held op's staleness DETECTABLE: the baked path still
				-- resolves after a switch, it just resolves to the character the player left.
				-- transaction() compares this stamp against the profile's current epoch and refuses.
				local operation = testSlice.op(USER_ID, function()
					return true
				end)
				expect(operation.epoch).to.equal(PlayerDataService:getSlotEpoch(USER_ID))
			end)

			itMultiSlot("stamps the epoch as of MINT time, not as of the switch that follows", function()
				local operation = testSlice.op(USER_ID, function()
					return true
				end)
				local mintedUnder = operation.epoch
				-- A switch bumps the generation; the already-minted op keeps the OLD one, which is
				-- exactly the mismatch transaction() rejects on.
				_profiles[USER_ID].slotState.active = 2
				_profiles[USER_ID].slotState.epoch += 1
				expect(operation.epoch).to.equal(mintedUnder)
				expect(operation.epoch).to.never.equal(PlayerDataService:getSlotEpoch(USER_ID))
			end)

			it("is pure packaging — minting an op does not run the mutator", function()
				local ran = false
				testSlice.op(USER_ID, function()
					ran = true
					return true
				end)
				expect(ran).to.equal(false)
				expect(testSlice.get(USER_ID).amount).to.equal(0)
			end)

			it("throws when op is minted for a profile that is not loaded", function()
				-- No active slot -> no path. A bogus op would silently drop a leg of an
				-- all-or-nothing transaction, so op must throw rather than mint one.
				expect(function()
					testSlice.op(999, function()
						return true
					end)
				end).to.throw()
			end)

			it("returns nil / false when the profile is not loaded", function()
				expect(testSlice.get(999)).to.equal(nil)
				expect(testSlice.getForSlot(999, 1)).to.equal(nil)
				expect(testSlice.mutate(999, function()
					return true
				end)).to.equal(false)
			end)

			it("throws for a non-number userId", function()
				expect(function()
					testSlice.get("bad" :: any)
				end).to.throw()
				expect(function()
					testSlice.mutate("bad" :: any, function()
						return true
					end)
				end).to.throw()
			end)
		end)

		describe("registerAccount", function()
			it("reads and writes the account slice", function()
				flagsSlice.mutate(USER_ID, function(flags)
					flags.premium = true
					return true
				end)

				expect(flagsSlice.get(USER_ID).premium).to.equal(true)
			end)

			itMultiSlot("is shared across slots — switching slot does not change it", function()
				sharedSlice.mutate(USER_ID, function(value)
					value.n = 7
					return true
				end)
				setActiveSlot(USER_ID, 2)
				expect(sharedSlice.get(USER_ID).n).to.equal(7)
				-- getForSlot on an account slice is the account value, whatever slot is named.
				expect(sharedSlice.getForSlot(USER_ID, 2).n).to.equal(7)
			end)

			it("mints an op against the account path", function()
				local operation = flagsSlice.op(USER_ID, function()
					return true
				end)
				expect(operation.path).to.equal(PlayerDataPathUtils.forAccount("__sliceOwnerSpecFlags"))
			end)

			it("does not stamp an epoch onto an account op", function()
				-- Account data is slot-independent, so a character switch cannot invalidate an op over
				-- it. No stamp -> transaction() never epoch-checks it.
				local operation = flagsSlice.op(USER_ID, function()
					return true
				end)
				expect(operation.epoch).to.never.be.ok()
			end)

			it("returns nil when the profile is not loaded", function()
				expect(flagsSlice.get(999)).to.equal(nil)
			end)
		end)
	end)
end
