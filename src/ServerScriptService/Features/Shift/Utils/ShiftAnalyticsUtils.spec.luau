local ServerScriptService = game:GetService("ServerScriptService")

local ShiftAnalyticsUtils = require(script.Parent.ShiftAnalyticsUtils)
local ShiftAnalyticsConstants = require(ServerScriptService.Features.Shift.Data.ShiftAnalyticsConstants)
local ExperimentRegistry = require(ServerScriptService.Features.Experiment.Data.ExperimentRegistry)

local function context(overrides)
	local base =
		{ session = "job-1", build = "w1-v12", tags = "1.5s+10s", platform = "phone", party = 3, cohort = "new" }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	describe("isEvent", function()
		it("knows exactly the 13 spec events", function()
			expect(#ShiftAnalyticsConstants.EVENTS).to.equal(13)
			for _, name in ShiftAnalyticsConstants.EVENTS do
				expect(ShiftAnalyticsUtils.isEvent(name)).to.equal(true)
			end
		end)

		it("refuses anything else, including a different case", function()
			expect(ShiftAnalyticsUtils.isEvent("Contract_Started")).to.equal(false)
			expect(ShiftAnalyticsUtils.isEvent("chat")).to.equal(false)
			expect(ShiftAnalyticsUtils.isEvent("")).to.equal(false)
		end)
	end)

	describe("token", function()
		it("keeps fixed words, cargo ids and pile kinds", function()
			expect(ShiftAnalyticsUtils.token("after_quota")).to.equal("after_quota")
			expect(ShiftAnalyticsUtils.token("fishTank")).to.equal("fishTank")
			expect(ShiftAnalyticsUtils.token("cables")).to.equal("cables")
		end)

		it("keeps a compound token whose parts are all known", function()
			expect(ShiftAnalyticsUtils.token("fishTank:pile")).to.equal("fishTank:pile")
			expect(ShiftAnalyticsUtils.token("failed:caught")).to.equal("failed:caught")
		end)

		it("turns a player name, a chat line or a user id into other", function()
			expect(ShiftAnalyticsUtils.token("Builderman")).to.equal("other")
			expect(ShiftAnalyticsUtils.token("lol harlow is so slow")).to.equal("other")
			expect(ShiftAnalyticsUtils.token("123456789")).to.equal("other")
		end)

		it("checks each part of a compound token", function()
			expect(ShiftAnalyticsUtils.token("fishTank:Builderman")).to.equal("other")
			expect(ShiftAnalyticsUtils.token("fishTank:")).to.equal("other")
		end)

		it("is none for nothing and other for an over-long string", function()
			expect(ShiftAnalyticsUtils.token(nil)).to.equal("none")
			expect(ShiftAnalyticsUtils.token("")).to.equal("none")
			expect(ShiftAnalyticsUtils.token(string.rep("pile:", 10) .. "pile")).to.equal("other")
		end)
	end)

	describe("value", function()
		it("clamps, rounds to a tenth and never returns NaN", function()
			expect(ShiftAnalyticsUtils.value(nil)).to.equal(0)
			expect(ShiftAnalyticsUtils.value(0 / 0)).to.equal(0)
			expect(ShiftAnalyticsUtils.value(-5)).to.equal(0)
			expect(ShiftAnalyticsUtils.value(math.huge)).to.equal(ShiftAnalyticsConstants.VALUE_MAX)
			expect(ShiftAnalyticsUtils.value(12.34)).to.equal(12.3)
			expect(ShiftAnalyticsUtils.value(38)).to.equal(38)
		end)
	end)

	describe("session", function()
		it("names Studio's empty JobId and keeps a live one", function()
			expect(ShiftAnalyticsUtils.session("")).to.equal("studio")
			expect(ShiftAnalyticsUtils.session("a1b2-c3")).to.equal("a1b2-c3")
		end)
	end)

	describe("contextField", function()
		it("packs tags, platform, party, cohort and build", function()
			expect(ShiftAnalyticsUtils.contextField(context())).to.equal("1.5s+10s|phone|3|new|w1-v12")
		end)

		it("tags each shift event with the two crew experiments", function()
			expect(#ShiftAnalyticsConstants.EXPERIMENTS).to.equal(2)
			for _, id in ShiftAnalyticsConstants.EXPERIMENTS do
				local definition = ExperimentRegistry.get(id)
				expect(definition).to.be.ok()
				expect(definition.unit).to.equal("crew")
			end
		end)
	end)

	describe("fields", function()
		it("packs the context into field 1, the target into 2 and the outcome into 3", function()
			local fields = ShiftAnalyticsUtils.fields(context(), { target = "plaque:pile", outcome = "banked" })
			expect(#fields).to.equal(3)
			expect(fields[1]).to.equal("1.5s+10s|phone|3|new|w1-v12")
			expect(fields[2]).to.equal("plaque:pile")
			expect(fields[3]).to.equal("banked")
		end)

		it("joins a failure reason to the outcome", function()
			local fields =
				ShiftAnalyticsUtils.fields(context(), { target = "plaque:open", outcome = "failed", reason = "caught" })
			expect(fields[3]).to.equal("failed:caught")
		end)

		it("keeps the session out of the engine fields", function()
			for _, field in ShiftAnalyticsUtils.fields(context(), { target = "harlow", outcome = "after_quota" }) do
				expect(string.find(field, "job-1", 1, true)).to.equal(nil)
			end
		end)

		it("clamps the party size and cleans every string", function()
			local fields =
				ShiftAnalyticsUtils.fields(context({ party = 150 }), { target = "Bob", outcome = "hi there" })
			expect(fields[1]).to.equal("1.5s+10s|phone|99|new|w1-v12")
			expect(fields[2]).to.equal("other")
			expect(fields[3]).to.equal("other")
		end)
	end)

	describe("record", function()
		it("carries every spec field, cleaned", function()
			local record = ShiftAnalyticsUtils.record(
				"pile_cleared",
				context(),
				{ target = "paper", outcome = "solo", value = 61.27 }
			)
			expect(record.event).to.equal("pile_cleared")
			expect(record.session).to.equal("job-1")
			expect(record.build).to.equal("w1-v12")
			expect(record.tags).to.equal("1.5s+10s")
			expect(record.cohort).to.equal("new")
			expect(record.platform).to.equal("phone")
			expect(record.party).to.equal(3)
			expect(record.target).to.equal("paper")
			expect(record.outcome).to.equal("solo")
			expect(record.reason).to.equal("none")
			expect(record.value).to.equal(61.3)
		end)
	end)

	describe("small decisions", function()
		it("tags before and after the quota", function()
			expect(ShiftAnalyticsUtils.quotaTag(false)).to.equal("before_quota")
			expect(ShiftAnalyticsUtils.quotaTag(true)).to.equal("after_quota")
		end)

		it("buckets the piles a player cleared", function()
			expect(ShiftAnalyticsUtils.pileBucket(0)).to.equal("piles_0")
			expect(ShiftAnalyticsUtils.pileBucket(1)).to.equal("piles_1_2")
			expect(ShiftAnalyticsUtils.pileBucket(2)).to.equal("piles_1_2")
			expect(ShiftAnalyticsUtils.pileBucket(3)).to.equal("piles_3_5")
			expect(ShiftAnalyticsUtils.pileBucket(5)).to.equal("piles_3_5")
			expect(ShiftAnalyticsUtils.pileBucket(6)).to.equal("piles_6_plus")
			expect(ShiftAnalyticsUtils.pileBucket(40)).to.equal("piles_6_plus")
		end)

		it("reads Carry's drop reasons, ignoring pocketing, banking and resets", function()
			expect(ShiftAnalyticsUtils.dropOutcome("drop")).to.equal("dropped")
			expect(ShiftAnalyticsUtils.dropOutcome("throw")).to.equal("thrown")
			expect(ShiftAnalyticsUtils.dropOutcome("death")).to.equal("caught")
			expect(ShiftAnalyticsUtils.dropOutcome("removed")).to.equal("left")
			expect(ShiftAnalyticsUtils.dropOutcome("forced")).to.equal(nil)
			expect(ShiftAnalyticsUtils.dropOutcome("destroyed")).to.equal(nil)
		end)

		it("counts an after-quota salvage pick-up outside the bay as an attempt", function()
			local base = { category = "salvage", phase = "running", sub = "normal", quotaMet = true, inBay = false }
			expect(ShiftAnalyticsUtils.isSalvageAttempt(base)).to.equal(true)
			local function with(key, value)
				local copy = table.clone(base)
				copy[key] = value
				return ShiftAnalyticsUtils.isSalvageAttempt(copy)
			end
			expect(with("category", "trash")).to.equal(false)
			expect(with("phase", "results")).to.equal(false)
			expect(with("sub", "clockout")).to.equal(false)
			expect(with("quotaMet", false)).to.equal(false)
			expect(with("inBay", true)).to.equal(false)
		end)

		it("tests a point against a box, edges included", function()
			local low, high = Vector3.new(0, 0, 0), Vector3.new(10, 10, 10)
			expect(ShiftAnalyticsUtils.inBox(Vector3.new(5, 5, 5), low, high)).to.equal(true)
			expect(ShiftAnalyticsUtils.inBox(Vector3.new(10, 0, 10), low, high)).to.equal(true)
			expect(ShiftAnalyticsUtils.inBox(Vector3.new(11, 5, 5), low, high)).to.equal(false)
			expect(ShiftAnalyticsUtils.inBox(Vector3.new(5, -1, 5), low, high)).to.equal(false)
		end)

		it("credits salvage times the multiplier, rounded like the review, and trash as is", function()
			expect(ShiftAnalyticsUtils.credited("salvage", 25, 1.5)).to.equal(38)
			expect(ShiftAnalyticsUtils.credited("salvage", 70, 1)).to.equal(70)
			expect(ShiftAnalyticsUtils.credited("trash", 15, 1.5)).to.equal(15)
		end)
	end)

	describe("harlowChange", function()
		local function change(beforeMode, beforeTarget, afterMode, afterTarget)
			local before = if beforeMode ~= nil then { mode = beforeMode, target = beforeTarget } else nil
			return ShiftAnalyticsUtils.harlowChange(before, { mode = afterMode, target = afterTarget })
		end

		it("reports the start of an investigation once", function()
			expect(change(nil, 0, "investigate", 0)).to.equal("noise_investigation")
			expect(change("patrol", 0, "investigate", 0)).to.equal("noise_investigation")
			expect(change("investigate", 0, "investigate", 0)).to.equal(nil)
		end)

		it("reports a chase start and a switch to another player, not a continuing chase", function()
			expect(change("patrol", 0, "chase", 7)).to.equal("chase_started")
			expect(change("chase", 7, "chase", 9)).to.equal("chase_started")
			expect(change("chase", 7, "chase", 7)).to.equal(nil)
		end)

		it("ignores a chase with no target and every other mode", function()
			expect(change("patrol", 0, "chase", 0)).to.equal(nil)
			expect(change("chase", 7, "search", 0)).to.equal(nil)
			expect(change("search", 0, "catch", 0)).to.equal(nil)
		end)
	end)

	describe("heardSource", function()
		local HARLOW = Vector3.new(0, 0, 0)

		it("picks the newest recent noise that reached him", function()
			local noises = {
				{ source = "vacuum", position = Vector3.new(30, 0, 0), radius = 40, at = 99, makers = {} },
				{ source = "drop", position = Vector3.new(10, 0, 0), radius = 14, at = 99.5, makers = {} },
			}
			expect(ShiftAnalyticsUtils.heardSource(noises, HARLOW, 1, 100)).to.equal("drop")
		end)

		it("skips a noise that did not reach him, scaled by his hearing", function()
			local noises =
				{ { source = "search", position = Vector3.new(14, 0, 0), radius = 12, at = 100, makers = {} } }
			expect(ShiftAnalyticsUtils.heardSource(noises, HARLOW, 1, 100)).to.equal("unknown")
			expect(ShiftAnalyticsUtils.heardSource(noises, HARLOW, 1.2, 100)).to.equal("search")
		end)

		it("forgets noises older than the memory", function()
			local noises = { { source = "vacuum", position = HARLOW, radius = 40, at = 90, makers = {} } }
			local late = 90 + ShiftAnalyticsConstants.NOISE_MEMORY + 0.1
			expect(ShiftAnalyticsUtils.heardSource(noises, HARLOW, 1, late)).to.equal("unknown")
			expect(ShiftAnalyticsUtils.heardSource({}, HARLOW, 1, 100)).to.equal("unknown")
		end)
	end)

	describe("heardNoise", function()
		local function noise(source, x, radius, at, makers)
			return { source = source, position = Vector3.new(x, 0, 0), radius = radius, at = at, makers = makers or {} }
		end

		it("returns the makers of the noise he most likely heard", function()
			local noises = { noise("drop", 0, 40, 9, { 2 }), noise("vacuum", 5, 40, 9.5, { 1, 3 }) }
			local heard = ShiftAnalyticsUtils.heardNoise(noises, Vector3.new(10, 0, 0), 1, 10)
			expect(heard.source).to.equal("vacuum")
			expect(#heard.makers).to.equal(2)
		end)

		it("skips a noise that could not reach him, and returns nil when none did", function()
			local noises = { noise("drop", 0, 40, 9, { 2 }), noise("vacuum", 200, 40, 9.5, { 1 }) }
			expect(ShiftAnalyticsUtils.heardNoise(noises, Vector3.new(10, 0, 0), 1, 10).source).to.equal("drop")
			expect(ShiftAnalyticsUtils.heardNoise({}, Vector3.zero, 1, 10)).to.equal(nil)
		end)

		it("keeps heardSource answering with the source word", function()
			local noises = { noise("search", 0, 40, 9, { 4 }) }
			expect(ShiftAnalyticsUtils.heardSource(noises, Vector3.new(1, 0, 0), 1, 10)).to.equal("search")
			expect(ShiftAnalyticsUtils.heardSource({}, Vector3.zero, 1, 10)).to.equal("unknown")
		end)

		describe("newlyPunched", function()
			it("returns ids in after but not before", function()
				local ids = ShiftAnalyticsUtils.newlyPunched({ 1 }, { 1, 2, 3 })
				table.sort(ids)
				expect(#ids).to.equal(2)
				expect(ids[1]).to.equal(2)
				expect(ids[2]).to.equal(3)
			end)

			it("treats nil as nobody", function()
				expect(#ShiftAnalyticsUtils.newlyPunched(nil, nil)).to.equal(0)
				expect(#ShiftAnalyticsUtils.newlyPunched(nil, { 4 })).to.equal(1)
				expect(#ShiftAnalyticsUtils.newlyPunched({ 4 }, nil)).to.equal(0)
			end)
		end)
	end)
end
