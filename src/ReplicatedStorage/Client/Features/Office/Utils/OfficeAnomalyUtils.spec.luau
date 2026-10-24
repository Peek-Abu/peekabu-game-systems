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
			expect(step({ phase = "hidden" }, true, true, SEEN, 10).phase).to.equal("hidden")
		end)

		it("is seen after SEEN_AFTER seconds in view, not before", function()
			expect(SEEN).to.equal(0.5)
			local state = step({ phase = "visible" }, true, true, SEEN, 10)
			expect(state.phase).to.equal("visible")
			state = step(state, true, true, SEEN, 10.4)
			expect(state.phase).to.equal("visible")
			state = step(state, true, true, SEEN, 10.5)
			expect(state.phase).to.equal("seen")
		end)

		it("restarts the count when it leaves view before being seen", function()
			local state = step({ phase = "visible" }, true, true, SEEN, 10)
			state = step(state, false, false, SEEN, 10.3)
			expect(state.phase).to.equal("visible")
			state = step(state, true, true, SEEN, 10.4)
			state = step(state, true, true, SEEN, 10.8)
			expect(state.phase).to.equal("visible")
			state = step(state, true, true, SEEN, 10.9)
			expect(state.phase).to.equal("seen")
		end)

		it("goes once off screen after being seen, and never comes back", function()
			local state = step({ phase = "seen" }, true, true, SEEN, 20)
			expect(state.phase).to.equal("seen")
			state = step(state, false, false, SEEN, 21)
			expect(state.phase).to.equal("gone")
			state = step(state, true, true, SEEN, 22)
			expect(state.phase).to.equal("gone")
			state = step(state, true, true, SEEN, 30)
			expect(state.phase).to.equal("gone")
		end)

		it("counts in-view time only while on screen, in range and unoccluded", function()
			local state = step({ phase = "visible" }, true, false, SEEN, 10)
			state = step(state, true, false, SEEN, 11)
			expect(state.phase).to.equal("visible")
			state = step(state, true, true, SEEN, 12)
			state = step(state, true, true, SEEN, 12.5)
			expect(state.phase).to.equal("seen")
		end)

		it("once seen, stays while on screen even when occluded or out of range", function()
			local state = step({ phase = "seen" }, true, false, SEEN, 20)
			expect(state.phase).to.equal("seen")
			state = step(state, true, false, SEEN, 25)
			expect(state.phase).to.equal("seen")
			state = step(state, false, false, SEEN, 26)
			expect(state.phase).to.equal("gone")
		end)

		it("never goes while not yet seen, whatever the view", function()
			local state = step({ phase = "visible" }, false, false, SEEN, 1)
			state = step(state, true, false, SEEN, 2)
			state = step(state, false, false, SEEN, 3)
			expect(state.phase).to.equal("visible")
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

	describe("door clock", function()
		local doorStep = OfficeAnomalyUtils.doorStep
		local SEED = 1234

		it("never opens the moment a player comes near; the first cycle is 20-40 s later", function()
			local timer = doorStep({ cycle = 0 }, SEED, false, 0)
			expect(timer.nextAt).to.equal(nil)
			timer = doorStep(timer, SEED, true, 100)
			expect(timer.startedAt).to.equal(nil)
			expect(OfficeAnomalyUtils.doorOpen(timer, 100)).to.equal(0)
			local due = timer.nextAt
			expect(due >= 120 and due <= 140).to.equal(true)
			timer = doorStep(timer, SEED, true, due - 0.01)
			expect(timer.startedAt).to.equal(nil)
			timer = doorStep(timer, SEED, true, due)
			expect(timer.startedAt).to.equal(due)
			expect(timer.cycle).to.equal(1)
			expect(OfficeAnomalyUtils.doorOpen(timer, due + 1)).to.equal(1)
		end)

		it("schedules the next cycle 20-40 s after one starts, and finishes a running cycle", function()
			local timer = doorStep({ cycle = 0, nextAt = 10 }, SEED, true, 10)
			local nextAt = timer.nextAt
			expect(nextAt - 10 >= 20 and nextAt - 10 <= 40).to.equal(true)
			-- Everyone walks off mid-cycle: it still closes.
			local mid = doorStep(timer, SEED, false, 11)
			expect(mid.startedAt).to.equal(10)
			expect(OfficeAnomalyUtils.doorOpen(mid, 12.9)).to.be.near(0.5, 1e-6)
			expect(OfficeAnomalyUtils.doorOpen(mid, 20)).to.equal(0)
		end)

		it("skips a due cycle with nobody near and waits for a fresh 20-40 s after the next arrival", function()
			local timer = doorStep({ cycle = 3, nextAt = 50 }, SEED, false, 50)
			expect(timer.startedAt).to.equal(nil)
			expect(timer.nextAt).to.equal(nil)
			timer = doorStep(timer, SEED, false, 200)
			expect(timer.nextAt).to.equal(nil)
			timer = doorStep(timer, SEED, true, 300)
			expect(timer.startedAt).to.equal(nil)
			expect(timer.nextAt >= 320 and timer.nextAt <= 340).to.equal(true)
		end)
	end)

	describe("slotAction", function()
		local listed = { banner = true }
		it("decides apply, reset, reapply, refresh, keep and none", function()
			local act = OfficeAnomalyUtils.slotAction
			expect(act("banner", listed, 7, nil, false)).to.equal("apply")
			expect(act("wetFloor", listed, 7, nil, false)).to.equal("none")
			expect(act("wetFloor", listed, 7, 7, false)).to.equal("reset")
			expect(act("banner", {}, 7, 7, true)).to.equal("reset")
			expect(act("banner", listed, 8, 7, false)).to.equal("reapply")
			expect(act("banner", listed, 7, 7, true)).to.equal("refresh")
			expect(act("banner", listed, 7, 7, false)).to.equal("keep")
			expect(act(nil, listed, 7, nil, false)).to.equal("none")
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

		it("still moves at server-clock times (Workspace:GetServerTimeNow, ~1.8e9 s)", function()
			local low, high = math.huge, -math.huge
			for i = 0, 400 do
				local b = OfficeAnomalyUtils.tvBrightness(1792811431.25 + i * 0.017)
				expect(b >= 0.6 - 1e-9 and b <= 1.2 + 1e-9).to.equal(true)
				low = math.min(low, b)
				high = math.max(high, b)
			end
			expect(high - low > 0.2).to.equal(true)
		end)
	end)
end
