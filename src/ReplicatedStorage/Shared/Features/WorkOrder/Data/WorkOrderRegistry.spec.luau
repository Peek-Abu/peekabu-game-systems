local WorkOrderRegistry = require(script.Parent.WorkOrderRegistry)

-- Monday 26 Oct 2026 00:00 UTC, an exact UTC midnight; DAY is the rotation step.
local MONDAY = 1792972800
local DAY = 86400

return function()
	describe("the catalog", function()
		it("is a valid ladder of orders", function()
			expect(WorkOrderRegistry.check(WorkOrderRegistry.all())).to.equal(true)
			expect(#WorkOrderRegistry.all() >= 4).to.equal(true)
		end)

		it("gives every order a non-empty id, label, known kind and a positive whole target", function()
			for _, order in WorkOrderRegistry.all() do
				expect(#order.id > 0).to.equal(true)
				expect(#order.label > 0).to.equal(true)
				expect(order.target >= 1).to.equal(true)
				expect(order.target).to.equal(math.floor(order.target))
				expect(WorkOrderRegistry.get(order.id)).to.equal(order)
			end
		end)

		it("rejects duplicate ids, an empty id or label, a bad target and an unknown kind", function()
			local base = { id = "clear-floor", kind = "piles", target = 10, label = "Clear 10 piles" }
			expect(WorkOrderRegistry.check({ base })).to.equal(true)
			expect(WorkOrderRegistry.check({ base, { id = "clear-floor", kind = "cargo", target = 3, label = "x" } })).to.equal(
				false
			)
			expect(WorkOrderRegistry.check({ { id = "", kind = "piles", target = 10, label = "Clear 10 piles" } })).to.equal(
				false
			)
			expect(WorkOrderRegistry.check({ { id = "a", kind = "piles", target = 10, label = "" } })).to.equal(false)
			expect(WorkOrderRegistry.check({ { id = "a", kind = "piles", target = 0, label = "Clear" } })).to.equal(
				false
			)
			expect(WorkOrderRegistry.check({ { id = "a", kind = "piles", target = 2.5, label = "Clear" } })).to.equal(
				false
			)
			expect(WorkOrderRegistry.check({ { id = "a", kind = "dance", target = 2, label = "Dance" } })).to.equal(
				false
			)
			expect(WorkOrderRegistry.check({})).to.equal(false)
		end)

		it("hands out the catalog as a copy", function()
			local all = WorkOrderRegistry.all()
			table.insert(all, { id = "house", kind = "piles", target = 1, label = "lunch" })
			expect(#WorkOrderRegistry.all()).to.equal(#all - 1)
		end)
	end)

	describe("lookup", function()
		it("finds an order by id and is nil for anything else", function()
			local first = WorkOrderRegistry.all()[1]
			expect(WorkOrderRegistry.get(first.id)).to.equal(first)
			expect(WorkOrderRegistry.get("no-such-order")).to.equal(nil)
			expect(WorkOrderRegistry.get("")).to.equal(nil)
		end)
	end)

	describe("the daily rotation", function()
		it("counts UTC days from the epoch", function()
			expect(WorkOrderRegistry.dayIndex(MONDAY)).to.equal(20752)
			expect(WorkOrderRegistry.dayIndex(MONDAY + 3599)).to.equal(20752)
			expect(WorkOrderRegistry.dayIndex(MONDAY + DAY)).to.equal(20753)
			expect(WorkOrderRegistry.dayIndex(MONDAY - 1)).to.equal(20751)
		end)

		it("gives the whole UTC day one order", function()
			local morning = WorkOrderRegistry.orderFor(MONDAY)
			local night = WorkOrderRegistry.orderFor(MONDAY + DAY - 1)
			expect(night.id).to.equal(morning.id)
			expect(WorkOrderRegistry.orderFor(MONDAY).id).to.equal(morning.id)
		end)

		it("moves to a different order tomorrow", function()
			expect(WorkOrderRegistry.orderFor(MONDAY + DAY).id).never.to.equal(WorkOrderRegistry.orderFor(MONDAY).id)
		end)

		it("cycles through every order without repeating inside one cycle", function()
			local seen = {}
			local count = #WorkOrderRegistry.all()
			for day = 0, count - 1 do
				local id = WorkOrderRegistry.orderFor(MONDAY + day * DAY).id
				expect(seen[id]).never.to.be.ok()
				seen[id] = true
			end
			local total = 0
			for _ in seen do
				total += 1
			end
			expect(total).to.equal(count)
		end)

		it("is the same order for the same day however far away it is", function()
			local far = MONDAY + 400 * DAY
			expect(WorkOrderRegistry.orderFor(far).id).to.equal(WorkOrderRegistry.orderFor(far + DAY - 1).id)
		end)
	end)
end
