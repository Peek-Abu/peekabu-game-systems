local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeStatFormulas = require(script.Parent.EmployeeStatFormulas)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

return function()
	it("reads an employee's bars from their profile, the floor (today's game) for anyone unknown", function()
		expect(EmployeeStatFormulas.level("Pippa", "speed")).to.equal(EmployeeProfileRegistry.get("Pippa").stats.speed)
		expect(EmployeeStatFormulas.level("Nobody", "quiet")).to.equal(EmployeeStatFormulas.FLOOR)
		expect(EmployeeStatFormulas.FLOOR).to.equal(1)
	end)

	it("plays 1 bar exactly like today's game for every stat", function()
		for _, stat in EmployeeProfileRegistry.STATS do
			expect(EmployeeStatFormulas.gain(stat, 1)).to.equal(0)
			expect(EmployeeStatFormulas.effect(stat, 1)).to.equal(1)
			expect(EmployeeStatFormulas.cut(stat, 1)).to.equal(1)
		end
	end)

	it("adds the approved step per bar above 1", function()
		expect(EmployeeStatFormulas.effect("speed", 5)).to.be.near(1.06)
		expect(EmployeeStatFormulas.effect("stamina", 4)).to.be.near(1.15)
		expect(EmployeeStatFormulas.cut("strength", 5)).to.be.near(0.84)
		expect(EmployeeStatFormulas.effect("suction", 3)).to.be.near(1.08)
		expect(EmployeeStatFormulas.cut("quiet", 2)).to.be.near(0.96)
	end)

	it("keeps every stat's 1-to-5 spread inside the band", function()
		for _, stat in EmployeeProfileRegistry.STATS do
			for bars = 1, 5 do
				local gain = EmployeeStatFormulas.gain(stat, bars)
				expect(gain >= 0 and gain <= EmployeeStatFormulas.BAND).to.equal(true)
			end
		end
	end)

	it("clamps and rounds bars, and treats anything that is not a number as the floor", function()
		expect(EmployeeStatFormulas.barsFrom(0)).to.equal(1)
		expect(EmployeeStatFormulas.barsFrom(9)).to.equal(5)
		expect(EmployeeStatFormulas.barsFrom(3.4)).to.equal(3)
		expect(EmployeeStatFormulas.barsFrom(0 / 0)).to.equal(1)
		expect(EmployeeStatFormulas.barsFrom("5")).to.equal(1)
		expect(EmployeeStatFormulas.barsFrom(nil)).to.equal(1)
		expect(EmployeeStatFormulas.gain("speed", 99)).to.equal(EmployeeStatFormulas.gain("speed", 5))
	end)

	it("reads a character's bars from its stat attributes, the floor without one", function()
		local character = Instance.new("Model")
		character:SetAttribute(EmployeeConstants.STAT_ATTRIBUTES.quiet, 4)
		expect(EmployeeStatFormulas.barsOn(character, "quiet")).to.equal(4)
		expect(EmployeeStatFormulas.barsOn(character, "speed")).to.equal(1)
		expect(EmployeeStatFormulas.barsOn(nil, "speed")).to.equal(1)
		character:Destroy()
	end)

	it("gives every employee's spread the same total", function()
		local total = nil
		for _, name in EmployeeRegistry.names() do
			local sum = 0
			for _, stat in EmployeeProfileRegistry.STATS do
				sum += EmployeeStatFormulas.level(name, stat)
			end
			total = total or sum
			expect(sum).to.equal(total)
		end
	end)
end
