local ServerScriptService = game:GetService("ServerScriptService")

local TrainingMapRules = require(ServerScriptService.Features.Training.Rules.TrainingMapRules)

local KINDS = {
	pile = function(kind)
		return kind == "paper"
	end,
	item = function(kind)
		return kind == "coffeeMug" or kind == "rubbishBag"
	end,
	treasure = function(kind)
		return kind == "coffeeMug"
	end,
}

local function at(x, z)
	return CFrame.new(x, 0, z)
end

local function entry(role, fields)
	local e = { role = role, cframe = at(0, 0), size = Vector3.new(4, 4, 4) }
	for key, value in fields or {} do
		e[key] = value
	end
	return e
end

-- A whole, valid hall: one of each single part, 5 stops with zones, the stop-1 pile, the stop-2 mug, two doors and
-- a 3-point route.
local function hall()
	local list = {
		entry("spawn"),
		entry("rest", { cframe = at(0, 90) }),
		entry("safe", { size = Vector3.new(10, 10, 10) }),
		entry("bay", { cframe = at(0, 20), size = Vector3.new(10, 10, 10) }),
		entry("pile", { stop = 1, kind = "paper", cframe = at(0, 10) }),
		entry("item", { stop = 2, kind = "coffeeMug", cframe = at(0, 30) }),
		entry("item", { stop = 2, kind = "rubbishBag", cframe = at(2, 30) }),
		entry("door", { stop = 1 }),
		entry("door", { stop = 2 }),
		entry("route", { order = 2, cframe = at(0, 60) }),
		entry("route", { order = 1, cframe = at(0, 50) }),
		entry("route", { order = 3, cframe = at(0, 70) }),
		entry("light", { order = 1 }),
		entry("sign", { stop = 1 }),
	}
	for stop = 1, 5 do
		table.insert(list, entry("stop", { stop = stop, cframe = at(0, stop * 15) }))
		table.insert(list, entry("zone", { stop = stop, cframe = at(0, stop * 15) }))
	end
	return list
end

local function without(list, role, stop)
	local kept = {}
	for _, e in list do
		if not (e.role == role and (stop == nil or e.stop == stop)) then
			table.insert(kept, e)
		end
	end
	return kept
end

local function hasError(errors, needle)
	for _, message in errors do
		if string.find(message, needle, 1, true) then
			return true
		end
	end
	return false
end

return function()
	describe("read", function()
		it("reads a whole hall into a plan", function()
			local plan, errors = TrainingMapRules.read(hall(), KINDS)
			expect(#errors).to.equal(0)
			expect(plan).to.be.ok()
			expect(#plan.stops).to.equal(5)
			expect(#plan.zones).to.equal(5)
			expect(#plan.piles).to.equal(1)
			expect(#plan.items).to.equal(2)
			expect(plan.rest).to.equal(Vector3.new(0, 0, 90))
		end)

		it("puts the route in its order", function()
			local plan = TrainingMapRules.read(hall(), KINDS)
			expect(plan.route[1]).to.equal(Vector3.new(0, 0, 50))
			expect(plan.route[3]).to.equal(Vector3.new(0, 0, 70))
		end)

		it("names a missing single part", function()
			local plan, errors = TrainingMapRules.read(without(hall(), "spawn"), KINDS)
			expect(plan).never.to.be.ok()
			expect(hasError(errors, "spawn")).to.equal(true)
		end)

		it("names a stop without its start or zone", function()
			local _, errors = TrainingMapRules.read(without(hall(), "zone", 4), KINDS)
			expect(hasError(errors, "stop 4")).to.equal(true)
		end)

		it("needs a known pile at the dust stop and a treasure at the treasure stop", function()
			local _, piles = TrainingMapRules.read(without(hall(), "pile"), KINDS)
			expect(hasError(piles, "stop 1")).to.equal(true)
			local list = without(hall(), "item")
			table.insert(list, entry("item", { stop = 2, kind = "rubbishBag" }))
			local _, items = TrainingMapRules.read(list, KINDS)
			expect(hasError(items, "stop 2")).to.equal(true)
		end)

		it("refuses an unknown pile kind", function()
			local list = hall()
			table.insert(list, entry("pile", { stop = 1, kind = "glitter" }))
			local _, errors = TrainingMapRules.read(list, KINDS)
			expect(hasError(errors, "glitter")).to.equal(true)
		end)

		it("needs a door after each stop with its own goal", function()
			local _, errors = TrainingMapRules.read(without(hall(), "door", 2), KINDS)
			expect(hasError(errors, "door")).to.equal(true)
		end)

		it("needs two route points with different orders", function()
			local list = without(hall(), "route")
			table.insert(list, entry("route", { order = 1 }))
			table.insert(list, entry("route", { order = 1, cframe = at(5, 5) }))
			local _, errors = TrainingMapRules.read(list, KINDS)
			expect(hasError(errors, "route")).to.equal(true)
		end)

		it("refuses an unknown role", function()
			local list = hall()
			table.insert(list, entry("trampoline"))
			local _, errors = TrainingMapRules.read(list, KINDS)
			expect(hasError(errors, "trampoline")).to.equal(true)
		end)
	end)

	describe("boxes", function()
		it("finds a point inside a box part, turned or not", function()
			local box =
				TrainingMapRules.boxOf(CFrame.new(10, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(2, 4, 8))
			expect(TrainingMapRules.inside(box, Vector3.new(13, 0, 0))).to.equal(true)
			expect(TrainingMapRules.inside(box, Vector3.new(10, 0, 3))).to.equal(false)
		end)
	end)
end
