local HostRules = require(script.Parent.HostRules)
local HostConstants = require(script.Parent.Parent.Data.HostConstants)

return function()
	describe("hostAfter", function()
		it("makes the first member of an empty truck the host", function()
			expect(HostRules.hostAfter(nil, { 7, 8 })).to.equal(7)
		end)

		it("keeps the host while others join or leave", function()
			expect(HostRules.hostAfter(8, { 7, 8, 9 })).to.equal(8)
			expect(HostRules.hostAfter(8, { 8 })).to.equal(8)
		end)

		it("hands over to the earliest member left when the host leaves", function()
			expect(HostRules.hostAfter(7, { 9, 8 })).to.equal(9)
		end)

		it("has no host once the truck is empty", function()
			expect(HostRules.hostAfter(7, {})).to.equal(nil)
		end)
	end)

	describe("seats", function()
		it("gives 4 seats without the pass and 6 with it", function()
			expect(HostRules.seats(false)).to.equal(HostConstants.SEATS)
			expect(HostRules.seats(true)).to.equal(HostConstants.PASS_SEATS)
			expect(HostConstants.SEATS).to.equal(4)
			expect(HostConstants.PASS_SEATS).to.equal(6)
		end)
	end)

	describe("seatsFor", function()
		it("seats the host's pass size while it covers everyone aboard", function()
			expect(HostRules.seatsFor(false, 2)).to.equal(4)
			expect(HostRules.seatsFor(true, 2)).to.equal(6)
		end)

		it("never drops under the crew aboard: a hand-over to a host without the pass keeps 5 aboard", function()
			expect(HostRules.seatsFor(false, 5)).to.equal(5)
			expect(HostRules.seatsFor(false, 6)).to.equal(6)
			expect(HostRules.seatsFor(false, 4)).to.equal(4)
		end)
	end)

	describe("passLive", function()
		it("is off while the pass id is 0 (not created on the Dashboard yet)", function()
			expect(HostRules.passLive(0)).to.equal(false)
			expect(HostRules.passLive(123456)).to.equal(true)
		end)
	end)

	describe("canAct", function()
		local MEMBERS = { 7, 8, 9 }

		it("lets only the host start, cancel and lock", function()
			for _, action in { "start", "cancel", "lock" } do
				expect(HostRules.canAct(action, 7, 7, MEMBERS)).to.equal(true)
				expect(HostRules.canAct(action, 8, 7, MEMBERS)).to.equal(false)
			end
		end)

		it("refuses everything on a truck with no host", function()
			expect(HostRules.canAct("start", 7, nil, {})).to.equal(false)
		end)

		it("lets any member leave, host included, but nobody outside", function()
			expect(HostRules.canAct("leave", 8, 7, MEMBERS)).to.equal(true)
			expect(HostRules.canAct("leave", 7, 7, MEMBERS)).to.equal(true)
			expect(HostRules.canAct("leave", 5, 7, MEMBERS)).to.equal(false)
		end)

		it("lets the host kick a member, never themself or someone not aboard", function()
			expect(HostRules.canAct("kick", 7, 7, MEMBERS, 8)).to.equal(true)
			expect(HostRules.canAct("kick", 8, 7, MEMBERS, 9)).to.equal(false)
			expect(HostRules.canAct("kick", 7, 7, MEMBERS, 7)).to.equal(false)
			expect(HostRules.canAct("kick", 7, 7, MEMBERS, 5)).to.equal(false)
			expect(HostRules.canAct("kick", 7, 7, MEMBERS, nil)).to.equal(false)
		end)
	end)

	describe("canBoard", function()
		local MEMBERS = { 7, 8 }

		it("lets anyone onto an open truck, and anyone onto an empty one", function()
			expect(HostRules.canBoard(9, 7, MEMBERS, false, false, false)).to.equal(true)
			expect(HostRules.canBoard(9, nil, {}, false, false, false)).to.equal(true)
		end)

		it("refuses a kicked player, and says so", function()
			local ok, reason = HostRules.canBoard(9, 7, MEMBERS, false, true, true)
			expect(ok).to.equal(false)
			expect(reason).to.equal("kicked")
		end)

		it("takes a kicked member off too", function()
			expect(HostRules.canBoard(8, 7, MEMBERS, false, true, false)).to.equal(false)
		end)

		it("lets only the host's friends onto a friends-only truck, and says so", function()
			local ok, reason = HostRules.canBoard(9, 7, MEMBERS, true, false, false)
			expect(ok).to.equal(false)
			expect(reason).to.equal("friends")
			expect(HostRules.canBoard(9, 7, MEMBERS, true, false, true)).to.equal(true)
		end)

		it("never ejects the host or a member already aboard when the lock goes on", function()
			expect(HostRules.canBoard(7, 7, MEMBERS, true, false, false)).to.equal(true)
			expect(HostRules.canBoard(8, 7, MEMBERS, true, false, false)).to.equal(true)
		end)
	end)

	describe("idleDue", function()
		local IDLE = HostConstants.IDLE_SECONDS

		it("starts the trip once a truck has waited unstarted for the idle time", function()
			expect(HostRules.idleDue(100, false, 100 + IDLE - 1)).to.equal(false)
			expect(HostRules.idleDue(100, false, 100 + IDLE)).to.equal(true)
		end)

		it("never fires while a countdown runs or with nobody aboard", function()
			expect(HostRules.idleDue(100, true, 100 + IDLE * 2)).to.equal(false)
			expect(HostRules.idleDue(nil, false, 100 + IDLE * 2)).to.equal(false)
		end)
	end)

	describe("exit", function()
		it("puts a leaving player on the floor past the pad's front (-Z) edge, facing away", function()
			local pad = CFrame.new(10, 1.5, 20)
			local size = Vector3.new(12, 3, 16)
			local exit = HostRules.exit(pad, size)
			local floor = 1.5 - 3 / 2
			expect(exit.Position.X).to.be.near(10)
			expect(exit.Position.Y).to.be.near(floor + HostConstants.EXIT_HEIGHT)
			expect(exit.Position.Z).to.be.near(20 - 8 - HostConstants.EXIT_DISTANCE)
			expect(exit.LookVector:Dot(Vector3.new(0, 0, -1))).to.be.near(1)
		end)

		it("follows the pad's rotation", function()
			local pad = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(90), 0)
			local exit = HostRules.exit(pad, Vector3.new(12, 3, 16))
			local front = pad.LookVector
			local flat = Vector3.new(exit.Position.X, 0, exit.Position.Z)
			expect(exit.LookVector:Dot(front)).to.be.near(1)
			expect(flat:Dot(front)).to.be.near(8 + HostConstants.EXIT_DISTANCE)
		end)
	end)
end
