local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HidePoseFormulas = require(script.Parent.HidePoseFormulas)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

return function()
	describe("targets", function()
		it("has a Transform for every joint of the hug pose", function()
			local targets = HidePoseFormulas.targets()
			for _, entry in HideConstants.HUG_POSE do
				expect(targets[entry.joint]).never.to.equal(nil)
			end
			-- Hugging the knees: the hips swing the thighs forward, the waist bends the torso down.
			expect(targets.LeftHip:VectorToWorldSpace(Vector3.new(0, -1, 0)).Z < -0.9).to.equal(true)
			expect(targets.Waist:VectorToWorldSpace(Vector3.new(0, 1, 0)).Z < -0.7).to.equal(true)
		end)
	end)

	describe("weight", function()
		it("tucks in over TUCK_SECONDS and out over UNTUCK_SECONDS", function()
			expect(HidePoseFormulas.weight(0, true)).to.equal(0)
			expect(HidePoseFormulas.weight(HideConstants.TUCK_SECONDS, true)).to.equal(1)
			expect(HidePoseFormulas.weight(HideConstants.TUCK_SECONDS / 2, true) > 0.5).to.equal(true)
			expect(HidePoseFormulas.weight(0, false)).to.equal(1)
			expect(HidePoseFormulas.weight(HideConstants.UNTUCK_SECONDS, false)).to.equal(0)
			expect(HidePoseFormulas.weight(-1, true)).to.equal(0)
			expect(HidePoseFormulas.weight(99, false)).to.equal(0)
		end)
	end)

	describe("blend", function()
		it("keeps the animation at 0 and the pose at 1", function()
			local animated = CFrame.Angles(0.2, 0, 0)
			local target = CFrame.new(0, -1, 0)
			local blended = { HidePoseFormulas.blend(animated, target, 0):GetComponents() }
			for i, value in { animated:GetComponents() } do
				expect(math.abs(blended[i] - value) < 1e-4).to.equal(true)
			end
			expect(HidePoseFormulas.blend(animated, target, 1).Position.Y).to.be.near(-1, 1e-6)
		end)
	end)
end
