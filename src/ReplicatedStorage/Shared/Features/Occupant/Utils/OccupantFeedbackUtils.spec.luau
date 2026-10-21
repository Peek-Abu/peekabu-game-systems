local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantFeedbackUtils = require(script.Parent.OccupantFeedbackUtils)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local function has(list, value)
	return table.find(list, value) ~= nil
end

return function()
	describe("pickLine", function()
		local lines = { "Those are COMPANY ASSETS.", "Put that BACK.", "This is THEFT." }

		it("picks by the roll", function()
			expect(OccupantFeedbackUtils.pickLine(lines, 0, nil)).to.equal(lines[1])
			expect(OccupantFeedbackUtils.pickLine(lines, 0.999, nil)).to.equal(lines[3])
		end)

		it("never repeats the last line when there is a choice", function()
			for roll = 0, 0.99, 0.11 do
				expect(OccupantFeedbackUtils.pickLine(lines, roll, "Put that BACK.")).never.to.equal("Put that BACK.")
			end
		end)

		it("repeats a lone line, and has nothing for no lines", function()
			expect(OccupantFeedbackUtils.pickLine({ "You're FIRED!" }, 0.5, "You're FIRED!")).to.equal("You're FIRED!")
			expect(OccupantFeedbackUtils.pickLine({}, 0.5, nil)).to.equal(nil)
		end)

		it("keeps the spec's three lines in his mouth", function()
			expect(has(OccupantConstants.LINE_VARIANTS.spotted, "Those are COMPANY ASSETS.")).to.equal(true)
			expect(has(OccupantConstants.LINE_VARIANTS.curious, "Per my last email…")).to.equal(true)
			expect(has(OccupantConstants.LINE_VARIANTS.caught, "You're FIRED!")).to.equal(true)
		end)
	end)

	describe("clipFor", function()
		it("gives a line the same clip every time, within range", function()
			local first = OccupantFeedbackUtils.clipFor("Per my last email…", 4)
			expect(first >= 1 and first <= 4).to.equal(true)
			expect(OccupantFeedbackUtils.clipFor("Per my last email…", 4)).to.equal(first)
		end)

		it("spreads different lines over the clips", function()
			local seen = {}
			for _, set in OccupantConstants.LINE_VARIANTS do
				for _, line in set do
					seen[OccupantFeedbackUtils.clipFor(line, 4)] = true
				end
			end
			local distinct = 0
			for _ in seen do
				distinct += 1
			end
			expect(distinct >= 2).to.equal(true)
		end)

		it("has no clip when none is uploaded", function()
			expect(OccupantFeedbackUtils.clipFor("You're FIRED!", 0)).to.equal(nil)
		end)
	end)

	describe("voiced", function()
		it("speaks words but not *actions*", function()
			expect(OccupantFeedbackUtils.voiced("You're FIRED!")).to.equal(true)
			expect(OccupantFeedbackUtils.voiced("*sigh*")).to.equal(false)
			expect(OccupantFeedbackUtils.voiced("")).to.equal(false)
		end)
	end)

	describe("cues", function()
		it("hums when he starts to investigate", function()
			local list = OccupantFeedbackUtils.cues("patrol", "investigate", false, false)
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("curious")
		end)

		it("stings and starts the chase music when he spots you", function()
			local list = OccupantFeedbackUtils.cues("patrol", "chase", false, true)
			expect(#list).to.equal(2)
			expect(list[1]).to.equal("spotted")
			expect(list[2]).to.equal("chaseStart")
		end)

		it("stings without music when he spots someone else", function()
			local list = OccupantFeedbackUtils.cues("search", "chase", false, false)
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("spotted")
		end)

		it("ends your music when he switches to someone else or loses you", function()
			expect(OccupantFeedbackUtils.cues("chase", "chase", true, false)[1]).to.equal("chaseEnd")
			local lost = OccupantFeedbackUtils.cues("chase", "search", true, false)
			expect(#lost).to.equal(1)
			expect(lost[1]).to.equal("chaseEnd")
		end)

		it("stings you whenever a chase on you starts, by every way in (2026-10-16: no silent chase)", function()
			-- Direct or long sight from patrol, an investigate or search, the ambush from his desk, a hider
			-- bolting from a stare, a re-spot after he lost you, and a first frame with no mode yet.
			for _, before in { "patrol", "investigate", "search", "work", "stare", "catch", "rest" } do
				local list = OccupantFeedbackUtils.cues(before, "chase", false, true)
				expect(#list).to.equal(2)
				expect(list[1]).to.equal("spotted")
				expect(list[2]).to.equal("chaseStart")
			end
			local first = OccupantFeedbackUtils.cues(nil, "chase", false, true)
			expect(first[1]).to.equal("spotted")
			expect(first[2]).to.equal("chaseStart")
		end)

		it("stings you when he switches his chase from a crewmate onto you", function()
			local list = OccupantFeedbackUtils.cues("chase", "chase", false, true)
			expect(#list).to.equal(2)
			expect(list[1]).to.equal("spotted")
			expect(list[2]).to.equal("chaseStart")
		end)

		it("does not sting again while the same chase on you carries on", function()
			expect(#OccupantFeedbackUtils.cues("chase", "chase", true, true)).to.equal(0)
		end)

		it("has chase music to play: a sting and looped stems, every one registered", function()
			local OccupantAssets =
				require(game:GetService("ReplicatedStorage").Shared.Features.Occupant.Data.OccupantAssets)
			local SoundRegistry = require(game:GetService("ReplicatedStorage").Shared.Features.Sound.Data.SoundRegistry)
			expect(SoundRegistry.has("harlowChaseSting")).to.equal(true)
			expect(SoundRegistry.has("harlowSpotted")).to.equal(true)
			local stems = 0
			for _, list in { OccupantAssets.CHASE_STEMS.base, OccupantAssets.CHASE_STEMS.near } do
				for _, id in list do
					stems += 1
					expect(OccupantAssets.SOUNDS[id].looped).to.equal(true)
					expect(SoundRegistry.has(id)).to.equal(true)
				end
			end
			expect(stems).to.equal(5)
		end)

		it("sighs when he gives up, and only then", function()
			expect(OccupantFeedbackUtils.cues("search", "patrol", false, false)[1]).to.equal("giveUp")
			expect(OccupantFeedbackUtils.cues("investigate", "patrol", false, false)[1]).to.equal("giveUp")
			expect(#OccupantFeedbackUtils.cues("rest", "patrol", false, false)).to.equal(0)
			expect(#OccupantFeedbackUtils.cues(nil, "patrol", false, false)).to.equal(0)
		end)
	end)

	describe("catch copy", function()
		local CargoRegistry = require(game:GetService("ReplicatedStorage").Shared.Features.Cargo.Data.CargoRegistry)

		it("lists the hands item, then the pockets, by name", function()
			local names = OccupantFeedbackUtils.droppedNames("monitor", { "plaque" }, CargoRegistry.get)
			expect(#names).to.equal(2)
			expect(names[1]).to.equal("Monitor")
			expect(names[2]).to.equal("Employee of the Month plaque")
		end)

		it("skips empty hands and unknown kinds", function()
			local names = OccupantFeedbackUtils.droppedNames(nil, { "nope", "goldenStapler" }, CargoRegistry.get)
			expect(#names).to.equal(1)
			expect(names[1]).to.equal("Golden stapler")
		end)

		it("writes the hit toast without a back-in time", function()
			expect(OccupantFeedbackUtils.hitText("Alex")).to.equal("Alex got caught!")
		end)

		it("writes the out toast when the last life is spent", function()
			expect(OccupantFeedbackUtils.outText("Alex")).to.equal("Alex is out for the shift")
		end)
	end)
end
