local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local StateSyncPublicPlayerStore = require(script.Parent.StateSyncPublicPlayerStore)

local VIEWER, A, B, C = 970001, 970002, 970003, 970004

return function()
	afterEach(function()
		for _, userId in { VIEWER, A, B, C } do
			StateSyncPublicPlayerStore.remove(userId)
		end
	end)

	describe("default relevance (the roster)", function()
		it("shows every joined player to every viewer, keyed by string userId", function()
			StateSyncPublicPlayerStore.join(A)
			StateSyncPublicPlayerStore.join(B)
			StateSyncPublicPlayerStore.set(A, { carrying = "egg" })
			local map = StateSyncPublicPlayerStore.getterFor(VIEWER)()
			expect(map[tostring(A)].carrying).to.equal("egg")
			expect(map[tostring(B)]).to.be.ok()
		end)

		it("join gives an empty entry and is idempotent", function()
			StateSyncPublicPlayerStore.join(A)
			StateSyncPublicPlayerStore.set(A, { dead = true })
			StateSyncPublicPlayerStore.join(A)
			expect(StateSyncPublicPlayerStore.get(A).dead).to.equal(true)
			expect(#StateSyncPublicPlayerStore.relevantOf(VIEWER)).to.equal(1)
		end)

		it("drops a player who leaves", function()
			StateSyncPublicPlayerStore.join(A)
			StateSyncPublicPlayerStore.join(B)
			StateSyncPublicPlayerStore.remove(A)
			local map = StateSyncPublicPlayerStore.getterFor(VIEWER)()
			expect(map[tostring(A)]).to.equal(nil)
			expect(map[tostring(B)]).to.be.ok()
			expect(StateSyncPublicPlayerStore.get(A)).to.equal(nil)
		end)
	end)

	describe("explicit relevance", function()
		it("serves only the viewer's explicit set", function()
			StateSyncPublicPlayerStore.join(A)
			StateSyncPublicPlayerStore.join(B)
			StateSyncPublicPlayerStore.setRelevant(VIEWER, { A })
			local map = StateSyncPublicPlayerStore.getterFor(VIEWER)()
			expect(map[tostring(A)]).to.be.ok()
			expect(map[tostring(B)]).to.equal(nil)
		end)

		it("clearRelevant returns the viewer to the roster", function()
			StateSyncPublicPlayerStore.join(A)
			StateSyncPublicPlayerStore.join(B)
			StateSyncPublicPlayerStore.setRelevant(VIEWER, { A })
			StateSyncPublicPlayerStore.clearRelevant(VIEWER)
			expect(StateSyncPublicPlayerStore.getterFor(VIEWER)()[tostring(B)]).to.be.ok()
		end)

		it("remove drops the player's own override", function()
			StateSyncPublicPlayerStore.join(A)
			StateSyncPublicPlayerStore.join(B)
			StateSyncPublicPlayerStore.setRelevant(A, { A })
			StateSyncPublicPlayerStore.remove(A)
			StateSyncPublicPlayerStore.join(A)
			expect(#StateSyncPublicPlayerStore.relevantOf(A)).to.equal(2)
		end)
	end)

	it("re-runs a viewer's getter for relevant changes only, never for irrelevant players", function()
		StateSyncPublicPlayerStore.join(A)
		StateSyncPublicPlayerStore.join(C)
		StateSyncPublicPlayerStore.setRelevant(VIEWER, { A })
		local getter = StateSyncPublicPlayerStore.getterFor(VIEWER)
		local runs = 0
		local dispose = Charm.effect(function()
			getter()
			runs += 1
		end)
		local baseline = runs
		StateSyncPublicPlayerStore.set(C, { score = 2 }) -- not relevant to VIEWER
		expect(runs).to.equal(baseline)
		StateSyncPublicPlayerStore.set(A, { score = 1 })
		expect(runs).to.equal(baseline + 1)
		StateSyncPublicPlayerStore.setRelevant(VIEWER, { A, C })
		expect(runs).to.equal(baseline + 2)
		dispose()
	end)

	it("a partial update preserves the other fields, and explicit falsy values are writes", function()
		StateSyncPublicPlayerStore.set(A, { team = "red", score = 5, alive = true })
		StateSyncPublicPlayerStore.set(A, { score = 0, alive = false })
		local entry = StateSyncPublicPlayerStore.get(A)
		expect(entry.team).to.equal("red")
		expect(entry.score).to.equal(0)
		expect(entry.alive).to.equal(false)
	end)

	it("snapshots an entry: mutating the source afterwards changes nothing", function()
		local source = { score = 80 }
		StateSyncPublicPlayerStore.set(A, source)
		source.score = 1
		expect(StateSyncPublicPlayerStore.get(A).score).to.equal(80)
		expect(table.isfrozen(StateSyncPublicPlayerStore.get(A))).to.equal(true)
	end)

	it("clearField removes one field and leaves the rest", function()
		StateSyncPublicPlayerStore.set(A, { carrying = "egg", team = "red" })
		StateSyncPublicPlayerStore.clearField(A, "carrying")
		expect(StateSyncPublicPlayerStore.get(A).carrying).to.equal(nil)
		expect(StateSyncPublicPlayerStore.get(A).team).to.equal("red")
		StateSyncPublicPlayerStore.clearField(B, "carrying") -- absent entry: no-op, no throw
	end)
end
