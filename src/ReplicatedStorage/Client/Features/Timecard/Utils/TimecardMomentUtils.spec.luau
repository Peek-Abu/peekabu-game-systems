local Utils = require(script.Parent.TimecardMomentUtils)

-- Monday 26 Oct 2026, 00:00 UTC, and a day.
local MONDAY = 1792972800
local DAY = 86400

local function card(punched, weeks)
	return { week = MONDAY, punched = punched, weeks = weeks or 0 }
end

return function()
	describe("moment", function()
		it("reports today's new punch with its count", function()
			local now = MONDAY + 2 * DAY + 60
			local moment = Utils.moment(card({ 1 }), card({ 1, 3 }), now)
			expect(moment.day).to.equal(3)
			expect(moment.count).to.equal(2)
			expect(moment.reward).never.to.be.ok()
			expect(moment.paycheque).to.equal(false)
			expect(moment.id).to.equal(`{MONDAY}:3`)
		end)

		it("pays the key on the third punch and the Gleam on the fifth", function()
			local third = Utils.moment(card({ 1, 2 }), card({ 1, 2, 4 }), MONDAY + 3 * DAY)
			expect(third.reward).to.equal("key")
			local fifth = Utils.moment(card({ 1, 2, 3, 4 }), card({ 1, 2, 3, 4, 5 }, 1), MONDAY + 4 * DAY)
			expect(fifth.reward).to.equal("stars")
			expect(fifth.paycheque).to.equal(false)
		end)

		it("adds the paycheque when the fifth punch fills the fourth week in a row", function()
			local moment = Utils.moment(card({ 1, 2, 3, 4 }, 3), card({ 1, 2, 3, 4, 5 }, 4), MONDAY + 4 * DAY)
			expect(moment.reward).to.equal("stars")
			expect(moment.paycheque).to.equal(true)
		end)

		it("reports nothing when today was already on the card", function()
			expect(Utils.moment(card({ 1 }), card({ 1 }), MONDAY + 60)).never.to.be.ok()
		end)

		it("reports nothing for a card that only changed on another day", function()
			expect(Utils.moment(card({}), card({ 2 }), MONDAY + 60)).never.to.be.ok()
		end)

		it("rolls last week's card forward, so last week's punch on this weekday is not today's", function()
			local lastWeek = { week = MONDAY - 7 * DAY, punched = { 1 }, weeks = 0 }
			local moment = Utils.moment(lastWeek, card({ 1 }), MONDAY + 60)
			expect(moment.day).to.equal(1)
			expect(moment.count).to.equal(1)
		end)
	end)

	describe("banner", function()
		it("names the reward a milestone punch paid", function()
			expect(Utils.banner({ day = 3, count = 3, reward = "key", paycheque = false, id = "x" })).to.equal(
				"DAY 3! +1 GLOOM KEY"
			)
			expect(Utils.banner({ day = 5, count = 5, reward = "stars", paycheque = false, id = "x" })).to.equal(
				"CARD FULL! +5 GLEAM"
			)
			expect(Utils.banner({ day = 5, count = 5, reward = "stars", paycheque = true, id = "x" })).to.equal(
				"CARD FULL! +5 GLEAM +500 CREDITS"
			)
		end)

		it("tells how many days are left until the next reward", function()
			expect(Utils.banner({ day = 1, count = 1, paycheque = false, id = "x" })).to.equal(
				"DAY 1! 2 MORE FOR A GLOOM KEY"
			)
			expect(Utils.banner({ day = 4, count = 4, paycheque = false, id = "x" })).to.equal(
				"DAY 4! 1 MORE FOR 5 GLEAM"
			)
			expect(Utils.banner({ day = 7, count = 6, paycheque = false, id = "x" })).to.equal(
				"BONUS DAY! CARD IS FULL"
			)
		end)
	end)

	describe("shouldGreet", function()
		local function input(overrides)
			local value = {
				synced = true,
				inHub = true,
				busy = false,
				canPunch = true,
				greeted = nil,
				day = 20754,
			}
			for key, item in overrides or {} do
				value[key] = item
			end
			return value
		end

		it("greets once a day in the hub while today is still free", function()
			expect(Utils.shouldGreet(input())).to.equal(true)
			expect(Utils.shouldGreet(input({ greeted = 20754 }))).to.equal(false)
			expect(Utils.shouldGreet(input({ greeted = 20753 }))).to.equal(true)
		end)

		it("waits for the real card, the hub and a free screen", function()
			expect(Utils.shouldGreet(input({ synced = false }))).to.equal(false)
			expect(Utils.shouldGreet(input({ inHub = false }))).to.equal(false)
			expect(Utils.shouldGreet(input({ busy = true }))).to.equal(false)
		end)

		it("never greets once today is punched", function()
			expect(Utils.shouldGreet(input({ canPunch = false }))).to.equal(false)
		end)
	end)
end
