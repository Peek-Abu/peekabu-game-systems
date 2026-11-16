local ToonViewportModel = require(script.Parent.ToonViewportModel)

return function()
	describe("lookKey", function()
		it("joins the employee, skin, style, vacuum and lanyard", function()
			local key = ToonViewportModel.lookKey({
				employee = "pippa",
				skin = "carnival",
				style = 2,
				vacuum = "red",
				lanyard = true,
				framing = "full",
				size = UDim2.fromScale(1, 1),
			})
			expect(key).to.equal("pippa|carnival|2|red|lanyard")
		end)

		it("fills the gaps: no skin or vacuum is empty, no style is 1, no lanyard is empty", function()
			local key =
				ToonViewportModel.lookKey({ employee = "pippa", framing = "full", size = UDim2.fromScale(1, 1) })
			expect(key).to.equal("pippa||1||")
		end)

		it("changes with the colour style, so a style change rebuilds", function()
			local one =
				ToonViewportModel.lookKey({ employee = "pippa", style = 1, framing = "full", size = UDim2.new() })
			local two =
				ToonViewportModel.lookKey({ employee = "pippa", style = 2, framing = "full", size = UDim2.new() })
			expect(one).never.to.equal(two)
		end)

		it("reads a whole player's look from the outfit instead", function()
			local key = ToonViewportModel.lookKey({
				employee = "prickles",
				outfit = {
					employee = "pippa",
					look = { skin = "carnival", style = 3 },
					vacuum = "red",
					stickers = {},
				},
				framing = "full",
				size = UDim2.new(),
			})
			expect(key).to.equal("pippa|carnival|3|red")
		end)
	end)
end
