-- RankNameTag is presentational (its words are the specced RankViewModel); this checks it builds an element and
-- keeps the spec-sibling rule without an exemption.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)
local RankNameTag = require(script.Parent.RankNameTag)

return function()
	describe("RankNameTag", function()
		it("builds a badge element from a tag view", function()
			local view = RankViewModel.tag({ xp = 0, prevXp = 0 }, "Ava")
			expect(type(RankNameTag)).to.equal("function")
			local element = React.createElement(RankNameTag, { view = view })
			expect(element).to.be.ok()
		end)
	end)
end
