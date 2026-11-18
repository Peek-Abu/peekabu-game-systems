local SkillCheckStore = require(script.Parent.SkillCheckStore)

local function ring(id)
	return { id = id, gap = 90, width = 100, arriveAt = 50, travel = 1.2 }
end

return function()
	afterEach(function()
		SkillCheckStore.reset()
	end)

	it("starts empty", function()
		expect(SkillCheckStore.ring()).to.equal(nil)
		expect(SkillCheckStore.result()).to.equal(nil)
		expect(SkillCheckStore.seen()).to.equal(0)
	end)

	it("shows a ring and counts the rings seen", function()
		local first = ring(1)
		SkillCheckStore.show(first)
		expect(SkillCheckStore.ring()).to.equal(first)
		expect(SkillCheckStore.seen()).to.equal(1)
		SkillCheckStore.show(ring(2))
		expect(SkillCheckStore.seen()).to.equal(2)
	end)

	it("does not count the same ring twice", function()
		SkillCheckStore.show(ring(4))
		SkillCheckStore.show(ring(4))
		expect(SkillCheckStore.seen()).to.equal(1)
	end)

	it("keeps the verdict for a ring", function()
		SkillCheckStore.show(ring(3))
		SkillCheckStore.judged(3, false, 12)
		local result = SkillCheckStore.result()
		expect(result.id).to.equal(3)
		expect(result.hit).to.equal(false)
		expect(result.at).to.equal(12)
	end)

	it("hides only the ring it names", function()
		SkillCheckStore.show(ring(5))
		SkillCheckStore.hide(4)
		expect(SkillCheckStore.ring()).to.be.ok()
		SkillCheckStore.hide(5)
		expect(SkillCheckStore.ring()).to.equal(nil)
	end)

	it("forgets everything on reset", function()
		SkillCheckStore.show(ring(6))
		SkillCheckStore.judged(6, true, 1)
		SkillCheckStore.reset()
		expect(SkillCheckStore.ring()).to.equal(nil)
		expect(SkillCheckStore.result()).to.equal(nil)
		expect(SkillCheckStore.seen()).to.equal(0)
	end)
end
