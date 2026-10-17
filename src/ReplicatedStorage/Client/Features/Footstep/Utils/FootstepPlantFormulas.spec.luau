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

		it("plants every contact of a run whose second stride stands higher than its first (Pippa's sprint)", function()
			-- Pippa's run clip holds two strides per loop and the second stands ~0.11 studs higher. One loop of her left
			-- foot's height (foot centre minus root), measured live at 60 fps at sprint speed 2026-10-17: the deep
			-- contact bottoms at frame 9, the shallow one at frame 23. Every 2nd contact used to be lost (a gallop).
			local loop = {
				-0.881,
				-0.897,
				-0.917,
				-0.951,
				-0.998,
				-1.042,
				-1.081,
				-1.108,
				-1.113,
				-1.095,
				-1.038,
				-0.939,
				-0.865,
				-0.816,
				-0.792,
				-0.790,
				-0.809,
				-0.843,
				-0.884,
				-0.928,
				-0.969,
				-0.994,
				-1.000,
				-0.998,
				-0.979,
				-0.946,
				-0.911,
				-0.884,
			}
			local bottoms = { 9, 23 }
			local foot = FootstepPlantFormulas.fresh(loop[1])
			local plants = {}
			local frame = 1
			for _ = 1, 8 do
				for index, height in loop do
					if frame > 1 and FootstepPlantFormulas.step(foot, height, DT, 0.375) then
						table.insert(plants, { frame = frame, index = index })
					end
					frame += 1
				end
			end
			-- 8 loops, two contacts each, but the first (the foot is first seen already coming down to it, never armed).
			expect(#plants).to.equal(15)
			for _, plant in plants do
				-- At its contact: no earlier than 3 frames before the bottom, no later than the frame after it.
				local near = false
				for _, bottom in bottoms do
					if plant.index >= bottom - 3 and plant.index <= bottom + 1 then
						near = true
					end
				end
				expect(near).to.equal(true)
			end
		end)

		it("is not a step when a foot only shuffles as the walk starts (the other foot's plant)", function()
			-- Pippa's left foot as she sets off from idle, measured live 2026-10-17 at 60 fps: a 0.06-stud shuffle back
			-- down to her stand while the right foot plants, then the real lift into the walk.
			local start = {
				-1.113,
				-1.112,
				-1.113,
				-1.108,
				-1.115,
				-1.128,
				-1.138,
				-1.132,
				-1.125,
				-1.127,
				-1.116,
				-1.093,
				-1.077,
				-1.077,
				-1.091,
				-1.112,
				-1.113,
				-1.078,
				-0.987,
				-0.894,
			}
			local foot = FootstepPlantFormulas.fresh(start[1])
			for index = 2, #start do
				expect(FootstepPlantFormulas.step(foot, start[index], DT, 0.375)).to.equal(false)
			end
		end)

		it("is not a step when a swinging foot wobbles in the upper half of its swing", function()
			local foot = FootstepPlantFormulas.fresh(-2)
			local plants = 0
			local t = 0
			while t < 5 do
				t += DT
				local phase = (t % 1) / 1
				-- Up to 0.3, a dip back to 0.2 (still the upper half), up again, then down to stand at phase 0.5.
				local height = -2
				if phase < 0.5 then
					local swing = math.sin(phase * 2 * math.pi)
					height = -2 + 0.3 * swing - 0.12 * math.max(0, math.sin((phase - 0.15) / 0.2 * math.pi)) * swing
				end
				if FootstepPlantFormulas.step(foot, height, DT, 1) then
					plants += 1
				end
			end
			-- One contact per 1 s stride: 5.
			expect(plants).to.equal(5)
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
