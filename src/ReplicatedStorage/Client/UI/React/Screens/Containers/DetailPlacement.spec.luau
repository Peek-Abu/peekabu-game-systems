--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DetailPlacement = require(ReplicatedStorage.Client.UI.React.Screens.Containers.DetailPlacement)

return function()
	local VIEWPORT = Vector2.new(1920, 1080)
	-- Vector2 stores its components as FLOAT32, so a rect that came back through one has already been
	-- rounded, while the expectations below are computed in Luau's float64. 1920 * 0.0865 is 166.08 as a
	-- double and 166.080002 once it has been a Vector2 — past TestEZ's default tolerance, which is
	-- tighter than the storage these values live in. A hundredth of a PIXEL is the honest bar here: far
	-- below anything that could be seen, and far above float32's error.
	local EPSILON = 0.01

	local function slotAt(x, y)
		return { position = Vector2.new(x, y), size = Vector2.new(90, 90) }
	end

	describe("rect", function()
		it("sizes the card from the viewport width and its own aspect", function()
			local _, size = DetailPlacement.rect(nil, VIEWPORT)
			expect(size.X).to.be.near(VIEWPORT.X * DetailPlacement.WIDTH_SCALE, EPSILON)
			expect(size.Y).to.be.near(size.X / DetailPlacement.ASPECT, EPSILON)
		end)

		it("centres the card when nothing is anchored", function()
			local position, size = DetailPlacement.rect(nil, VIEWPORT)
			expect(position.X).to.be.near((VIEWPORT.X - size.X) / 2, EPSILON)
			expect(position.Y).to.be.near((VIEWPORT.Y - size.Y) / 2, EPSILON)
		end)

		it("puts the card to the right of the slot when there is room", function()
			local anchor = slotAt(200, 400)
			local position = DetailPlacement.rect(anchor, VIEWPORT)
			expect(position.X).to.be.near(200 + 90 + DetailPlacement.GAP_PX, EPSILON)
		end)

		it("centres the card on the slot vertically", function()
			local anchor = slotAt(200, 400)
			local position, size = DetailPlacement.rect(anchor, VIEWPORT)
			expect(position.Y).to.be.near(400 + 45 - size.Y / 2, EPSILON)
		end)

		it("flips to the left of the slot when the card would run off the right edge", function()
			-- A slot hard against the right edge: the preferred side cannot fit.
			local anchor = slotAt(VIEWPORT.X - 100, 400)
			local position, size = DetailPlacement.rect(anchor, VIEWPORT)
			expect(position.X).to.be.near(VIEWPORT.X - 100 - size.X - DetailPlacement.GAP_PX, EPSILON)
		end)

		it("flips before the ACTION MENU would run off the right edge, not just the card", function()
			-- The regression: a slot whose card fits on the right, but whose action column does not. Left
			-- unreserved, EQUIP/DISMANTLE/FAVORITE were cut off by the screen edge and partly unclickable.
			local width = VIEWPORT.X * DetailPlacement.WIDTH_SCALE
			local menu = width * DetailPlacement.ACTIONS_WIDTH_SCALE
			-- Place the slot so the card alone clears the edge with room, but card + menu does not.
			local slotX = VIEWPORT.X - 90 - DetailPlacement.GAP_PX - width - menu / 2
			local position, size = DetailPlacement.rect(slotAt(slotX, 400), VIEWPORT)
			expect(position.X).to.be.near(slotX - size.X - DetailPlacement.GAP_PX, EPSILON)
		end)

		it("keeps the card on the right when the menu also fits", function()
			local anchor = slotAt(200, 400)
			local position, size = DetailPlacement.rect(anchor, VIEWPORT)
			local right = position.X + size.X * (1 + DetailPlacement.ACTIONS_WIDTH_SCALE)
			expect(position.X).to.be.near(200 + 90 + DetailPlacement.GAP_PX, EPSILON)
			expect(right <= VIEWPORT.X).to.equal(true)
		end)

		it("clamps the card on screen for a slot near the bottom", function()
			local anchor = slotAt(200, VIEWPORT.Y - 40)
			local position, size = DetailPlacement.rect(anchor, VIEWPORT)
			expect(position.Y + size.Y <= VIEWPORT.Y).to.equal(true)
		end)

		it("clamps the card on screen for a slot near the top", function()
			local anchor = slotAt(200, 0)
			local position = DetailPlacement.rect(anchor, VIEWPORT)
			expect(position.Y >= DetailPlacement.GAP_PX).to.equal(true)
		end)

		it("keeps the card on screen when the viewport is shorter than the card", function()
			-- The clamp's two bounds cross over here; it must not produce a negative position.
			local short = Vector2.new(1920, 100)
			local position = DetailPlacement.rect(slotAt(200, 50), short)
			expect(position.Y).to.be.near(DetailPlacement.GAP_PX, EPSILON)
		end)
	end)
end
