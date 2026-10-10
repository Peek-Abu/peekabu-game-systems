local QueuePadRules = require(script.Parent.QueuePadRules)

local function same(a, b)
	if #a ~= #b then
		return false
	end
	for index, value in a do
		if b[index] ~= value then
			return false
		end
	end
	return true
end

return function()
	describe("config", function()
		it("reads a complete pad", function()
			local config = QueuePadRules.config(2, 10, "away")
			expect(config.capacity).to.equal(2)
			expect(config.countdown).to.equal(10)
			expect(config.destination).to.equal("away")
		end)

		it("defaults the capacity and countdown", function()
			local config = QueuePadRules.config(nil, nil, "away")
			expect(config.capacity).to.equal(4)
			expect(config.countdown).to.equal(15)
		end)

		it("clamps the countdown", function()
			expect(QueuePadRules.config(nil, -5, "away").countdown).to.equal(0)
			expect(QueuePadRules.config(nil, 9999, "away").countdown).to.equal(300)
		end)

		it("refuses a bad capacity and says why", function()
			for _, bad in { 0, 51, 2.5, "4", 0 / 0 } do
				local config, reason = QueuePadRules.config(bad, nil, "away")
				expect(config).to.equal(nil)
				expect(reason).never.to.equal(nil)
			end
		end)

		it("refuses a countdown that is not a number", function()
			expect(QueuePadRules.config(4, "soon", "away")).to.equal(nil)
			expect(QueuePadRules.config(4, 0 / 0, "away")).to.equal(nil)
		end)

		it("refuses a pad with no destination", function()
			expect(QueuePadRules.config(4, 15, nil)).to.equal(nil)
			expect(QueuePadRules.config(4, 15, "")).to.equal(nil)
			expect(QueuePadRules.config(4, 15, 7)).to.equal(nil)
		end)
	end)

	describe("isAboard", function()
		local PAD = CFrame.new(0, 0.5, 0)
		local SIZE = Vector3.new(10, 1, 10)

		it("counts a player standing on the pad", function()
			expect(QueuePadRules.isAboard(PAD, SIZE, Vector3.new(4, 3, -4), 8)).to.equal(true)
		end)

		it("does not count a player beside it", function()
			expect(QueuePadRules.isAboard(PAD, SIZE, Vector3.new(5.5, 3, 0), 8)).to.equal(false)
		end)

		it("does not count a player far above or below it", function()
			expect(QueuePadRules.isAboard(PAD, SIZE, Vector3.new(0, 20, 0), 8)).to.equal(false)
			expect(QueuePadRules.isAboard(PAD, SIZE, Vector3.new(0, -3, 0), 8)).to.equal(false)
		end)

		it("follows the pad's rotation", function()
			local turned = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(45), 0)
			local narrow = Vector3.new(2, 1, 20)
			-- 6 studs along the pad's long axis is on it; 6 studs along world X is off it.
			local alongPad = turned:PointToWorldSpace(Vector3.new(0, 3, 6))
			expect(QueuePadRules.isAboard(turned, narrow, alongPad, 8)).to.equal(true)
			expect(QueuePadRules.isAboard(turned, narrow, Vector3.new(6, 3, 0), 8)).to.equal(false)
		end)
	end)

	describe("admit", function()
		it("keeps members in join order and adds newcomers after them", function()
			expect(same(QueuePadRules.admit({ 3, 1 }, { 1, 2, 3 }, 4), { 3, 1, 2 })).to.equal(true)
		end)

		it("drops members who stepped off", function()
			expect(same(QueuePadRules.admit({ 3, 1 }, { 1 }, 4), { 1 })).to.equal(true)
		end)

		it("never goes over capacity; the earliest keep their seats", function()
			expect(same(QueuePadRules.admit({ 3, 1 }, { 1, 2, 3, 4 }, 3), { 3, 1, 2 })).to.equal(true)
		end)
	end)

	describe("deadline", function()
		it("starts the countdown when the first player boards", function()
			expect(QueuePadRules.deadline({}, { 1 }, nil, 100, 15)).to.equal(115)
		end)

		it("resets the countdown when someone joins", function()
			expect(QueuePadRules.deadline({ 1 }, { 1, 2 }, 110, 105, 15)).to.equal(120)
		end)

		it("keeps the countdown when someone leaves", function()
			expect(QueuePadRules.deadline({ 1, 2 }, { 1 }, 110, 105, 15)).to.equal(110)
		end)

		it("stops the countdown when the pad empties", function()
			expect(QueuePadRules.deadline({ 1 }, {}, 110, 105, 15)).to.equal(nil)
		end)
	end)

	describe("canDepart", function()
		it("lets anyone aboard depart an open pad", function()
			expect(QueuePadRules.canDepart({ 1, 2 }, "open", 2)).to.equal(true)
		end)

		it("refuses a player who is not aboard", function()
			expect(QueuePadRules.canDepart({ 1 }, "open", 3)).to.equal(false)
		end)

		it("refuses while the pad is already departing", function()
			expect(QueuePadRules.canDepart({ 1 }, "departing", 1)).to.equal(false)
		end)
	end)
end
