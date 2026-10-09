local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local AnimationActionGrantSystem = require(ServerScriptService.Features.Animation.Systems.AnimationActionGrantSystem)

-- Always the last option (the highest variant).
local function lastRoll(count)
	return count
end

local function decide(id, options, roll)
	return AnimationActionGrantSystem.decide(id, AnimationRegistry.get(id), options, roll or lastRoll)
end

return function()
	describe("decide", function()
		it("refuses an unregistered id", function()
			local grant, reason = decide("no-such-action")
			expect(grant).to.equal(nil)
			expect(reason:find("not a registered", 1, true)).to.be.ok()
		end)

		it("refuses an entry that is not replicable (locomotion stays local)", function()
			local grant, reason = decide("idle")
			expect(grant).to.equal(nil)
			expect(reason:find("not a replicable", 1, true)).to.be.ok()
		end)

		it("grants a replicable one-shot on its layer, with its wire id", function()
			local def = AnimationRegistry.get("testleap")
			local grant = decide("testleap")
			expect(grant.layer).to.equal("full")
			expect(grant.def).to.equal(def)
			expect(grant.data.id).to.equal("testleap")
			expect(grant.data.wireId).to.equal(def.wireId)
		end)

		it("derives the duration from the declared length and the speed", function()
			local def = AnimationRegistry.get("testleap")
			expect(decide("testleap").durationMs).to.equal(def.durationMs)
			expect(decide("testleap", { speed = 2 }).durationMs).to.equal(math.floor(def.durationMs / 2 + 0.5))
		end)

		it("leaves a looped entry open-ended", function()
			local grant = decide("testpose")
			expect(grant.durationMs).to.equal(nil)
			expect(grant.layer).to.equal("upper")
		end)

		it("clamps the speed to 0.25-4 and quantises it to thousandths", function()
			expect(decide("testleap", { speed = 10 }).data.speedMilli).to.equal(4000)
			expect(decide("testleap", { speed = 0.1 }).data.speedMilli).to.equal(250)
			expect(decide("testleap", { speed = 1.23456 }).data.speedMilli).to.equal(1235)
			expect(decide("testleap").data.speedMilli).to.equal(1000)
		end)

		it("refuses a speed that is not a positive number", function()
			for _, bad in { 0, -1, 0 / 0, math.huge } do
				local grant, reason = decide("testleap", { speed = bad })
				expect(grant).to.equal(nil)
				expect(reason).to.be.ok()
			end
		end)

		it("rolls the variant on the server when none is asked for", function()
			expect(decide("testleap", nil, lastRoll).data.variant).to.equal(#AnimationRegistry.get("testleap").variants)
			expect(decide("testleap", nil, function()
				return 1
			end).data.variant).to.equal(0)
			expect(decide("testpose").data.variant).to.equal(0) -- no variants: always the entry's own
		end)

		it("honours a requested variant and refuses one out of range", function()
			expect(decide("testleap", { variant = 0 }).data.variant).to.equal(0)
			expect(decide("testleap", { variant = 1 }).data.variant).to.equal(1)
			expect(decide("testleap", { variant = 2 })).to.equal(nil)
			expect(decide("testleap", { variant = 0.5 })).to.equal(nil)
		end)
	end)

	describe("canReplace (one grant per layer)", function()
		local attack = { interruption = "attack" }
		local protected = { interruption = "protected" }
		local ambient = { interruption = "ambient" }

		it("lets anything take an empty layer", function()
			expect(AnimationActionGrantSystem.canReplace(nil, attack)).to.equal(true)
		end)

		it("lets an attack replace an attack or an ambient action", function()
			expect(AnimationActionGrantSystem.canReplace(attack, attack)).to.equal(true)
			expect(AnimationActionGrantSystem.canReplace(ambient, attack)).to.equal(true)
		end)

		it("never lets a non-protected action cut a protected one", function()
			expect(AnimationActionGrantSystem.canReplace(protected, attack)).to.equal(false)
			expect(AnimationActionGrantSystem.canReplace(protected, ambient)).to.equal(false)
		end)

		it("lets a protected action cut anything", function()
			expect(AnimationActionGrantSystem.canReplace(attack, protected)).to.equal(true)
			expect(AnimationActionGrantSystem.canReplace(protected, protected)).to.equal(true)
		end)
	end)
end
