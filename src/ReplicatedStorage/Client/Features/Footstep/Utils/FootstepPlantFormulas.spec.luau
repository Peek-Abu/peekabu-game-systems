local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootstepPlantFormulas = require(script.Parent.FootstepPlantFormulas)
local FootstepConstants = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepConstants)

local DT = 1 / 60

-- A foot that swings `lift` studs up for the first half of each `period` and stands for the second half.
-- Contact (the ground truth) is at period/2 + k*period.
local function walk(period, lift, seconds, scale, base)
	local foot = FootstepPlantFormulas.fresh(base or -2)
	local plants = {}
	local t = 0
	while t < seconds do
		t += DT
		local phase = (t % period) / period
		local height = (base or -2) + lift * math.max(0, math.sin(phase * 2 * math.pi))
		if FootstepPlantFormulas.step(foot, height, DT, scale) then
			table.insert(plants, t)
		end
	end
	return plants
end

return function()
	describe("step", function()
		it("plants once per stride, just at contact", function()
			local period = 0.9
			local plants = walk(period, 0.3, 5, 1)
			-- 5 s of 0.9 s strides: contacts at 0.45, 1.35, ... 4.95 (6 of them).
			expect(#plants).to.equal(6)
			for index, at in plants do
				local contact = period / 2 + (index - 1) * period
				expect(at <= contact + DT).to.equal(true)
				expect(contact - at < 0.06 * period + DT).to.equal(true)
			end
		end)

		it("keeps up with a sprint's short strides on a tall rig", function()
			local plants = walk(0.5, 1.2, 3, 3.5)
			expect(#plants).to.equal(6)
		end)

		it("never plants a still foot", function()
			local foot = FootstepPlantFormulas.fresh(-2)
			for _ = 1, 600 do
				expect(FootstepPlantFormulas.step(foot, -2, DT, 1)).to.equal(false)
			end
		end)

		it("ignores an idle sway smaller than MIN_RANGE of the rig", function()
			local sway = FootstepConstants.MIN_RANGE * 0.8
			expect(#walk(1.5, sway, 6, 1)).to.equal(0)
			-- The same sway on a small rig is a step.
			expect(#walk(1.5, sway, 6, 0.5) > 0).to.equal(true)
		end)

		it("is not a step when a foot is held up longer than a swing (sitting, then standing)", function()
			local foot = FootstepPlantFormulas.fresh(-2)
			local planted = false
			for _ = 1, 30 do
				planted = FootstepPlantFormulas.step(foot, -2, DT, 1) or planted
			end
			for _ = 1, math.ceil((FootstepConstants.MAX_SWING + 1) / DT) do
				planted = FootstepPlantFormulas.step(foot, -1.4, DT, 1) or planted
			end
			for _ = 1, 30 do
				planted = FootstepPlantFormulas.step(foot, -2, DT, 1) or planted
			end
			expect(planted).to.equal(false)
		end)

		it("adapts to a new floor level (scaled rig, a seat) within a few strides", function()
			local foot = FootstepPlantFormulas.fresh(-5)
			local plants = 0
			local t = 0
			while t < 6 do
				t += DT
				local phase = (t % 0.8) / 0.8
				local height = -2 + 0.3 * math.max(0, math.sin(phase * 2 * math.pi))
				if FootstepPlantFormulas.step(foot, height, DT, 1) then
					plants += 1
				end
			end
			-- 7 contacts in 6 s; only those inside the first WINDOW (while the old floor is remembered) may be lost.
			expect(plants >= 7 - math.ceil(FootstepConstants.WINDOW / 0.8) and plants <= 7).to.equal(true)
		end)
	end)
end
