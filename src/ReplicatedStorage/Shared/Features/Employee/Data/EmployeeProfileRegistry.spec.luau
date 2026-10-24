local EmployeeProfileRegistry = require(script.Parent.EmployeeProfileRegistry)
local EmployeeRegistry = require(script.Parent.EmployeeRegistry)

return function()
	it("has a profile for every employee, with copy and a colour", function()
		for _, name in EmployeeRegistry.names() do
			local profile = EmployeeProfileRegistry.get(name)
			expect(profile).to.be.ok()
			for _, text in
				{
					profile.kind,
					profile.line,
					profile.bio,
					profile.funFact,
					profile.ability.name,
					profile.ability.line,
					profile.ability.detail,
				}
			do
				expect(type(text) == "string" and text ~= "").to.equal(true)
			end
			expect(#profile.words).to.equal(3)
			expect(profile.ability.cooldown > 0).to.equal(true)
			expect(typeof(profile.color.body)).to.equal("Color3")
			expect(typeof(profile.color.light)).to.equal("Color3")
			expect(typeof(profile.color.dark)).to.equal("Color3")
		end
		expect(EmployeeProfileRegistry.get("Nobody")).to.equal(nil)
	end)

	it("keeps every display stat 1-5 and every employee's total equal (no one is simply better)", function()
		local total = nil
		for _, name in EmployeeRegistry.names() do
			local stats = EmployeeProfileRegistry.get(name).stats
			local sum = 0
			for _, stat in EmployeeProfileRegistry.STATS do
				local value = stats[stat]
				expect(value >= 1 and value <= 5 and value == math.floor(value)).to.equal(true)
				sum += value
			end
			total = total or sum
			expect(sum).to.equal(total)
		end
	end)

	it("lists the five stats in display order", function()
		expect(table.concat(EmployeeProfileRegistry.STATS, ",")).to.equal("speed,stamina,strength,suction,quiet")
	end)
end
