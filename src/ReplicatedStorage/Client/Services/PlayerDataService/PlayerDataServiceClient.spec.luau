--!strict
--[=[
	Unit tests for PlayerDataServiceClient.

	Two surfaces are covered:
	  1. The data API (getProfile/mutate/getState) via the `_setProfileForTesting` seam,
	     which mirrors the server service's seam and gives clean per-test reset.
	  2. The init() network wiring: we patch PlayerProfileUpdate.listen to capture the
	     handler and stub PlayerReady.send (which is client-only and absent on the server
	     test runner), then drive the captured handler to simulate a server sync.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataServiceClient = require(ReplicatedStorage.Client.Services.PlayerDataService.PlayerDataServiceClient)
local PlayerDataEvents = require(ReplicatedStorage.Shared.Events.PlayerDataEvents)

local function makeProfile(gold: number?, items: { any }?): any
	return {
		currency = { gold = gold or 0, gems = 0 },
		inventory = items or {},
	}
end

return function()
	describe("PlayerDataServiceClient", function()
		beforeEach(function()
			PlayerDataServiceClient:_setProfileForTesting(nil)
		end)

		afterEach(function()
			PlayerDataServiceClient:_setProfileForTesting(nil)
		end)

		-- ---------------------------------------------------------------------
		describe("getProfile", function()
			it("returns nil before any profile is loaded", function()
				expect(PlayerDataServiceClient:getProfile()).to.equal(nil)
			end)

			it("returns the loaded profile", function()
				local p = makeProfile(100)
				PlayerDataServiceClient:_setProfileForTesting(p)
				expect(PlayerDataServiceClient:getProfile()).to.equal(p)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("mutate", function()
			it("returns false (and does not run the mutator) when no profile is loaded", function()
				local ran = false
				local ok = PlayerDataServiceClient:mutate("currency", function()
					ran = true
					return true
				end)
				expect(ok).to.equal(false)
				expect(ran).to.equal(false)
			end)

			it("applies the mutation and returns true", function()
				PlayerDataServiceClient:_setProfileForTesting(makeProfile(100))
				local ok = PlayerDataServiceClient:mutate("currency", function(c: any)
					c.gold = 250
					return true
				end)
				expect(ok).to.equal(true)
				local prof = PlayerDataServiceClient:getProfile()
				expect(prof and prof.currency.gold).to.equal(250)
			end)

			it("returns false when the mutator reports no change", function()
				PlayerDataServiceClient:_setProfileForTesting(makeProfile(100))
				local ok = PlayerDataServiceClient:mutate("currency", function(c: any)
					c.gold = 1
					return false
				end)
				expect(ok).to.equal(false)
			end)

			it("returns false when the path does not exist", function()
				PlayerDataServiceClient:_setProfileForTesting(makeProfile(100))
				local ok = PlayerDataServiceClient:mutate("quests", function()
					return true
				end)
				expect(ok).to.equal(false)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("getState", function()
			it("reports no profile when unloaded", function()
				local state = PlayerDataServiceClient:getState()
				expect(state.hasProfile).to.equal(false)
				expect(state.inventoryCount).to.equal(0)
			end)

			it("reports a profile summary when loaded", function()
				PlayerDataServiceClient:_setProfileForTesting(makeProfile(100, { { itemType = "iron-sword" } }))
				local state = PlayerDataServiceClient:getState()
				expect(state.hasProfile).to.equal(true)
				expect(state.inventoryCount).to.equal(1)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("profile sync (init)", function()
			local capturedHandler: ((any) -> ())?
			local origListen
			local origSend

			beforeEach(function()
				capturedHandler = nil
				origListen = PlayerDataEvents.packets.PlayerProfileUpdate.listen
				origSend = PlayerDataEvents.packets.PlayerReady.send

				PlayerDataEvents.packets.PlayerProfileUpdate.listen = function(handler)
					capturedHandler = handler
					return function() end
				end
				-- PlayerReady.send is client-only; stub it so init() never touches the network.
				PlayerDataEvents.packets.PlayerReady.send = function() end

				PlayerDataServiceClient.init(PlayerDataServiceClient)
			end)

			afterEach(function()
				PlayerDataEvents.packets.PlayerProfileUpdate.listen = origListen
				PlayerDataEvents.packets.PlayerReady.send = origSend
				PlayerDataServiceClient.stop(PlayerDataServiceClient)
				PlayerDataServiceClient:_setProfileForTesting(nil)
			end)

			it("registers a PlayerProfileUpdate listener", function()
				expect(capturedHandler).to.be.a("function")
			end)

			it("loads the profile and fires ProfileLoaded on sync", function()
				local fired: any = nil
				local conn = PlayerDataServiceClient.ProfileLoaded:Connect(function(p)
					fired = p
				end)

				local handler = assert(capturedHandler, "handler was not captured")
				handler({
					userId = 123,
					currency = { gold = 500, gems = 5 },
					inventory = { { itemType = "iron-sword" } },
				})

				-- SignalPlus fires connections via task.defer; yield once so the connection runs.
				task.wait()
				conn:Disconnect()

				local prof = PlayerDataServiceClient:getProfile()
				expect(prof).to.be.ok()
				expect(prof and prof.currency.gold).to.equal(500)
				expect(prof and #prof.inventory).to.equal(1)
				expect(fired).to.be.ok()
			end)
		end)
	end)
end
