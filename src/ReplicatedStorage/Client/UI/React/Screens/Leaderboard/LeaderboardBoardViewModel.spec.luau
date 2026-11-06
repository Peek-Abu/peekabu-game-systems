local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VM = require(ReplicatedStorage.Client.UI.React.Screens.Leaderboard.LeaderboardBoardViewModel)

local NOW = 1000000

local function board(entries)
	return { week = "2026-11-02", endsAt = NOW + 2 * 86400 + 5 * 3600 + 30, entries = entries }
end

return function()
	it("titles the board in kid words and says when it starts over", function()
		local view = VM.view(board({}), NOW)
		expect(view.title).to.equal("BEST CREWS THIS WEEK")
		expect(view.subtitle).to.equal("Most Gloom cleaned in one shift · new board in 2d 5h")
	end)

	it("counts the last day down in hours and minutes", function()
		local view = VM.view({ week = "w", endsAt = NOW + 3 * 3600 + 20 * 60 + 5, entries = {} }, NOW)
		expect(view.subtitle).to.equal("Most Gloom cleaned in one shift · new board in 3h 20m")
	end)

	it("lists the crews best first, numbered, names joined, scores with commas", function()
		local view =
			VM.view(board({ { names = { "Ana", "Bo" }, score = 1240 }, { names = { "Cy" }, score = 600 } }), NOW)
		expect(#view.rows).to.equal(2)
		expect(view.rows[1].rank).to.equal("1")
		expect(view.rows[1].names).to.equal("Ana · Bo")
		expect(view.rows[1].score).to.equal("1,240")
		expect(view.rows[2].rank).to.equal("2")
		expect(view.empty).to.equal(nil)
	end)

	it("invites the first crew when the week is empty, and before the board has loaded", function()
		expect(VM.view(board({}), NOW).empty).to.equal("No crews yet this week. Be the first!")
		local waiting = VM.view(nil, NOW)
		expect(#waiting.rows).to.equal(0)
		expect(waiting.empty).to.equal("No crews yet this week. Be the first!")
		expect(waiting.subtitle).to.equal("Most Gloom cleaned in one shift")
	end)
end
