local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeStatSystem = require(script.Parent.EmployeeStatSystem)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeStatFormulas = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeeStatFormulas)

local function body(walk: number)
	local model = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = walk
	humanoid.Parent = model
	return model, humanoid
end

local BARS = { speed = 5, stamina = 2, strength = 3, suction = 4, quiet = 1 }

return function()
	it("writes all five stat bars on the character", function()
		local model = body(16)
		EmployeeStatSystem.apply(model, BARS)
		for stat, bars in BARS do
			expect(model:GetAttribute(EmployeeConstants.STAT_ATTRIBUTES[stat])).to.equal(bars)
			expect(EmployeeStatFormulas.barsOn(model, stat)).to.equal(bars)
		end
		model:Destroy()
	end)

	it("scales the plain walk by Speed", function()
		local model, humanoid = body(16)
		EmployeeStatSystem.apply(model, BARS)
		expect(humanoid.WalkSpeed).to.be.near(16 * 1.06)
		model:Destroy()
	end)

	it("leaves the walk alone at 1 Speed (today's game)", function()
		local model, humanoid = body(16)
		EmployeeStatSystem.apply(model, { speed = 1, stamina = 1, strength = 1, suction = 1, quiet = 1 })
		expect(humanoid.WalkSpeed).to.equal(16)
		model:Destroy()
	end)

	it("applied again, moves the walk from the old Speed to the new one (never scales twice)", function()
		local model, humanoid = body(16)
		EmployeeStatSystem.apply(model, BARS)
		EmployeeStatSystem.apply(model, BARS)
		expect(humanoid.WalkSpeed).to.be.near(16 * 1.06)
		EmployeeStatSystem.apply(model, { speed = 1, stamina = 1, strength = 1, suction = 1, quiet = 1 })
		expect(humanoid.WalkSpeed).to.be.near(16)
		model:Destroy()
	end)

	it("writes the bars on a character without a humanoid", function()
		local model = Instance.new("Model")
		EmployeeStatSystem.apply(model, BARS)
		expect(EmployeeStatFormulas.barsOn(model, "suction")).to.equal(4)
		model:Destroy()
	end)
end
