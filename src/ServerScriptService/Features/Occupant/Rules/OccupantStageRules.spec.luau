local OccupantStageRules = require(script.Parent.OccupantStageRules)
local OccupantBrainRules = require(script.Parent.OccupantBrainRules)

local function senses(players)
	return {
		position = Vector3.new(0, 3, 0),
		look = Vector3.new(1, 0, 0),
		now = 100,
		sightRange = 60,
		sightAngle = 120,
		players = players or {},
		resting = false,
		route = { Vector3.new(10, 0, 0) },
		restPoint = Vector3.new(50, 0, 50),
		zone = { min = Vector3.new(-100, -5, -100), max = Vector3.new(100, 20, 100) },
	}
end

return function()
	describe("parse", function()
		it("takes every staging action and nothing else", function()
			for _, action in { "freeze", "free", "come", "rush", "here", "calm", "chase" } do
				expect(OccupantStageRules.parse(action)).to.equal(action)
			end
			expect(OccupantStageRules.parse("dance")).to.equal(nil)
			expect(OccupantStageRules.parse("")).to.equal(nil)
		end)

		it("is case-insensitive", function()
			expect(OccupantStageRules.parse("Freeze")).to.equal("freeze")
		end)

		it("needs a player only to chase", function()
			expect(OccupantStageRules.needsTarget("chase")).to.equal(true)
			expect(OccupantStageRules.needsTarget("freeze")).to.equal(false)
		end)
	end)

	describe("intent", function()
		it("stands still while frozen, and stays frozen", function()
			local stage = { kind = "freeze" }
			local intent, nextStage = OccupantStageRules.intent(stage, Vector3.new(0, 3, 0))
			expect(intent.kind).to.equal("idle")
			expect(nextStage).to.equal(stage)
		end)

		it("walks or runs to a staged spot", function()
			local target = Vector3.new(30, 3, 0)
			local walk =
				OccupantStageRules.intent({ kind = "goTo", position = target, run = false }, Vector3.new(0, 3, 0))
			expect(walk.kind).to.equal("goTo")
			expect(walk.position).to.equal(target)
			expect(walk.run).to.equal(false)
			local run =
				OccupantStageRules.intent({ kind = "goTo", position = target, run = true }, Vector3.new(0, 3, 0))
			expect(run.run).to.equal(true)
		end)

		it("freezes once he arrives (height does not count)", function()
			local stage = { kind = "goTo", position = Vector3.new(1, 10, 1), run = false }
			local intent, nextStage = OccupantStageRules.intent(stage, Vector3.new(0, 3, 0))
			expect(intent.kind).to.equal("idle")
			expect(nextStage.kind).to.equal("freeze")
		end)
	end)

	describe("standIn", function()
		it("stands him on the caller's floor at his own height, facing their way", function()
			local caller = CFrame.lookAt(Vector3.new(10, 2.2, 5), Vector3.new(10, 2.2, -5))
			local spot = OccupantStageRules.standIn(caller, 0, 4.6)
			expect(spot.Position).to.equal(Vector3.new(10, 4.6, 5))
			expect((spot.LookVector - Vector3.new(0, 0, -1)).Magnitude < 1e-4).to.equal(true)
		end)

		it("faces level even when the caller looks down", function()
			local caller = CFrame.lookAt(Vector3.new(0, 2, 0), Vector3.new(3, -10, 0))
			local spot = OccupantStageRules.standIn(caller, 0, 4)
			expect(math.abs(spot.LookVector.Y) < 1e-4).to.equal(true)
			expect(spot.LookVector.X > 0.99).to.equal(true)
		end)
	end)

	describe("facing", function()
		it("turns him in place to look flat at a point", function()
			local root = CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
			local turned = OccupantStageRules.facing(root, Vector3.new(10, 0, 0))
			expect(turned.Position).to.equal(root.Position)
			expect(math.abs(turned.LookVector.Y) < 1e-4).to.equal(true)
			expect(turned.LookVector.X > 0.99).to.equal(true)
		end)

		it("keeps his facing when the point is straight above or below him", function()
			local root = CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
			local turned = OccupantStageRules.facing(root, Vector3.new(0, -5, 0))
			expect((turned.LookVector - root.LookVector).Magnitude < 1e-4).to.equal(true)
		end)
	end)

	describe("chase", function()
		it("starts a chase on the named player when he senses them", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			local glimpse = { userId = 7, position = Vector3.new(40, 3, 0), clear = false }
			local nextMind, ok = OccupantStageRules.chase(mind, senses({ glimpse }), 7)
			expect(ok).to.equal(true)
			expect(nextMind.mode).to.equal("chase")
			expect(nextMind.target).to.equal(7)
			expect(nextMind.lastSeen).to.equal(glimpse.position)
		end)

		it("does nothing when the player is not in the shift", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			local nextMind, ok = OccupantStageRules.chase(mind, senses({}), 7)
			expect(ok).to.equal(false)
			expect(nextMind).to.equal(mind)
		end)

		it("never interrupts a catch", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			mind.mode = "catch"
			local glimpse = { userId = 7, position = Vector3.new(40, 3, 0), clear = true }
			local nextMind, ok = OccupantStageRules.chase(mind, senses({ glimpse }), 7)
			expect(ok).to.equal(false)
			expect(nextMind).to.equal(mind)
		end)
	end)

	describe("calm", function()
		it("gives every player a grace period without touching the old mind", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			local nextMind = OccupantStageRules.calm(mind, { 1, 2 }, 100)
			expect(nextMind.grace[1]).to.equal(100 + OccupantStageRules.CALM_SECONDS)
			expect(nextMind.grace[2]).to.equal(100 + OccupantStageRules.CALM_SECONDS)
			expect(mind.grace[1]).to.equal(nil)
		end)

		it("drops a chase back to his route", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			mind.mode = "chase"
			mind.target = 1
			local nextMind = OccupantStageRules.calm(mind, { 1 }, 100)
			expect(nextMind.mode).to.equal("patrol")
			expect(nextMind.target).to.equal(nil)
		end)
	end)
end
