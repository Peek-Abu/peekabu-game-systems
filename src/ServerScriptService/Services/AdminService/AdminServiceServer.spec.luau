--!strict
--[=[
	Tests for AdminServiceServer — above all its BeforeRun permission gate, the security-critical
	path that keeps Cmdr's powerful built-in groups (DefaultAdmin/DefaultDebug) and the custom
	Admins group behind Admin.isAdmin.

	`Admin.isAdmin` is patched for the gate tests (the same require-time-reference convention
	CurrencyServiceServer.spec uses to patch PlayerDataService): the hook looks it up on the Admin
	table at call time, so swapping the field controls the admin/non-admin branch regardless of the
	environment's Studio always-allow bypass. The original is restored in afterAll.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminServiceServer = require(script.Parent.AdminServiceServer)
local Admin = require(ReplicatedStorage.Shared.Modules.Admin)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

return function()
	describe("AdminServiceServer", function()
		it("should have correct dependencies", function()
			expect(AdminServiceServer.dependencies).to.be.a("table")
			expect(#AdminServiceServer.dependencies).to.equal(0)
		end)

		it("should implement lifecycle methods", function()
			expect(AdminServiceServer.init).to.be.a("function")
			expect(AdminServiceServer.start).to.be.a("function")
		end)
	end)

	describe("BeforeRun permission gate", function()
		local originalIsAdmin = Admin.isAdmin
		-- Controls what the patched Admin.isAdmin reports for the current test.
		local isAdminResult = false

		local function makePlayer(userId: number, name: string): Player
			-- The gate only reads UserId and Name; a stand-in table is sufficient (and the only
			-- option — specs cannot construct real Player instances).
			return { UserId = userId, Name = name } :: any
		end

		local function makeContext(group: string?, executor: Player?): AdminServiceServer.BeforeRunContext
			return { Group = group, Name = "specCommand", Executor = executor }
		end

		beforeAll(function()
			Admin.isAdmin = function(_player: Player): boolean
				return isAdminResult
			end
		end)

		afterAll(function()
			Admin.isAdmin = originalIsAdmin
		end)

		it("allows an admin to run a gated command", function()
			isAdminResult = true
			local verdict = AdminServiceServer._beforeRunHook(makeContext("Admins", makePlayer(101, "AdminPlayer")))
			expect(verdict).to.equal(nil)
		end)

		it("denies a non-admin on every gated group", function()
			isAdminResult = false
			for _, group in { "Admins", "DefaultAdmin", "DefaultDebug" } do
				local verdict = AdminServiceServer._beforeRunHook(makeContext(group, makePlayer(102, "Rando")))
				expect(verdict).to.equal("You do not have permission to run this command")
			end
		end)

		it("denies a gated command with no executor, even when isAdmin would pass", function()
			isAdminResult = true
			local verdict = AdminServiceServer._beforeRunHook(makeContext("Admins", nil))
			expect(verdict).to.equal("This command can only be run by a player")
		end)

		it("leaves allowlisted groups open to non-admins", function()
			isAdminResult = false
			for _, group in { "DefaultUtil", "Help" } do
				local verdict = AdminServiceServer._beforeRunHook(makeContext(group, makePlayer(103, "Rando")))
				expect(verdict).to.equal(nil)
			end
		end)

		it("FAILS CLOSED on unknown groups — a typo or future group is gated, not open (regression)", function()
			isAdminResult = false
			-- "Admin" (typo for "Admins") and a hypothetical future group must both be denied:
			-- the gate is an allowlist of open groups, so anything unrecognized requires admin.
			for _, group in { "Admin", "FutureModeration" } do
				local verdict = AdminServiceServer._beforeRunHook(makeContext(group, makePlayer(104, "Rando")))
				expect(verdict).to.equal("You do not have permission to run this command")
			end
		end)

		it("FAILS CLOSED on group-less commands for non-admins", function()
			isAdminResult = false
			local verdict = AdminServiceServer._beforeRunHook(makeContext(nil, makePlayer(104, "Rando")))
			expect(verdict).to.equal("You do not have permission to run this command")
		end)

		it("still allows admins to run unknown and group-less commands", function()
			isAdminResult = true
			expect(AdminServiceServer._beforeRunHook(makeContext("FutureModeration", makePlayer(107, "AdminPlayer")))).to.equal(
				nil
			)
			expect(AdminServiceServer._beforeRunHook(makeContext(nil, makePlayer(107, "AdminPlayer")))).to.equal(nil)
		end)

		it("audit-logs both denials and allowed runs", function()
			isAdminResult = false
			AdminServiceServer._beforeRunHook(makeContext("DefaultAdmin", makePlayer(105, "Rando")))
			isAdminResult = true
			AdminServiceServer._beforeRunHook(makeContext("DefaultAdmin", makePlayer(106, "AdminPlayer")))

			local sawDenied = false
			local sawAllowed = false
			for _, entry in Logger.getHistory() do
				if entry.level == "AUDIT" and entry.context == "AdminServiceServer" then
					if
						string.find(entry.message, "DENIED", 1, true) and string.find(entry.message, "(105)", 1, true)
					then
						sawDenied = true
					end
					if
						string.find(entry.message, "ran admin command", 1, true)
						and string.find(entry.message, "(106)", 1, true)
					then
						sawAllowed = true
					end
				end
			end
			expect(sawDenied).to.equal(true)
			expect(sawAllowed).to.equal(true)
		end)
	end)
end
