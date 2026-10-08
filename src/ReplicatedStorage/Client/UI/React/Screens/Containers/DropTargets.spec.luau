--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DropTargets = require(ReplicatedStorage.Client.UI.React.Screens.Containers.DropTargets)

return function()
	-- Two cells stacked with a gap, mirroring the paperdoll's weapon column. The regression this guards
	-- shifted a drop by one topbar, which landed every cell's drop on its neighbour — so the cases below
	-- deliberately check the gap and both edges, not just the middle.
	local CELLS = {
		weapon = { position = Vector2.new(27, 294), size = Vector2.new(41, 41) },
		offhand = { position = Vector2.new(27, 346), size = Vector2.new(41, 41) },
	}

	describe("rectAt", function()
		it("finds the target a point is inside", function()
			expect(DropTargets.rectAt(CELLS, Vector2.new(47, 314))).to.equal("weapon")
			expect(DropTargets.rectAt(CELLS, Vector2.new(47, 366))).to.equal("offhand")
		end)

		it("returns nil for a point in the gap between targets", function()
			expect(DropTargets.rectAt(CELLS, Vector2.new(47, 340))).to.equal(nil)
		end)

		it("does not resolve a point on one cell to its neighbour", function()
			-- The exact failure that shipped: the point was shifted down by the 58px topbar inset.
			local shifted = Vector2.new(47, 314 + 58)
			expect(DropTargets.rectAt(CELLS, shifted)).never.to.equal("weapon")
		end)

		it("includes its own edges", function()
			expect(DropTargets.rectAt(CELLS, Vector2.new(27, 294))).to.equal("weapon")
			expect(DropTargets.rectAt(CELLS, Vector2.new(68, 335))).to.equal("weapon")
		end)

		it("returns nil for a point outside every target", function()
			expect(DropTargets.rectAt(CELLS, Vector2.new(800, 200))).to.equal(nil)
			expect(DropTargets.rectAt(CELLS, Vector2.new(47, 100))).to.equal(nil)
		end)

		it("returns nil when there are no targets at all", function()
			-- The state the paperdoll's cells were stuck in when their refs never attached.
			expect(DropTargets.rectAt({}, Vector2.new(47, 314))).to.equal(nil)
		end)
	end)
end
