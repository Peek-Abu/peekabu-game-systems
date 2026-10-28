local Stamp = require(script.Parent.DepotTimecardStamp)

return function()
	it("slams onto today's tile and shows the banner, keyed by the punch", function()
		local tree = Stamp({
			moment = { day = 3, count = 3, reward = "key", paycheque = false, id = "1792972800:3" },
			banner = "DAY 3! +1 GLOOM KEY",
		})
		local slam = tree.props.children["1792972800:3"]
		expect(slam).to.be.ok()
		expect(slam.props.tile).to.equal(UDim2.fromOffset(24 + 2 * 83, 180))
		expect(slam.props.banner).to.equal("DAY 3! +1 GLOOM KEY")
		expect(slam.props.reward).to.equal(true)
	end)

	it("uses the plain banner colour for a punch that paid nothing", function()
		local tree = Stamp({
			moment = { day = 1, count = 1, paycheque = false, id = "a" },
			banner = "DAY 1! 2 MORE FOR A GLOOM KEY",
		})
		expect(tree.props.children.a.props.reward).to.equal(false)
	end)
end
