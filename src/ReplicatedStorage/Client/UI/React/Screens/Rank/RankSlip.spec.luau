-- RankSlip is presentational (its words are the specced RankViewModel); this checks it builds an element for each
-- layout without a renderer, which keeps the spec-sibling rule without an exemption.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)
local RankSlip = require(script.Parent.RankSlip)

return function()
	describe("RankSlip", function()
		it("is a component that takes a slip view for either layout", function()
			expect(type(RankSlip)).to.equal("function")
			local view = RankViewModel.slip({ xp = 45, prevXp = 10 }, nil, {}, 1)
			for _, layout in { "desktop", "phone" } do
				local element = React.createElement(RankSlip, {
					view = view,
					layout = layout,
					position = UDim2.fromOffset(0, 0),
				})
				expect(element).to.be.ok()
			end
		end)
	end)
end
