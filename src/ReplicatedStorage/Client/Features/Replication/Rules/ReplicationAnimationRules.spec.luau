local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationAnimationRules = require(ReplicatedStorage.Client.Features.Replication.Rules.ReplicationAnimationRules)

local C = ReplicationAnimationRules.DEFAULT_CONFIG
local SIZE = Vector2.new(800, 600)

return function()
	describe("decide", function()
		it("keeps a near, on-screen puppet full", function()
			expect(ReplicationAnimationRules.decide("full", 100, true, C)).to.equal("full")
		end)

		it("freezes a puppet that leaves the screen, however near", function()
			expect(ReplicationAnimationRules.decide("full", 10, false, C)).to.equal("frozen")
		end)

		it("freezes a full puppet only past fullStuds + hysteresis", function()
			expect(ReplicationAnimationRules.decide("full", C.fullStuds + C.hysteresisStuds, true, C)).to.equal("full")
			expect(ReplicationAnimationRules.decide("full", C.fullStuds + C.hysteresisStuds + 1, true, C)).to.equal(
				"frozen"
			)
		end)

		it("unfreezes only on screen and within fullStuds", function()
			expect(ReplicationAnimationRules.decide("frozen", C.fullStuds + 10, true, C)).to.equal("frozen")
			expect(ReplicationAnimationRules.decide("frozen", C.fullStuds, true, C)).to.equal("full")
			expect(ReplicationAnimationRules.decide("frozen", 100, false, C)).to.equal("frozen")
		end)

		it("does not flicker for a puppet pacing inside the hysteresis band", function()
			local tier = "full"
			for _, distance in { 240, 255, 270, 255, 240, 270 } do
				tier = ReplicationAnimationRules.decide(tier, distance, true, C)
				expect(tier).to.equal("full")
			end
			tier = "frozen"
			for _, distance in { 270, 260, 255, 270 } do
				tier = ReplicationAnimationRules.decide(tier, distance, true, C)
				expect(tier).to.equal("frozen")
			end
		end)
	end)

	describe("isOnScreen", function()
		it("accepts a point inside the viewport", function()
			expect(ReplicationAnimationRules.isOnScreen(Vector3.new(400, 300, 10), SIZE, 64)).to.equal(true)
		end)

		it("accepts a point just outside the edge, inside the margin", function()
			expect(ReplicationAnimationRules.isOnScreen(Vector3.new(-50, 300, 10), SIZE, 64)).to.equal(true)
			expect(ReplicationAnimationRules.isOnScreen(Vector3.new(850, 300, 10), SIZE, 64)).to.equal(true)
		end)

		it("rejects a point beyond the margin", function()
			expect(ReplicationAnimationRules.isOnScreen(Vector3.new(-70, 300, 10), SIZE, 64)).to.equal(false)
			expect(ReplicationAnimationRules.isOnScreen(Vector3.new(400, 700, 10), SIZE, 64)).to.equal(false)
		end)

		it("rejects a point behind the camera", function()
			expect(ReplicationAnimationRules.isOnScreen(Vector3.new(400, 300, -5), SIZE, 64)).to.equal(false)
		end)
	end)

	describe("nextCheckAt", function()
		it("spaces checks at the configured rate", function()
			expect(ReplicationAnimationRules.nextCheckAt(10, 4)).to.be.near(10.25, 1e-9)
		end)

		it("staggers a first check by its phase", function()
			expect(ReplicationAnimationRules.nextCheckAt(10, 4, 0.5)).to.be.near(10.125, 1e-9)
		end)
	end)

	it("uses the spec's defaults: full within 250 studs, re-evaluated 4 times a second", function()
		expect(C.fullStuds).to.equal(250)
		expect(C.rateHz).to.equal(4)
		expect(table.isfrozen(C)).to.equal(true)
	end)
end
