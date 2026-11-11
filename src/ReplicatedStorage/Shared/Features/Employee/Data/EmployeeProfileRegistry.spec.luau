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
					profile.ability.icon,
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

	it("keeps every stat in the narrow 2-4 band (no one is very weak at anything)", function()
		for _, name in EmployeeRegistry.names() do
			for _, stat in EmployeeProfileRegistry.STATS do
				local value = EmployeeProfileRegistry.get(name).stats[stat]
				expect(value >= 2 and value <= 4).to.equal(true)
			end
		end
	end)

	it("keeps the owner's spreads: Pippa quick, Cappy quiet, Prickles the all-rounder", function()
		local function spread(name)
			local stats = EmployeeProfileRegistry.get(name).stats
			local values = {}
			for _, stat in EmployeeProfileRegistry.STATS do
				table.insert(values, stats[stat])
			end
			return table.concat(values, ",")
		end
		expect(spread("Pippa")).to.equal("4,4,2,3,2")
		expect(spread("Cappy")).to.equal("3,2,3,3,4")
		expect(spread("Prickles")).to.equal("3,3,3,3,3")
	end)

	it("words abilities for every map's monster", function()
		expect(EmployeeProfileRegistry.get("Prickles").ability.detail).to.equal(
			"Stand still as a potted plant for up to 8 seconds. Monsters walk right past."
		)
		for _, name in EmployeeRegistry.names() do
			local detail = string.lower(EmployeeProfileRegistry.get(name).ability.detail)
			expect(string.find(detail, "manager", 1, true)).to.equal(nil)
			expect(string.find(detail, "harlow", 1, true)).to.equal(nil)
		end
	end)

	it("lists the five stats in display order", function()
		expect(table.concat(EmployeeProfileRegistry.STATS, ",")).to.equal("speed,stamina,strength,suction,quiet")
	end)
end
