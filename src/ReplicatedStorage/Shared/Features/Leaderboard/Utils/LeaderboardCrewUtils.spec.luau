local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardCrewUtils = require(ReplicatedStorage.Shared.Features.Leaderboard.Utils.LeaderboardCrewUtils)
local LeaderboardConstants = require(ReplicatedStorage.Shared.Features.Leaderboard.Data.LeaderboardConstants)

-- Wednesday 2026-11-04 12:00 UTC.
local WEDNESDAY = 1793793600

return function()
	describe("crewKey", function()
		it("is the same for a crew in any order, and short enough for an OrderedDataStore key", function()
			local a = LeaderboardCrewUtils.crewKey({ 30, 10, 20 })
			expect(a).to.equal(LeaderboardCrewUtils.crewKey({ 10, 20, 30 }))
			expect(#a).to.equal(LeaderboardConstants.KEY_LENGTH)
			expect(
				#LeaderboardCrewUtils.crewKey({ 9007199254, 9007199255, 9007199256, 9007199257, 9007199258, 9007199259 })
			).to.equal(LeaderboardConstants.KEY_LENGTH)
		end)

		it("differs for a different crew", function()
			expect(LeaderboardCrewUtils.crewKey({ 1, 2 })).never.to.equal(LeaderboardCrewUtils.crewKey({ 1, 3 }))
			expect(LeaderboardCrewUtils.crewKey({ 12 })).never.to.equal(LeaderboardCrewUtils.crewKey({ 1, 2 }))
		end)
	end)

	describe("week", function()
		it("names the week's store by its Monday, and ends it the next Monday", function()
			expect(LeaderboardCrewUtils.storeName(WEDNESDAY)).to.equal("CrewWeek_2026-11-02")
			expect(LeaderboardCrewUtils.weekOf(WEDNESDAY)).to.equal("2026-11-02")
			expect(LeaderboardCrewUtils.weekEnds(WEDNESDAY)).to.equal(1794182400)
		end)
	end)

	describe("roster", function()
		it("sorts the crew, keeps names in the same order and cuts long names", function()
			local roster = LeaderboardCrewUtils.roster({
				{ userId = 20, name = "Bea" },
				{ userId = 10, name = string.rep("x", 40) },
			})
			expect(roster.ids[1]).to.equal(10)
			expect(roster.ids[2]).to.equal(20)
			expect(#roster.names[1]).to.equal(LeaderboardConstants.MAX_NAME)
			expect(roster.names[2]).to.equal("Bea")
		end)

		it("decodes a stored roster and refuses a bad one", function()
			local roster = LeaderboardCrewUtils.decodeRoster({ ids = { 1, 2 }, names = { "A", "B" } })
			expect(roster).to.be.ok()
			expect(roster.names[2]).to.equal("B")
			expect(LeaderboardCrewUtils.decodeRoster({ ids = { 1 }, names = { "A", "B" } })).to.equal(nil)
			expect(LeaderboardCrewUtils.decodeRoster("nope")).to.equal(nil)
			expect(LeaderboardCrewUtils.decodeRoster(nil)).to.equal(nil)
		end)
	end)

	describe("best", function()
		it("keeps a crew's best shift of the week", function()
			expect(LeaderboardCrewUtils.best(nil, 420)).to.equal(420)
			expect(LeaderboardCrewUtils.best(500, 420)).to.equal(500)
			expect(LeaderboardCrewUtils.best(300, 420.7)).to.equal(420)
			expect(LeaderboardCrewUtils.best("bad", 10)).to.equal(10)
		end)
	end)

	describe("board wire", function()
		it("round-trips a board through plain data", function()
			local board = {
				week = "2026-11-02",
				endsAt = 1794268800,
				entries = { { names = { "A", "B" }, score = 900 }, { names = { "C" }, score = 400 } },
			}
			local decoded = LeaderboardCrewUtils.decodeBoard(LeaderboardCrewUtils.encodeBoard(board))
			expect(decoded.week).to.equal("2026-11-02")
			expect(#decoded.entries).to.equal(2)
			expect(decoded.entries[1].names[2]).to.equal("B")
			expect(decoded.entries[2].score).to.equal(400)
		end)

		it("reads an empty board (an empty list does not survive the wire) and refuses junk", function()
			local empty = LeaderboardCrewUtils.decodeBoard({ week = "2026-11-02", endsAt = 1 })
			expect(#empty.entries).to.equal(0)
			expect(LeaderboardCrewUtils.decodeBoard(nil)).to.equal(nil)
			expect(LeaderboardCrewUtils.decodeBoard({ week = 3, endsAt = 1 })).to.equal(nil)
			expect(
				LeaderboardCrewUtils.decodeBoard({ week = "w", endsAt = 1, entries = { { names = "x", score = 1 } } })
			).to.equal(nil)
		end)
	end)
end
