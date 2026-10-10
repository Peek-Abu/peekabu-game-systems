local QueuePlaceRules = require(script.Parent.QueuePlaceRules)

local ROLES = { home = 111, away = 222, later = 0 }

return function()
	describe("roleOf", function()
		it("finds the role a place plays", function()
			expect(QueuePlaceRules.roleOf(222, ROLES)).to.equal("away")
		end)

		it("knows no role for an unknown or unpublished place", function()
			expect(QueuePlaceRules.roleOf(999, ROLES)).to.equal(nil)
			expect(QueuePlaceRules.roleOf(0, ROLES)).to.equal(nil)
		end)
	end)

	describe("mode", function()
		it("is live on a registered place outside Studio", function()
			expect(QueuePlaceRules.mode(111, false, false, ROLES)).to.equal("live")
		end)

		it("is local in Studio, even on a registered place", function()
			expect(QueuePlaceRules.mode(111, true, false, ROLES)).to.equal("local")
		end)

		it("is local on an unknown or unpublished place", function()
			expect(QueuePlaceRules.mode(999, false, false, ROLES)).to.equal("local")
			expect(QueuePlaceRules.mode(0, false, false, ROLES)).to.equal("local")
		end)

		it("is live when forced, even in Studio", function()
			expect(QueuePlaceRules.mode(0, true, true, ROLES)).to.equal("live")
		end)
	end)

	describe("route", function()
		it("teleports a live server to the destination's place", function()
			local route = QueuePlaceRules.route("live", "away", ROLES)
			expect(route.kind).to.equal("teleport")
			expect(route.placeId).to.equal(222)
		end)

		it("moves locally in local mode", function()
			expect(QueuePlaceRules.route("local", "away", ROLES).kind).to.equal("local")
		end)

		it("moves locally to a placeholder destination, even from a live server", function()
			expect(QueuePlaceRules.route("live", "later", ROLES).kind).to.equal("local")
		end)

		it("refuses an unregistered role and says why", function()
			local route, reason = QueuePlaceRules.route("live", "nowhere", ROLES)
			expect(route).to.equal(nil)
			expect(string.find(reason, "not registered") ~= nil).to.equal(true)
		end)
	end)

	describe("runsRole", function()
		it("runs every role in local mode", function()
			expect(QueuePlaceRules.runsRole("local", nil, "away")).to.equal(true)
		end)

		it("runs only its own role when live", function()
			expect(QueuePlaceRules.runsRole("live", "home", "home")).to.equal(true)
			expect(QueuePlaceRules.runsRole("live", "home", "away")).to.equal(false)
		end)
	end)

	describe("isReservedServer", function()
		it("is a reserved server with a private id and no owner", function()
			expect(QueuePlaceRules.isReservedServer("abc", 0)).to.equal(true)
		end)

		it("is not a public server or an owned private server", function()
			expect(QueuePlaceRules.isReservedServer("", 0)).to.equal(false)
			expect(QueuePlaceRules.isReservedServer("abc", 42)).to.equal(false)
		end)
	end)
end
