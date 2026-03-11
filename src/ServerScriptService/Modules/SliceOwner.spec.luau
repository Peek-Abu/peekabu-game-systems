--!strict
--[=[
	Unit tests for SliceOwner — the shared slice-owner scaffolding.

	Mock strategy mirrors the service specs: patch PlayerDataService._getSliceShell/.mutate inside
	beforeAll/afterAll so this file owns its mock window. SliceOwner looks those methods up through
	the table at call time, so the patch is seen. A synthetic slice name is registered so this never
	collides with the real "currency"/"inventory" registrations in the same test place.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService.PlayerDataServiceServer)
local SliceOwner = require(ServerScriptService.Modules.SliceOwner)

local SLICE_NAME = "__sliceOwnerSpec"

-- Registered at module scope (once per require, like the real services) rather than in beforeAll, so
-- re-running the suite in the same session can't trip registerProfilePath's "already registered" guard.
local slice = SliceOwner.register(SLICE_NAME, { value = 0 }, function(profile)
	return (profile :: any)[SLICE_NAME]
end)

return function()
	describe("SliceOwner", function()
		local _profiles: { [number]: any } = {}
		local _origGetSliceShell
		local _origMutate

		beforeAll(function()
			_origGetSliceShell = PlayerDataService._getSliceShell
			_origMutate = PlayerDataService.mutate

			-- get reads through _getSliceShell (the per-slice snapshot path). The mock mirrors its
			-- nil contract (unloaded profile / missing path) and returns the fake profile directly —
			-- the reader projects the slice out of it, same as production.
			PlayerDataService._getSliceShell = function(_self: any, userId: number, path: string)
				local profile = _profiles[userId]
				if not profile or (profile :: any)[path] == nil then
					return nil
				end
				return profile
			end

			PlayerDataService.mutate = function(
				_self: any,
				userId: number,
				path: string,
				mutator: (data: any) -> boolean?
			): boolean
				local profile = _profiles[userId]
				if not profile then
					return false
				end
				local data = (profile :: any)[path]
				if data == nil then
					return false
				end
				return mutator(data) ~= false
			end
		end)

		afterAll(function()
			PlayerDataService._getSliceShell = _origGetSliceShell
			PlayerDataService.mutate = _origMutate
		end)

		beforeEach(function()
			_profiles = {}
		end)

		describe("register", function()
			it("returns get and mutate accessors", function()
				expect(type(slice.get)).to.equal("function")
				expect(type(slice.mutate)).to.equal("function")
			end)
		end)

		describe("get", function()
			it("reads the slice via the provided reader", function()
				_profiles[1] = { [SLICE_NAME] = { value = 42 } }
				local value = slice.get(1)
				expect(value).to.be.ok()
				expect(value.value).to.equal(42)
			end)

			it("returns nil when the profile is not loaded", function()
				expect(slice.get(999)).to.equal(nil)
			end)

			it("throws for a non-number userId", function()
				expect(function()
					slice.get("bad" :: any)
				end).to.throw()
			end)
		end)

		describe("mutate", function()
			it("applies the mutator to the slice", function()
				_profiles[1] = { [SLICE_NAME] = { value = 1 } }
				local changed = slice.mutate(1, function(data)
					data.value = 100
					return true
				end)
				expect(changed).to.equal(true)
				expect(_profiles[1][SLICE_NAME].value).to.equal(100)
			end)

			it("returns false when the profile is not loaded", function()
				expect(slice.mutate(999, function()
					return true
				end)).to.equal(false)
			end)

			it("throws for a non-number userId", function()
				expect(function()
					slice.mutate("bad" :: any, function()
						return true
					end)
				end).to.throw()
			end)
		end)
	end)
end
