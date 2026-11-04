local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmoteLassoConstants = require(ReplicatedStorage.Client.Features.Emote.Data.EmoteLassoConstants)
local EmoteLassoFormulas = require(script.Parent.EmoteLassoFormulas)

return function()
	local T = EmoteLassoConstants.TUNING
	local HEIGHT = EmoteLassoConstants.TEMPLATE_HEIGHT

	-- The LassoLoop part's pose for a rope standing up at `at`, the ring turned `angle` about it.
	local function upright(at, angle)
		return CFrame.new(at) * CFrame.Angles(0, angle, 0)
	end

	local function bendAngles(state)
		local out = {}
		for i = 2, #state.rope - 1 do
			local a = state.rope[i] - state.rope[i - 1]
			local b = state.rope[i + 1] - state.rope[i]
			local c = math.clamp(a:Dot(b) / (a.Magnitude * b.Magnitude + 1e-9), -1, 1)
			table.insert(out, math.deg(math.acos(c)))
		end
		return out
	end

	-- Runs `seconds` of substeps with the pose given by `pose(t)`.
	local function run(state, seconds, pose, look, tuning)
		local t = 0
		while t < seconds do
			local driver = EmoteLassoFormulas.driverOf(pose(t), HEIGHT, look or Vector3.new(0, 0, -1))
			state = EmoteLassoFormulas.step(state, driver, T.substep, tuning or T)
			t += T.substep
		end
		return state
	end

	describe("reachAt", function()
		it("is out, held, then back: 0 before, 1 in the hold, 0 after", function()
			expect(EmoteLassoFormulas.reachAt(-0.1, T)).to.equal(0)
			expect(EmoteLassoFormulas.reachAt(T.throwOut + T.throwHold / 2, T)).to.equal(1)
			expect(EmoteLassoFormulas.reachAt(T.throwOut + T.throwHold + T.throwBack + 0.01, T)).to.equal(0)
			local rising = EmoteLassoFormulas.reachAt(T.throwOut / 2, T)
			expect(rising > 0 and rising < 1).to.equal(true)
		end)
	end)

	describe("driverOf", function()
		it("reads the grip, the knot above it and the scale from the part", function()
			local d = EmoteLassoFormulas.driverOf(CFrame.new(), HEIGHT * 2, Vector3.new(0, 0, -1))
			expect(d.scale).to.be.near(2, 1e-6)
			expect((d.knot - d.grip).Magnitude).to.be.near(T.ropeLength * 2, 1e-4)
			expect(d.up:FuzzyEq(Vector3.yAxis, 1e-6)).to.equal(true)
			expect(d.facing:FuzzyEq(Vector3.new(0, 0, -1), 1e-6)).to.equal(true)
		end)
	end)

	describe("step", function()
		it("starts with the rope straight from the hand to the knot and the ring through the knot", function()
			local d = EmoteLassoFormulas.driverOf(upright(Vector3.zero, 0), HEIGHT, Vector3.new(0, 0, -1))
			local s = EmoteLassoFormulas.step(EmoteLassoFormulas.newState(), d, T.substep, T)
			expect(s.live).to.equal(true)
			expect(#s.rope).to.equal(T.ropePoints + 1)
			expect(#s.ring).to.equal(T.ringPoints)
			expect(s.rope[1]:FuzzyEq(d.grip, 1e-4)).to.equal(true)
			expect(s.ring[1]:FuzzyEq(s.rope[#s.rope], 1e-6)).to.equal(true)
		end)

		it("keeps the hand end pinned and the first segment straight along the rope", function()
			local s = run(EmoteLassoFormulas.newState(), 1, function(t)
				return upright(Vector3.zero, t * 7)
			end)
			local d = EmoteLassoFormulas.driverOf(upright(Vector3.zero, 7), HEIGHT, Vector3.new(0, 0, -1))
			expect(s.rope[1]:FuzzyEq(d.grip, 1e-3)).to.equal(true)
			local first = (s.rope[2] - s.rope[1]).Unit
			expect(first:Dot(d.up) > 0.999).to.equal(true)
		end)

		it("never folds the rope back on itself through a fast spin (the crumple)", function()
			local worst = 0
			local s = EmoteLassoFormulas.newState()
			local t = 0
			while t < 2 do
				local d = EmoteLassoFormulas.driverOf(upright(Vector3.zero, t * 9), HEIGHT, Vector3.new(0, 0, -1))
				s = EmoteLassoFormulas.step(s, d, T.substep, T)
				for _, angle in bendAngles(s) do
					worst = math.max(worst, angle)
				end
				t += T.substep
			end
			expect(worst < 90).to.equal(true)
		end)

		it("keeps the ring's length (it bends, it does not stretch)", function()
			local s = run(EmoteLassoFormulas.newState(), 1.5, function(t)
				return upright(Vector3.zero, t * 7)
			end)
			local perimeter = 0
			for i = 1, #s.ring do
				perimeter += (s.ring[i % #s.ring + 1] - s.ring[i]).Magnitude
			end
			expect(perimeter).to.be.near(2 * math.pi * T.ringRadius, 0.1 * 2 * math.pi * T.ringRadius)
		end)

		it("changes the loop's shape as it spins, not only its angle (a turning hoop would score 0)", function()
			-- Each point's distance to the point opposite it: unchanged by any rotation, so only a shape change moves it.
			local function diameters(s)
				local out, n = {}, #s.ring
				for i = 1, n / 2 do
					table.insert(out, (s.ring[i] - s.ring[i + n / 2]).Magnitude)
				end
				return out
			end
			local s = run(EmoteLassoFormulas.newState(), 1, function(t)
				return upright(Vector3.zero, t * 7)
			end)
			local a = diameters(s)
			s = run(s, 0.25, function(t)
				return upright(Vector3.zero, 7 + t * 7)
			end)
			local b = diameters(s)
			local changed = 0
			for i = 1, #a do
				changed += math.abs(a[i] - b[i])
			end
			expect(changed / #a > 0.05).to.equal(true)
		end)

		it("turns the loop spinMul times the clip's rate while the rope stands up", function()
			local s = run(EmoteLassoFormulas.newState(), 0.5, function(t)
				return upright(Vector3.zero, t * 2)
			end)
			expect(s.spin).to.be.near((T.spinMul - 1) * 2 * 0.5, 0.05)
		end)

		it("adds no extra spin while the rope is tipped over", function()
			local s = run(EmoteLassoFormulas.newState(), 0.5, function(t)
				return CFrame.Angles(math.rad(80), t * 2, 0)
			end)
			expect(s.spin).to.equal(0)
		end)

		it("throws the loop out along his facing once the rope has stood up and then tips forward", function()
			local look = Vector3.new(0, 0, -1)
			local s = run(EmoteLassoFormulas.newState(), 0.8, function()
				return upright(Vector3.zero, 0)
			end, look)
			-- Tip the rope forward (toward -Z) like the clip's throw.
			s = run(s, T.throwOut + T.throwHold * 0.5, function()
				return CFrame.Angles(math.rad(-80), 0, 0)
			end, look)
			expect(s.throwAt ~= nil).to.equal(true)
			-- Out past where the clip itself puts the knot.
			local clip = EmoteLassoFormulas.driverOf(CFrame.Angles(math.rad(-80), 0, 0), HEIGHT, look)
			expect(s.rope[#s.rope].Z < clip.knot.Z - 0.5).to.equal(true)
		end)

		it("does not throw on the shake-out, when the rope points forward before it ever stood up", function()
			local s = run(EmoteLassoFormulas.newState(), 0.3, function()
				return CFrame.Angles(math.rad(-80), 0, 0)
			end)
			expect(s.throwAt).to.equal(nil)
		end)

		it("snaps back to the pose after a teleport", function()
			local s = run(EmoteLassoFormulas.newState(), 0.3, function()
				return upright(Vector3.zero, 0)
			end)
			s = run(s, T.substep, function()
				return upright(Vector3.new(500, 0, 0), 0)
			end)
			expect((s.rope[#s.rope] - Vector3.new(500, 0, 0)).Magnitude < 10).to.equal(true)
			expect((s.ring[8] - Vector3.new(500, 0, 0)).Magnitude < 10).to.equal(true)
		end)
	end)
end
