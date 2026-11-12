local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingCreepRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingCreepRules)

local function near(a: Vector3, b: Vector3): boolean
	return (a - b).Magnitude < 1e-4
end

return function()
	describe("grow", function()
		-- A goo blob: a cylinder turned so its axis (local X) points up, lying on the floor off the patch's centre.
		local upright = CFrame.Angles(0, 0, math.pi / 2)
		local offset = CFrame.new(2, 0.05, -1) * upright
		local size = Vector3.new(0.1, 3, 2)

		it("is the authored blob at full size", function()
			local frame, grown = TrainingCreepRules.grow(offset, size, 1)
			expect(near(frame.Position, offset.Position)).to.equal(true)
			expect(near(grown, size)).to.equal(true)
		end)

		it("starts small and close to the patch's centre, flat on the floor, never thinner", function()
			local frame, grown = TrainingCreepRules.grow(offset, size, 0.2)
			expect(near(frame.Position, Vector3.new(0.4, 0.05, -0.2))).to.equal(true)
			-- The thickness (the axis that points up) keeps its size; the round face shrinks.
			expect(near(grown, Vector3.new(0.1, 0.6, 0.4))).to.equal(true)
			expect(frame.UpVector:Dot(offset.UpVector) > 0.9999).to.equal(true)
		end)

		it("finds the up axis whichever way a blob is turned", function()
			local flat = CFrame.new(1, 0, 1) * CFrame.Angles(0, math.rad(30), 0)
			local _, grown = TrainingCreepRules.grow(flat, Vector3.new(2, 0.1, 3), 0.5)
			expect(near(grown, Vector3.new(1, 0.1, 1.5))).to.equal(true)
		end)
	end)
end
