local NpcRosterTracker = require(script.Parent.NpcRosterTracker)

-- Any table stands in for a Model here.
local modelA, modelB, modelC = {}, {}, {}

return function()
	it("hands out ids and finds an NPC by id and by model", function()
		local roster = NpcRosterTracker.new()
		local a = roster:add(modelA, "cow")
		local b = roster:add(modelB, "wolf")
		expect(a).never.to.equal(b)
		expect(roster:idOf(modelA)).to.equal(a)
		expect(roster:get(b).kind).to.equal("wolf")
		expect(roster:get(b).model).to.equal(modelB)
	end)

	it("does not add the same model twice", function()
		local roster = NpcRosterTracker.new()
		local id = roster:add(modelA, "cow")
		expect(roster:add(modelA, "cow")).to.equal(id)
		expect(roster:count()).to.equal(1)
	end)

	it("counts per kind and lists ids sorted", function()
		local roster = NpcRosterTracker.new()
		roster:add(modelA, "cow")
		roster:add(modelB, "cow")
		roster:add(modelC, "wolf")
		expect(roster:countOf("cow")).to.equal(2)
		expect(roster:countOf("bear")).to.equal(0)
		local ids = roster:ids()
		expect(#ids).to.equal(3)
		expect(ids[1] < ids[2]).to.equal(true)
	end)

	it("removes an NPC", function()
		local roster = NpcRosterTracker.new()
		local id = roster:add(modelA, "cow")
		expect(roster:remove(id)).to.equal(true)
		expect(roster:remove(id)).to.equal(false)
		expect(roster:idOf(modelA)).to.equal(nil)
		expect(roster:count()).to.equal(0)
	end)
end
