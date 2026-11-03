local AbilityRegistry = require(script.Parent.AbilityRegistry)

return function()
	it("gives each launch employee their ability", function()
		expect(AbilityRegistry.forEmployee("Pippa").id).to.equal("letsGo")
		expect(AbilityRegistry.forEmployee("Cappy").id).to.equal("spotIt")
		expect(AbilityRegistry.forEmployee("Prickles").id).to.equal("pottedPlant")
		expect(AbilityRegistry.forEmployee("Nobody")).to.equal(nil)
		expect(AbilityRegistry.get("letsGo").employee).to.equal("Pippa")
		expect(AbilityRegistry.get("nope")).to.equal(nil)
	end)

	it("matches the cards: cooldowns 45 / 40 / 45, effects 4 / 5 / 8 seconds", function()
		expect(AbilityRegistry.get("letsGo").cooldown).to.equal(45)
		expect(AbilityRegistry.get("spotIt").cooldown).to.equal(40)
		expect(AbilityRegistry.get("pottedPlant").cooldown).to.equal(45)
		expect(AbilityRegistry.get("letsGo").duration).to.equal(4)
		expect(AbilityRegistry.get("spotIt").duration).to.equal(5)
		expect(AbilityRegistry.get("pottedPlant").duration).to.equal(8)
	end)

	it("boosts the crew within 20 studs by 1.25", function()
		local letsGo = AbilityRegistry.get("letsGo")
		expect(letsGo.radius).to.equal(20)
		expect(letsGo.scale).to.equal(1.25)
	end)

	it("names clips by registry key only", function()
		for _, def in AbilityRegistry.all() do
			for _, key in def.clips do
				expect(type(key)).to.equal("string")
			end
		end
	end)
end
