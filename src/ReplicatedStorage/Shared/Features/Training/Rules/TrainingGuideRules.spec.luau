local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingGuideRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingGuideRules)

local function at(stopDone, carrying, hidden)
	return { stopDone = stopDone == true, carrying = carrying == true, hidden = hidden == true }
end

return function()
	describe("target", function()
		it("points at the Gloom, then on once the stop is done", function()
			expect(TrainingGuideRules.target(1, at())).to.equal("pile")
			expect(TrainingGuideRules.target(1, at(true))).to.equal("next")
		end)

		it("points at the treasure, at the truck while carrying it, then on", function()
			expect(TrainingGuideRules.target(2, at())).to.equal("treasure")
			expect(TrainingGuideRules.target(2, at(false, true))).to.equal("truck")
			expect(TrainingGuideRules.target(2, at(true, true))).to.equal("next")
		end)

		it("leads on through the dark", function()
			expect(TrainingGuideRules.target(3, at())).to.equal("next")
		end)

		it("points at the desk (one way to get away), nothing while hidden, then on once he is gone", function()
			expect(TrainingGuideRules.target(4, at())).to.equal("desk")
			expect(TrainingGuideRules.target(4, at(false, false, true))).to.equal("none")
			expect(TrainingGuideRules.target(4, at(true, false, true))).to.equal("next")
		end)

		it("points at nothing once training is done, or outside the stops", function()
			expect(TrainingGuideRules.target(5, at())).to.equal("none")
			expect(TrainingGuideRules.target(0, at())).to.equal("none")
			expect(TrainingGuideRules.target(9, at())).to.equal("none")
		end)
	end)

	describe("tone", function()
		it("is red at the hide stop only", function()
			for stop = 1, #TrainingConstants.STOPS do
				local hide = TrainingConstants.STOPS[stop].id == "hide"
				expect(TrainingGuideRules.tone(stop)).to.equal(if hide then "danger" else "calm")
			end
		end)
	end)

	describe("trailTone", function()
		it("is red at the escape stop until the player got away, then gold", function()
			expect(TrainingGuideRules.trailTone(4, at())).to.equal("danger")
			expect(TrainingGuideRules.trailTone(4, at(false, false, true))).to.equal("danger")
			expect(TrainingGuideRules.trailTone(4, at(true, false, true))).to.equal("calm")
			expect(TrainingGuideRules.trailTone(1, at())).to.equal("calm")
		end)
	end)

	describe("goal", function()
		it("has a title, a line and an icon for every stop", function()
			for stop = 1, #TrainingConstants.STOPS do
				local goal = TrainingGuideRules.goal(stop)
				expect(goal ~= nil).to.equal(true)
				expect(#goal.title > 0).to.equal(true)
				expect(#goal.line > 0).to.equal(true)
			end
			expect(TrainingGuideRules.goal(0)).to.equal(nil)
		end)
	end)

	describe("coach", function()
		it("gives Pippa a line and a pose for every stop, and a different one once the way is open", function()
			for stop = 1, #TrainingConstants.STOPS do
				local line = TrainingGuideRules.coach(stop, at())
				expect(line ~= nil).to.equal(true)
				expect(table.find(TrainingConstants.COACH_POSES, line.pose) ~= nil).to.equal(true)
			end
			local working = TrainingGuideRules.coach(1, at())
			local open = TrainingGuideRules.coach(1, at(true))
			expect(working.text ~= open.text).to.equal(true)
		end)

		it("tells a carrying player to load the truck", function()
			local line = TrainingGuideRules.coach(2, at(false, true))
			expect(line.text).to.equal(TrainingConstants.COACH.carrying.text)
		end)

		it("warns at the dark and ducks at the hide stop", function()
			expect(TrainingGuideRules.coach(3, at()).pose).to.equal("warn")
			expect(TrainingGuideRules.coach(4, at()).pose).to.equal("hide")
			expect(TrainingGuideRules.coach(5, at()).pose).to.equal("cheer")
		end)

		it("offers running or hiding, says wait while hidden, and cheers 'go now' once he is gone", function()
			expect(TrainingGuideRules.coach(4, at()).text).to.equal(TrainingConstants.COACH.hide.text)
			expect(TrainingGuideRules.coach(4, at(false, false, true)).text).to.equal(
				TrainingConstants.COACH.hidden.text
			)
			local clear = TrainingGuideRules.coach(4, at(true, false, true))
			expect(clear.text).to.equal(TrainingConstants.COACH.clear.text)
			expect(clear.pose).to.equal("cheer")
			expect(TrainingGuideRules.coach(4, at(true)).text).to.equal(TrainingConstants.COACH.clear.text)
		end)
	end)

	describe("catchPhase", function()
		it("runs grab, splat, card, dark, back, then done", function()
			local beat = TrainingConstants.CATCH_BEAT
			expect(TrainingGuideRules.catchPhase(0)).to.equal("grab")
			expect(TrainingGuideRules.catchPhase(beat.splat + 0.01)).to.equal("splat")
			expect(TrainingGuideRules.catchPhase(beat.card + 0.01)).to.equal("card")
			expect(TrainingGuideRules.catchPhase(beat.dark + 0.01)).to.equal("dark")
			expect(TrainingGuideRules.catchPhase(beat.back + 0.01)).to.equal("back")
			expect(TrainingGuideRules.catchPhase(beat.done + 0.01)).to.equal("done")
			expect(TrainingGuideRules.catchPhase(-1)).to.equal("done")
		end)

		it("moves the player back while the screen is fully dark", function()
			local beat = TrainingConstants.CATCH_BEAT
			expect(TrainingConstants.RETURN_DELAY >= beat.dark + beat.fade).to.equal(true)
			expect(TrainingConstants.RETURN_DELAY < beat.back).to.equal(true)
		end)

		it("is one beat: the player is moved back and the screen clears while they are still down", function()
			local beat = TrainingConstants.CATCH_BEAT
			local down = OccupantConstants.KNOCKDOWN_SECONDS
			expect(TrainingConstants.RETURN_DELAY < down).to.equal(true)
			expect(beat.back + beat.fade <= down).to.equal(true)
			-- A quick wipe (about 0.4 s dark to clear).
			expect(beat.back + beat.fade - beat.dark <= 0.5).to.equal(true)
		end)
	end)

	describe("powerUsed", function()
		it("counts the crew move only when the player really uses it", function()
			expect(TrainingGuideRules.powerUsed(0, 0, 100, nil)).to.equal(false)
			expect(TrainingGuideRules.powerUsed(0, 130, 100, nil)).to.equal(true)
			expect(TrainingGuideRules.powerUsed(0, 0, 100, "Hug")).to.equal(true)
		end)

		it("does not count a cooldown that was already running when the step began", function()
			expect(TrainingGuideRules.powerUsed(130, 130, 100, nil)).to.equal(false)
		end)
	end)

	describe("ranEnough", function()
		it("passes the run step after a real run, not a tap", function()
			expect(TrainingGuideRules.ranEnough(0.2)).to.equal(false)
			expect(TrainingGuideRules.ranEnough(TrainingConstants.RUN_SECONDS)).to.equal(true)
		end)
	end)
end
