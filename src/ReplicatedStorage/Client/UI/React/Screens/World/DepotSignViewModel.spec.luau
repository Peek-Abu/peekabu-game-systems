local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VM = require(script.Parent.DepotSignViewModel)
local TimecardRules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)
local TimecardConstants = require(ReplicatedStorage.Shared.Features.Timecard.Data.TimecardConstants)
local WorkOrderRegistry = require(ReplicatedStorage.Shared.Features.WorkOrder.Data.WorkOrderRegistry)
local RankRegistry = require(ReplicatedStorage.Shared.Features.Rank.Data.RankRegistry)

-- A Monday 12:00 UTC and the next two days (TimecardCalendarFormulas: Monday is day 1).
local MONDAY = 1792972800 + 12 * 3600
local DAY = 86400

local function status(punched, now)
	return TimecardRules.status({ week = 1792972800, punched = punched, weeks = 0 }, now)
end

return function()
	describe("DepotSignViewModel.clock", function()
		it("shows one punch hole per day up to the key, filled for each punch, today's open hole glowing", function()
			local view = VM.clock(status({ 1 }, MONDAY + DAY))
			expect(view.title).to.equal("CLOCK IN")
			expect(#view.slots).to.equal(TimecardConstants.KEY_PUNCH)
			expect(view.slots[1]).to.equal("punched")
			expect(view.slots[2]).to.equal("today")
			expect(view.slots[3]).to.equal("empty")
			expect(view.keyEarned).to.equal(false)
		end)
		it("earns the key once the key punch is in, and shows no glow when today is punched", function()
			local view = VM.clock(status({ 1, 2, 3 }, MONDAY + 2 * DAY))
			for _, slot in view.slots do
				expect(slot).to.equal("punched")
			end
			expect(view.keyEarned).to.equal(true)
		end)
		it("starts empty on a fresh week, today glowing first", function()
			local view = VM.clock(TimecardRules.status({ week = 0, punched = {}, weeks = 0 }, MONDAY))
			expect(view.slots[1]).to.equal("today")
			expect(view.slots[2]).to.equal("empty")
		end)
	end)

	describe("DepotSignViewModel.daily", function()
		local function order(kind, target)
			return { id = "x", kind = kind, target = target, label = "x" }
		end
		it("shows the job as a picture and a count, the reward as a number", function()
			local view = VM.daily(order("piles", 8), { day = 1, progress = 3, claimed = false })
			expect(view.title).to.equal("TODAY")
			expect(view.icon).to.equal("dust")
			expect(view.count).to.equal("x8")
			expect(view.progress).to.equal("3/8")
			expect(view.fill).to.be.near(3 / 8, 1e-6)
			expect(view.done).to.equal(false)
			expect(view.reward).to.equal(`+{WorkOrderRegistry.REWARD_CREDITS}`)
		end)
		it("has a picture for every kind of job", function()
			for _, kind in { "piles", "cargo", "salvage", "shifts" } do
				expect(VM.daily(order(kind, 1), { day = 1, progress = 0, claimed = false }).icon).to.be.ok()
			end
		end)
		it("is done once claimed, and never shows more than the target", function()
			local view = VM.daily(order("cargo", 4), { day = 1, progress = 9, claimed = true })
			expect(view.done).to.equal(true)
			expect(view.progress).to.equal("4/4")
			expect(view.fill).to.equal(1)
		end)
	end)

	describe("DepotSignViewModel.ranks", function()
		it("shows every rank as a numbered step in its lanyard colour, the player's step marked", function()
			local levels = RankRegistry.all()
			local view = VM.ranks(levels[3].xp + 1)
			expect(#view.steps).to.equal(#levels)
			for index, step in view.steps do
				expect(step.number).to.equal(tostring(index))
				expect(step.color).to.equal(levels[index].lanyard)
				expect(step.you).to.equal(index == 3)
			end
			expect(view.title).to.equal("RANKS")
			expect(view.you).to.equal(3)
		end)
		it("puts a player with no XP on the first step", function()
			expect(VM.ranks(nil).you).to.equal(1)
			expect(VM.ranks(-5).you).to.equal(1)
		end)
		it("climbs: each step is taller than the one before", function()
			local steps = VM.ranks(0).steps
			for index = 2, #steps do
				expect(steps[index].height > steps[index - 1].height).to.equal(true)
			end
		end)
	end)
end
