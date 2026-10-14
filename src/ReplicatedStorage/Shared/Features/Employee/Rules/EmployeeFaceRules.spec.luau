local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeFaceRules = require(script.Parent.EmployeeFaceRules)

return function()
	local NEAR = EmployeeConstants.WORRIED_RADIUS - 1
	local FAR = EmployeeConstants.WORRIED_RADIUS + 1

	describe("isThreatened", function()
		it("is never threatened without a Manager", function()
			expect(EmployeeFaceRules.isThreatened(nil, false, nil)).to.equal(false)
		end)

		it("is threatened when the Manager chases or catches this player, at any distance", function()
			expect(EmployeeFaceRules.isThreatened("chase", true, 500)).to.equal(true)
			expect(EmployeeFaceRules.isThreatened("catch", true, nil)).to.equal(true)
		end)

		it("is threatened by a nearby Manager who is investigating, chasing someone or searching", function()
			expect(EmployeeFaceRules.isThreatened("investigate", false, NEAR)).to.equal(true)
			expect(EmployeeFaceRules.isThreatened("chase", false, NEAR)).to.equal(true)
			expect(EmployeeFaceRules.isThreatened("search", false, NEAR)).to.equal(true)
			expect(EmployeeFaceRules.isThreatened("catch", false, NEAR)).to.equal(true)
		end)

		it("ignores a nearby Manager who is only patrolling or resting", function()
			expect(EmployeeFaceRules.isThreatened("patrol", false, NEAR)).to.equal(false)
			expect(EmployeeFaceRules.isThreatened("rest", false, NEAR)).to.equal(false)
		end)

		it("ignores an alert Manager beyond the radius when he is not after this player", function()
			expect(EmployeeFaceRules.isThreatened("investigate", false, FAR)).to.equal(false)
			expect(EmployeeFaceRules.isThreatened("chase", false, FAR)).to.equal(false)
			expect(EmployeeFaceRules.isThreatened("chase", false, nil)).to.equal(false)
		end)

		it("does not count being the target of a non-chase mode", function()
			expect(EmployeeFaceRules.isThreatened("search", true, FAR)).to.equal(false)
		end)
	end)

	describe("isCleaning", function()
		it("is cleaning while vacuuming", function()
			expect(EmployeeFaceRules.isCleaning(true, 10, nil)).to.equal(true)
		end)

		it("keeps cleaning for the short tail after the vacuum stops, then not", function()
			local now = 100
			local tail = EmployeeConstants.CLEANING_LINGER
			expect(EmployeeFaceRules.isCleaning(false, now, now - tail + 0.1)).to.equal(true)
			expect(EmployeeFaceRules.isCleaning(false, now, now - tail - 0.1)).to.equal(false)
		end)

		it("is not cleaning when the player never vacuumed", function()
			expect(EmployeeFaceRules.isCleaning(false, 10, nil)).to.equal(false)
		end)
	end)

	describe("isKnockedOut", function()
		it("is knocked out when dead or ragdolled", function()
			expect(EmployeeFaceRules.isKnockedOut(0, false)).to.equal(true)
			expect(EmployeeFaceRules.isKnockedOut(100, true)).to.equal(true)
			expect(EmployeeFaceRules.isKnockedOut(-5, true)).to.equal(true)
		end)

		it("is not knocked out while alive and standing", function()
			expect(EmployeeFaceRules.isKnockedOut(100, false)).to.equal(false)
			expect(EmployeeFaceRules.isKnockedOut(0.5, false)).to.equal(false)
		end)
	end)

	describe("stateOf", function()
		it("puts knocked out above everything, even a Manager still after this player", function()
			expect(EmployeeFaceRules.stateOf(true, true, true, true)).to.equal("knockedOut")
			expect(EmployeeFaceRules.stateOf(true, false, false, false)).to.equal("knockedOut")
		end)

		it("puts threatened above cleaning and carrying", function()
			expect(EmployeeFaceRules.stateOf(false, true, true, true)).to.equal("threatened")
		end)

		it("puts cleaning above carrying", function()
			expect(EmployeeFaceRules.stateOf(false, false, true, true)).to.equal("cleaning")
		end)

		it("is carrying with cargo in the hands or pockets", function()
			expect(EmployeeFaceRules.stateOf(false, false, false, true)).to.equal("carrying")
		end)

		it("is idle otherwise", function()
			expect(EmployeeFaceRules.stateOf(false, false, false, false)).to.equal("idle")
		end)
	end)

	describe("faceFor", function()
		local moody = {
			expressions = {
				knockedOut = "Dazed",
				threatened = "Worried",
				cleaning = "Content",
				carrying = "Happy",
				idle = "Worried",
			},
		}

		it("reads the face from the employee's own mapping", function()
			expect(EmployeeFaceRules.faceFor(moody, "threatened")).to.equal("Worried")
			expect(EmployeeFaceRules.faceFor(moody, "cleaning")).to.equal("Content")
			expect(EmployeeFaceRules.faceFor(moody, "carrying")).to.equal("Happy")
			expect(EmployeeFaceRules.faceFor(moody, "idle")).to.equal("Worried")
			expect(EmployeeFaceRules.faceFor(moody, "knockedOut")).to.equal("Dazed")
		end)
	end)
end
