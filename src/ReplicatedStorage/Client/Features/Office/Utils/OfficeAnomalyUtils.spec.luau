local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeAnomalyConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeAnomalyConstants)
local OfficeAnomalyUtils = require(script.Parent.OfficeAnomalyUtils)

return function()
	describe("parse", function()
		it("reads the comma-joined published list, keeping only known ids", function()
			local set = OfficeAnomalyUtils.parse("banner,wetFloor,nonsense")
			expect(set.banner).to.equal(true)
			expect(set.wetFloor).to.equal(true)
			expect(set.nonsense).to.equal(nil)
		end)

		it("is empty for nil, an empty string or a non-string", function()
			expect(next(OfficeAnomalyUtils.parse(nil))).to.equal(nil)
			expect(next(OfficeAnomalyUtils.parse(""))).to.equal(nil)
			expect(next(OfficeAnomalyUtils.parse(42))).to.equal(nil)
		end)
	end)

	describe("silhouette", function()
		local step = OfficeAnomalyUtils.silhouette
		local SEEN = OfficeAnomalyUtils.SILHOUETTE_SEEN_AFTER

		it("stays hidden until it is applied", function()
			expect(step({ phase = "hidden" }, true, SEEN, 10).phase).to.equal("hidden")
		end)

		it("is seen after SEEN_AFTER seconds in view, not before", function()
			expect(SEEN).to.equal(0.5)
			local state = step({ phase = "visible" }, true, SEEN, 10)
			expect(state.phase).to.equal("visible")
			state = step(state, true, SEEN, 10.4)
			expect(state.phase).to.equal("visible")
			state = step(state, true, SEEN, 10.5)
			expect(state.phase).to.equal("seen")
		end)

		it("restarts the count when it leaves view before being seen", function()
			local state = step({ phase = "visible" }, true, SEEN, 10)
			state = step(state, false, SEEN, 10.3)
			expect(state.phase).to.equal("visible")
			state = step(state, true, SEEN, 10.4)
			state = step(state, true, SEEN, 10.8)
			expect(state.phase).to.equal("visible")
			state = step(state, true, SEEN, 10.9)
			expect(state.phase).to.equal("seen")
		end)

		it("goes once off screen after being seen, and never comes back", function()
			local state = step({ phase = "seen" }, true, SEEN, 20)
			expect(state.phase).to.equal("seen")
			state = step(state, false, SEEN, 21)
			expect(state.phase).to.equal("gone")
			state = step(state, true, SEEN, 22)
			expect(state.phase).to.equal("gone")
			state = step(state, true, SEEN, 30)
			expect(state.phase).to.equal("gone")
		end)

		it("is visible only while visible or seen", function()
			expect(OfficeAnomalyUtils.silhouetteShown({ phase = "hidden" })).to.equal(false)
			expect(OfficeAnomalyUtils.silhouetteShown({ phase = "visible" })).to.equal(true)
			expect(OfficeAnomalyUtils.silhouetteShown({ phase = "seen" })).to.equal(true)
			expect(OfficeAnomalyUtils.silhouetteShown({ phase = "gone" })).to.equal(false)
		end)
	end)

	describe("door cycle", function()
		it("opens over 0.6 s, holds 2 s, closes over 0.6 s", function()
			local phase, open = OfficeAnomalyUtils.doorAt(0)
			expect(phase).to.equal("opening")
			expect(open).to.equal(0)
			phase, open = OfficeAnomalyUtils.doorAt(0.3)
			expect(phase).to.equal("opening")
			expect(open).to.be.near(0.5, 1e-6)
			phase, open = OfficeAnomalyUtils.doorAt(0.6)
			expect(phase).to.equal("open")
			expect(open).to.equal(1)
			phase, open = OfficeAnomalyUtils.doorAt(2.5)
			expect(phase).to.equal("open")
			expect(open).to.equal(1)
			phase, open = OfficeAnomalyUtils.doorAt(2.9)
			expect(phase).to.equal("closing")
			expect(open).to.be.near(0.5, 1e-6)
			phase, open = OfficeAnomalyUtils.doorAt(3.2)
			expect(phase).to.equal("closed")
			expect(open).to.equal(0)
			phase, open = OfficeAnomalyUtils.doorAt(100)
			expect(phase).to.equal("closed")
			expect(open).to.equal(0)
		end)

		it("waits 20-40 s between cycles, the same for the same seed and cycle", function()
			local differs = false
			for cycle = 1, 50 do
				local every = OfficeAnomalyUtils.doorEvery(1234, cycle)
				expect(every >= 20 and every <= 40).to.equal(true)
				expect(OfficeAnomalyUtils.doorEvery(1234, cycle)).to.equal(every)
				if every ~= OfficeAnomalyUtils.doorEvery(1234, 1) then
					differs = true
				end
			end
			expect(differs).to.equal(true)
		end)

		it("slides a leaf SlideStuds along its right vector, away from the centre", function()
			local closed = CFrame.new(10, 0, 0)
			local leaf = OfficeAnomalyUtils.leafAt(closed, 1, 2.2, 1)
			expect((leaf.Position - Vector3.new(12.2, 0, 0)).Magnitude < 1e-4).to.equal(true)
			local other = OfficeAnomalyUtils.leafAt(closed, -1, 2.2, 0.5)
			expect((other.Position - Vector3.new(8.9, 0, 0)).Magnitude < 1e-4).to.equal(true)
			expect(OfficeAnomalyUtils.leafAt(closed, 1, 2.2, 0)).to.equal(closed)
		end)
	end)

	describe("welcome text", function()
		local WRONG = "WE VALUE YOUR TEETH"

		it("shows the wrong line in the last 1.2 s of each 6 s cycle", function()
			local W = OfficeAnomalyConstants.WELCOME_TEXT
			expect(OfficeAnomalyUtils.welcomeText(0, WRONG)).to.equal(W)
			expect(OfficeAnomalyUtils.welcomeText(4.7, WRONG)).to.equal(W)
			expect(OfficeAnomalyUtils.welcomeText(4.8, WRONG)).to.equal(WRONG)
			expect(OfficeAnomalyUtils.welcomeText(5.9, WRONG)).to.equal(WRONG)
			expect(OfficeAnomalyUtils.welcomeText(6.0, WRONG)).to.equal(W)
			expect(OfficeAnomalyUtils.welcomeText(10.7, WRONG)).to.equal(W)
			expect(OfficeAnomalyUtils.welcomeText(11, WRONG)).to.equal(WRONG)
		end)

		it("picks the run's wrong line from the seed, the same on every machine", function()
			local line = OfficeAnomalyUtils.wrongLine(77)
			expect(table.find(OfficeAnomalyConstants.WRONG_WORDS, line) ~= nil).to.equal(true)
			expect(OfficeAnomalyUtils.wrongLine(77)).to.equal(line)
		end)
	end)

	describe("tv flicker", function()
		it("stays within 0.6-1.2 and moves", function()
			local low, high = math.huge, -math.huge
			for i = 0, 400 do
				local b = OfficeAnomalyUtils.tvBrightness(i * 0.017)
				expect(b >= 0.6 - 1e-9 and b <= 1.2 + 1e-9).to.equal(true)
				low = math.min(low, b)
				high = math.max(high, b)
			end
			expect(high - low > 0.2).to.equal(true)
		end)
	end)
end
