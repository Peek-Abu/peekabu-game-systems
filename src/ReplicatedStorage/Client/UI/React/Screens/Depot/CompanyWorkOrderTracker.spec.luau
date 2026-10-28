local Panel = require(script.Parent.CompanyWorkOrderTracker)

local function lines(overrides)
	local value = {
		timecard = "PUNCH YOUR TIMECARD!",
		timecardDue = true,
		order = "Help clear 8 piles",
		progress = 3,
		target = 8,
		claimed = false,
		footer = "+100 CREDITS",
	}
	for key, item in overrides or {} do
		value[key] = item
	end
	return value
end

return function()
	it("keeps the phone shift tracker above the thumbstick and left of action buttons", function()
		local tree = Panel({ phone = true, where = "shift", lines = lines(), onUnpin = function() end })
		expect(tree.props.AnchorPoint).to.equal(Vector2.zero)
		expect(tree.props.Position.Y.Offset + tree.props.Size.Y.Offset <= 200).to.equal(true)
		expect(tree.props.Position.X.Offset + tree.props.Size.X.Offset < 338).to.equal(true)
		expect(tree.props.children.card.props.children.footer).to.equal(nil)
	end)

	it("shows exact progress, the timecard line and unpins on request", function()
		local hidden = false
		local tree = Panel({
			phone = false,
			where = "shift",
			lines = lines(),
			onUnpin = function()
				hidden = true
			end,
		})
		local content = tree.props.children.card.props.children
		expect(content.meter.props.label).to.equal("3 / 8")
		expect(content.timecard.props.text).to.equal("PUNCH YOUR TIMECARD!")
		expect(content.footer.props.text).to.equal("+100 CREDITS")
		content.hide.props.onActivated()
		expect(hidden).to.equal(true)
		expect(tree.props.children.open).to.equal(nil)
	end)

	it("sits under the clipboard button in the hub, gold while the punch is due, and opens on tap", function()
		local opened = false
		local tree = Panel({
			phone = false,
			where = "hub",
			lines = lines(),
			onUnpin = function() end,
			onOpen = function()
				opened = true
			end,
		})
		expect(tree.props.Position).to.equal(UDim2.fromOffset(840, 134))
		expect(tree.props.children.card.props.hue).to.equal("gold")
		tree.props.children.open.props[require(game:GetService("ReplicatedStorage").Packages.React).Event.Activated]()
		expect(opened).to.equal(true)
		local done = Panel({
			phone = false,
			where = "hub",
			lines = lines({ timecardDue = false }),
			onUnpin = function() end,
		})
		expect(done.props.children.card.props.hue).to.equal("grape")
	end)
end
