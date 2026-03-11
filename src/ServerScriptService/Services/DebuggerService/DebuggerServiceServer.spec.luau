--!strict
--[=[
	Tests for DebuggerServiceServer. Beyond the shape checks, the admin-gate tests drive the real
	RequestHandler-wrapped handlers (exposed as `_onSetSubscription` / `_onClearServerLogs`) so the
	rate-limit + validate + handler pipeline is exercised exactly as ByteNet would invoke it.

	`Admin.isAdmin` is patched (same convention as AdminServiceServer.spec / CurrencyServiceServer.spec)
	to control the admin/non-admin branch independent of the Studio always-allow bypass; the original
	is restored — and all spec-created subscriber/rate-limit state cleared — in afterAll.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DebuggerServiceServer = require(ServerScriptService.Services.DebuggerService.DebuggerServiceServer)
local RequestHandler = require(ServerScriptService.Modules.RequestHandler)
local Admin = require(ReplicatedStorage.Shared.Modules.Admin)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

return function()
	describe("DebuggerServiceServer", function()
		it("should have no dependencies (boots at level 0, never blocked)", function()
			expect(DebuggerServiceServer.dependencies).to.be.a("table")
			expect(#DebuggerServiceServer.dependencies).to.equal(0)
		end)

		it("should implement lifecycle + introspection methods", function()
			expect(DebuggerServiceServer.init).to.be.a("function")
			expect(DebuggerServiceServer.stop).to.be.a("function")
			expect(DebuggerServiceServer.getState).to.be.a("function")
		end)

		it("getState should report a zero subscriber count before anyone subscribes", function()
			local state = DebuggerServiceServer:getState()
			expect(state.subscriberCount).to.equal(0)
			expect(state.assembling).to.equal(false)
		end)
	end)

	describe("admin gate (SetSubscription / ClearServerLogs)", function()
		local originalIsAdmin = Admin.isAdmin
		local isAdminResult = false

		-- The handlers only read UserId (rate limiting) and Name (logging); a stand-in suffices.
		local fakePlayer: Player = { UserId = -9001, Name = "DebuggerSpecPlayer" } :: any

		beforeAll(function()
			Admin.isAdmin = function(_player: Player): boolean
				return isAdminResult
			end
		end)

		afterAll(function()
			-- Ensure no fake subscriber or rate-limit counters leak past this spec, then unpatch.
			isAdminResult = true
			DebuggerServiceServer._onSetSubscription(false, fakePlayer)
			RequestHandler.resetRateLimit(fakePlayer.UserId)
			Admin.isAdmin = originalIsAdmin
		end)

		it("refuses a non-admin subscribe", function()
			isAdminResult = false
			DebuggerServiceServer._onSetSubscription(true, fakePlayer)
			expect(DebuggerServiceServer:getState().subscriberCount).to.equal(0)
		end)

		it("accepts an admin subscribe and unsubscribe", function()
			isAdminResult = true
			DebuggerServiceServer._onSetSubscription(true, fakePlayer)
			expect(DebuggerServiceServer:getState().subscriberCount).to.equal(1)

			DebuggerServiceServer._onSetSubscription(false, fakePlayer)
			expect(DebuggerServiceServer:getState().subscriberCount).to.equal(0)
		end)

		it("prunes a subscriber whose admin status lapsed (pre-dispatch re-check)", function()
			isAdminResult = true
			DebuggerServiceServer._onSetSubscription(true, fakePlayer)
			expect(DebuggerServiceServer:getState().subscriberCount).to.equal(1)

			-- Revoke mid-session (the case a dynamic group-rank/DataStore isAdmin makes real): the
			-- pre-dispatch re-check must drop the subscriber before the next snapshot goes out —
			-- the stream carries every player's economy state, not just the viewer's.
			isAdminResult = false
			DebuggerServiceServer._pruneUnauthorizedSubscribers()
			expect(DebuggerServiceServer:getState().subscriberCount).to.equal(0)
		end)

		it("keeps a still-authorized subscriber across a prune", function()
			isAdminResult = true
			DebuggerServiceServer._onSetSubscription(true, fakePlayer)
			DebuggerServiceServer._pruneUnauthorizedSubscribers()
			expect(DebuggerServiceServer:getState().subscriberCount).to.equal(1)
			DebuggerServiceServer._onSetSubscription(false, fakePlayer)
		end)

		it("refuses a non-admin log clear", function()
			local marker = `debugger-spec-marker-{math.floor(os.clock() * 1000)}`
			Logger.new("DebuggerSpec"):info(marker)

			isAdminResult = false
			DebuggerServiceServer._onClearServerLogs(true, fakePlayer)

			local markerSurvived = false
			for _, entry in Logger.getHistory() do
				if string.find(entry.message, marker, 1, true) then
					markerSurvived = true
					break
				end
			end
			expect(markerSurvived).to.equal(true)
		end)

		it("clears the server log buffer for an admin", function()
			local marker = `debugger-spec-marker-{math.floor(os.clock() * 1000)}-admin`
			Logger.new("DebuggerSpec"):info(marker)

			isAdminResult = true
			DebuggerServiceServer._onClearServerLogs(true, fakePlayer)

			local markerSurvived = false
			for _, entry in Logger.getHistory() do
				if string.find(entry.message, marker, 1, true) then
					markerSurvived = true
					break
				end
			end
			expect(markerSurvived).to.equal(false)
		end)
	end)
end
