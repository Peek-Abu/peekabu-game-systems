local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeStatFormulas = require(script.Parent.EmployeeStatFormulas)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

return function()
	it("reads an employee's level from their profile, the middle for anyone unknown", function()
		expect(EmployeeStatFormulas.level("Pippa", "speed")).to.equal(EmployeeProfileRegistry.get("Pippa").stats.speed)
		expect(EmployeeStatFormulas.level("Nobody", "quiet")).to.equal(EmployeeStatFormulas.MIDDLE)
		expect(EmployeeStatFormulas.MIDDLE).to.equal(3)
	end)

	it("changes nothing while stats are display only (every effect is exactly 1)", function()
		expect(EmployeeStatFormulas.STEP).to.equal(0)
		for _, name in EmployeeRegistry.names() do
			for _, stat in EmployeeProfileRegistry.STATS do
				expect(EmployeeStatFormulas.effect(name, stat)).to.equal(1)
			end
		end
		expect(EmployeeStatFormulas.effect("Nobody", "speed")).to.equal(1)
	end)

	it("keeps any later effect inside the narrow band, even at 1 and 5 bars", function()
		for level = 1, 5 do
			local value = EmployeeStatFormulas.effectOf(level)
			expect(value >= 1 - EmployeeStatFormulas.BAND and value <= 1 + EmployeeStatFormulas.BAND).to.equal(true)
		end
		expect(EmployeeStatFormulas.effectOf(EmployeeStatFormulas.MIDDLE)).to.equal(1)
	end)
end
