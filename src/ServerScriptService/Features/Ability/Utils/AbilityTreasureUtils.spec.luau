local AbilityTreasureUtils = require(script.Parent.AbilityTreasureUtils)

local function item(id, x, grimy, claimed)
	return { id = id, position = Vector3.new(x, 0, 0), grimy = grimy, claimed = claimed }
end

return function()
	it("picks the closest grimy treasure", function()
		local found = AbilityTreasureUtils.closest(Vector3.zero, {
			item(1, 30, true, false),
			item(2, 10, true, false),
			item(3, 20, true, false),
		})
		expect(found).to.equal(2)
	end)

	it("skips trash and claimed items however close", function()
		local found = AbilityTreasureUtils.closest(Vector3.zero, {
			item(1, 1, false, false),
			item(2, 2, true, true),
			item(3, 50, true, false),
		})
		expect(found).to.equal(3)
	end)

	it("breaks a tie by the lower id", function()
		local found = AbilityTreasureUtils.closest(Vector3.zero, {
			item(9, 10, true, false),
			item(4, -10, true, false),
		})
		expect(found).to.equal(4)
	end)

	it("finds nothing when nothing qualifies", function()
		expect(AbilityTreasureUtils.closest(Vector3.zero, {})).to.equal(nil)
		expect(AbilityTreasureUtils.closest(Vector3.zero, { item(1, 5, false, false) })).to.equal(nil)
	end)
end
