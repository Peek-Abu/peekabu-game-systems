local SocialAskCard = require(script.Parent.SocialAskCard)

return function()
	describe("SocialAskCard", function()
		it("asks for a favorite and a thumbs up, with no reward", function()
			local favorited, dismissed = false, false
			local tree = SocialAskCard({
				phone = false,
				onFavorite = function()
					favorited = true
				end,
				onDismiss = function()
					dismissed = true
				end,
			})
			local content = tree.props.children.card.props.children
			expect(content.title.props.text).to.equal("Having fun?")
			expect(string.find(content.body.props.text, "Gleam")).to.equal(nil)
			content.favorite.props.onActivated()
			content.later.props.onActivated()
			expect(favorited).to.equal(true)
			expect(dismissed).to.equal(true)
		end)

		it("sits in the top-right corner on desktop and phone", function()
			for _, phone in { false, true } do
				local tree = SocialAskCard({ phone = phone, onFavorite = function() end, onDismiss = function() end })
				expect(tree.props.AnchorPoint).to.equal(Vector2.new(1, 0))
				expect(tree.props.Position.X.Scale).to.equal(1)
			end
		end)
	end)
end
