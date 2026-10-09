local VoiceRoutingRules = require(script.Parent.VoiceRoutingRules)

local living = { dead = false }
local dead = { dead = true }
local radioA = { dead = false, radio = "A" }
local radioA2 = { dead = false, radio = "A" }
local radioB = { dead = false, radio = "B" }

return function()
	describe("route", function()
		it("the living hear the living by distance", function()
			expect(VoiceRoutingRules.route(living, living, true)).to.equal("spatial")
		end)

		it("the living never hear the dead", function()
			expect(VoiceRoutingRules.route(living, dead, true)).to.equal("none")
			expect(VoiceRoutingRules.route(radioA, { dead = true, radio = "A" }, true)).to.equal("none")
		end)

		it("the dead hear each other flat, and the living spatially when allowed", function()
			expect(VoiceRoutingRules.route(dead, dead, true)).to.equal("direct")
			expect(VoiceRoutingRules.route(dead, living, true)).to.equal("spatial")
			expect(VoiceRoutingRules.route(dead, living, false)).to.equal("none")
		end)

		it("two living players on the same radio channel hear the radio", function()
			expect(VoiceRoutingRules.route(radioA, radioA2, true)).to.equal("radio")
			expect(VoiceRoutingRules.route(radioA, radioB, true)).to.equal("spatial")
			expect(VoiceRoutingRules.route(living, radioA, true)).to.equal("spatial")
		end)
	end)

	describe("infoFrom", function()
		it("reads the dead and radio fields off a public entry", function()
			local info = VoiceRoutingRules.infoFrom({ dead = true, radio = "A" }, "dead", "radio")
			expect(info.dead).to.equal(true)
			expect(info.radio).to.equal("A")
			local none = VoiceRoutingRules.infoFrom(nil, "dead", "radio")
			expect(none.dead).to.equal(false)
			expect(none.radio).to.equal(nil)
			expect(VoiceRoutingRules.infoFrom({ radio = 5 }, "dead", "radio").radio).to.equal(nil)
		end)
	end)

	describe("listenersOf", function()
		it("lists everyone who may hear a speaker, sorted, never the speaker", function()
			local infos = { [1] = living, [2] = dead, [3] = living, [4] = dead }
			local forLiving = VoiceRoutingRules.listenersOf(1, infos, true)
			expect(#forLiving).to.equal(3)
			expect(forLiving[1]).to.equal(2)
			local forDead = VoiceRoutingRules.listenersOf(2, infos, true)
			expect(#forDead).to.equal(1)
			expect(forDead[1]).to.equal(4)
		end)
	end)
end
