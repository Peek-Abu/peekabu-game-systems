local Panel = require(script.Parent.CompanyWorkOrderTracker)
return function()
	it("keeps the phone tracker above the thumbstick and left of action buttons", function()
		local tree = Panel({
			phone = true,
			order = "Help clear 8 piles",
			progress = 2,
			target = 8,
			claimed = false,
			onUnpin = function() end,
		})
		expect(tree.props.AnchorPoint).to.equal(Vector2.zero)
		expect(tree.props.Position.Y.Offset + tree.props.Size.Y.Offset <= 200).to.equal(true)
		expect(tree.props.Position.X.Offset + tree.props.Size.X.Offset < 338).to.equal(true)
	end)

	it("shows exact progress and unpins on request", function()
		local hidden = false
		local tree = Panel({
			phone = false,
			order = "Clear 8 piles",
			progress = 3,
			target = 8,
			claimed = false,
			onUnpin = function()
				hidden = true
			end,
		})
		expect(tree.props.children.card.props.children.meter.props.label).to.equal("3 / 8")
		tree.props.children.card.props.children.hide.props.onActivated()
		expect(hidden).to.equal(true)
	end)
end
