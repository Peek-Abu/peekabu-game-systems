local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local Formulas = require(script.Parent.VacuumPileFormulas)

return function()
	local function bottomOf(frame, size)
		return (frame * CFrame.new(0, -size.Y / 2, 0)).Position
	end

	it("stands a new pile with its base exactly on the floor point it spawns on", function()
		local size = Vector3.new(4, 1.2, 3)
		for _, floor in { CFrame.new(10, 0, -4), CFrame.new(-3, 7.5, 2) * CFrame.Angles(0, 1.1, 0) } do
			local frame = Formulas.standing(floor, size)
			expect((bottomOf(frame, size) - floor.Position).Magnitude < 1e-5).to.equal(true)
			-- upright: same facing as the floor point
			expect((frame.LookVector - floor.LookVector).Magnitude < 1e-5).to.equal(true)
		end
	end)

	it("shrinks from full size at no progress to MIN_SCALE when cleared, never below", function()
		expect(Formulas.scaleAt(0)).to.equal(1)
		expect(Formulas.scaleAt(1)).to.be.near(VacuumConstants.MIN_SCALE, 1e-9)
		expect(Formulas.scaleAt(0.5)).to.be.near(1 - (1 - VacuumConstants.MIN_SCALE) / 2, 1e-9)
		expect(Formulas.scaleAt(2)).to.be.near(VacuumConstants.MIN_SCALE, 1e-9)
		expect(Formulas.scaleAt(-1)).to.equal(1)
	end)

	it("shrinks toward its base: the bottom stays on the floor at every step, never lifting or sinking", function()
		local base = Vector3.new(4, 1.2, 3)
		local floor = CFrame.new(5, 2, 5) * CFrame.Angles(0, 0.4, 0)
		local frame, size = Formulas.standing(floor, base), base
		for step = 1, 20 do
			frame, size = Formulas.shrunk(frame, size, base, step / 20)
			expect((size - base * Formulas.scaleAt(step / 20)).Magnitude < 1e-5).to.equal(true)
			expect((bottomOf(frame, size) - floor.Position).Magnitude < 1e-4).to.equal(true)
			expect((frame.LookVector - floor.LookVector).Magnitude < 1e-5).to.equal(true)
		end
	end)
end
