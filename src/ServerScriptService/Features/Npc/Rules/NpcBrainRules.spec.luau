local ServerScriptService = game:GetService("ServerScriptService")

local NpcConstants = require(ServerScriptService.Features.Npc.Data.NpcConstants)
local NpcBrainRules = require(script.Parent.NpcBrainRules)

local function def(overrides)
	local result = table.clone(NpcConstants.DEFAULTS)
	for key, value in overrides do
		result[key] = value
	end
	return result
end

local THREAT = { position = Vector3.new(5, 0, 0), distance = 5 }

return function()
	describe("decide", function()
		it("a hostile NPC attacks in range and chases otherwise", function()
			local hostile = def({ attitude = "hostile", attackRange = 5 })
			local attack = NpcBrainRules.decide(hostile, { target = { userId = 7, distance = 4 }, hasPatrol = false })
			expect(attack.kind).to.equal("attack")
			expect(attack.target).to.equal(7)
			local chase = NpcBrainRules.decide(hostile, { target = { userId = 7, distance = 30 }, hasPatrol = false })
			expect(chase.kind).to.equal("chase")
		end)

		it("a timid NPC flees a threat in range", function()
			local timid = def({ attitude = "timid", fleeRange = 10 })
			local flee = NpcBrainRules.decide(timid, { threat = THREAT, hasPatrol = true })
			expect(flee.kind).to.equal("flee")
			expect(flee.from).to.equal(THREAT.position)
			local far = { position = Vector3.new(50, 0, 0), distance = 50 }
			expect(NpcBrainRules.decide(timid, { threat = far, hasPatrol = false }).kind).to.equal("wander")
		end)

		it("a passive NPC ignores targets and threats", function()
			local passive = def({ attitude = "passive" })
			local intent = NpcBrainRules.decide(passive, {
				target = { userId = 7, distance = 1 },
				threat = THREAT,
				hasPatrol = false,
			})
			expect(intent.kind).to.equal("wander")
		end)

		it("patrols when it has a route, wanders when it may, else idles", function()
			expect(NpcBrainRules.decide(def({ attitude = "hostile" }), { hasPatrol = true }).kind).to.equal("patrol")
			expect(NpcBrainRules.decide(def({ wanderRadius = 10 }), { hasPatrol = false }).kind).to.equal("wander")
			expect(NpcBrainRules.decide(def({ wanderRadius = 0 }), { hasPatrol = false }).kind).to.equal("idle")
		end)
	end)

	describe("poseFor", function()
		it("idles when still, walks up to walk speed and runs above it", function()
			expect(NpcBrainRules.poseFor(0.1, 8)).to.equal("idle")
			expect(NpcBrainRules.poseFor(6, 8)).to.equal("walk")
			expect(NpcBrainRules.poseFor(8.4, 8)).to.equal("walk")
			expect(NpcBrainRules.poseFor(14, 8)).to.equal("run")
		end)
	end)
end
