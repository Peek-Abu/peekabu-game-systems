local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local StateSyncPublicPlayerStore = require(script.Parent.StateSyncPublicPlayerStore)

local VIEWER, A, B, C = 970001, 970002, 970003, 970004

return function()
	beforeEach(function()
		StateSyncPublicPlayerStore._resetVersionsForTesting() -- other spec files publish without resetting
	end)

	afterEach(function()
		for _, userId in { VIEWER, A, B, C } do
			StateSyncPublicPlayerStore.remove(userId)
		end
		StateSyncPublicPlayerStore._resetVersionsForTesting()
	end)

	it("serves only the entries in the viewer's relevant set, keyed by string userId", function()
		StateSyncPublicPlayerStore.set(A, { health = 80, maxHealth = 100 })
		StateSyncPublicPlayerStore.set(B, { health = 50, maxHealth = 200 })
		StateSyncPublicPlayerStore.setRelevant(VIEWER, { A })
		local map = StateSyncPublicPlayerStore.getterFor(VIEWER)()
		expect(map[tostring(A)].health).to.equal(80)
		expect(map[tostring(B)]).to.equal(nil)
	end)

	it("follows relevant-set changes", function()
		StateSyncPublicPlayerStore.set(A, { health = 80, maxHealth = 100 })
		StateSyncPublicPlayerStore.set(B, { health = 50, maxHealth = 200 })
		local getter = StateSyncPublicPlayerStore.getterFor(VIEWER)
		StateSyncPublicPlayerStore.setRelevant(VIEWER, { A, B })
		expect(getter()[tostring(B)].maxHealth).to.equal(200)
		StateSyncPublicPlayerStore.setRelevant(VIEWER, { B })
		expect(getter()[tostring(A)]).to.equal(nil)
	end)

	it("re-runs a viewer's getter for relevant changes only, never for irrelevant players", function()
		StateSyncPublicPlayerStore.set(A, { health = 80, maxHealth = 100 })
		StateSyncPublicPlayerStore.set(C, { health = 10, maxHealth = 100 })
		StateSyncPublicPlayerStore.setRelevant(VIEWER, { A })
		local getter = StateSyncPublicPlayerStore.getterFor(VIEWER)
		local runs = 0
		local dispose = Charm.effect(function()
			getter()
			runs += 1
		end)
		local baseline = runs
		StateSyncPublicPlayerStore.set(C, { health = 20, maxHealth = 100 }) -- not relevant to VIEWER
		expect(runs).to.equal(baseline)
		StateSyncPublicPlayerStore.set(A, { health = 70, maxHealth = 100 })
		expect(runs).to.equal(baseline + 1)
		StateSyncPublicPlayerStore.setRelevant(VIEWER, { A, C })
		expect(runs).to.equal(baseline + 2)
		dispose()
	end)

	it("snapshots an entry: mutating the source afterwards changes nothing", function()
		local source = { health = 80, maxHealth = 100 }
		StateSyncPublicPlayerStore.set(A, source)
		source.health = 1
		expect(StateSyncPublicPlayerStore.get(A).health).to.equal(80)
	end)

	it("a partial update preserves the other fields", function()
		StateSyncPublicPlayerStore.set(A, { health = 80, maxHealth = 100 })
		StateSyncPublicPlayerStore.set(A, {
			appearance = { cosmetics = {}, accessories = {}, body = {}, headType = "Covered", surfaces = {} },
			appearanceVersion = 7,
		})
		expect(StateSyncPublicPlayerStore.get(A).health).to.equal(80)
		expect(StateSyncPublicPlayerStore.get(A).appearanceVersion).to.equal(7)
		StateSyncPublicPlayerStore.set(A, { health = 55 })
		expect(StateSyncPublicPlayerStore.get(A).appearance.headType).to.equal("Covered")
		expect(StateSyncPublicPlayerStore.get(A).appearanceVersion).to.equal(7)
	end)

	it("publish bumps the entry version and deep-copies the appearance", function()
		local appearance = { cosmetics = {}, accessories = {}, body = {}, headType = "Covered", surfaces = {} }
		StateSyncPublicPlayerStore.publish(A, appearance)
		expect(StateSyncPublicPlayerStore.get(A).appearanceVersion).to.equal(1)
		expect(StateSyncPublicPlayerStore.get(A).appearance.headType).to.equal("Covered")
		appearance.headType = "Uncovered"
		expect(StateSyncPublicPlayerStore.get(A).appearance.headType).to.equal("Covered")
		StateSyncPublicPlayerStore.publish(A, appearance)
		expect(StateSyncPublicPlayerStore.get(A).appearanceVersion).to.equal(2)
	end)

	it("keeps explicit zeros in a merge (health = 0 is a write, not an absent field)", function()
		StateSyncPublicPlayerStore.set(A, { health = 80, maxHealth = 100, appearanceVersion = 3 })
		StateSyncPublicPlayerStore.set(A, { health = 0 })
		expect(StateSyncPublicPlayerStore.get(A).health).to.equal(0)
		expect(StateSyncPublicPlayerStore.get(A).maxHealth).to.equal(100)
		expect(StateSyncPublicPlayerStore.get(A).appearanceVersion).to.equal(3)
		StateSyncPublicPlayerStore.set(A, { maxHealth = 0, appearanceVersion = 0 })
		expect(StateSyncPublicPlayerStore.get(A).health).to.equal(0)
		expect(StateSyncPublicPlayerStore.get(A).maxHealth).to.equal(0)
		expect(StateSyncPublicPlayerStore.get(A).appearanceVersion).to.equal(0)
	end)

	it("a vitals-only update preserves the appearance and its version", function()
		StateSyncPublicPlayerStore.publish(
			A,
			{ cosmetics = {}, accessories = {}, body = {}, headType = "Covered", surfaces = {} }
		)
		StateSyncPublicPlayerStore.set(A, { health = 42, maxHealth = 100 })
		expect(StateSyncPublicPlayerStore.get(A).health).to.equal(42)
		expect(StateSyncPublicPlayerStore.get(A).appearanceVersion).to.equal(1)
		expect(StateSyncPublicPlayerStore.get(A).appearance.headType).to.equal("Covered")
	end)

	it("stores a deep copy of the appearance: mutating the source afterwards changes nothing", function()
		local source = { cosmetics = {}, accessories = {}, body = {}, headType = "Covered", surfaces = {} }
		StateSyncPublicPlayerStore.set(A, { appearance = source, appearanceVersion = 1 })
		source.headType = "Uncovered"
		source.cosmetics.hair = { id = "Hair1", colors = {} }
		expect(StateSyncPublicPlayerStore.get(A).appearance.headType).to.equal("Covered")
		expect(StateSyncPublicPlayerStore.get(A).appearance.cosmetics.hair).to.equal(nil)
	end)

	it("remove drops the entry and the player's own relevant set", function()
		StateSyncPublicPlayerStore.set(A, { health = 80, maxHealth = 100 })
		StateSyncPublicPlayerStore.setRelevant(VIEWER, { A })
		StateSyncPublicPlayerStore.setRelevant(A, { A })
		StateSyncPublicPlayerStore.remove(A)
		expect(StateSyncPublicPlayerStore.get(A)).to.equal(nil)
		expect(StateSyncPublicPlayerStore.getterFor(VIEWER)()[tostring(A)]).to.equal(nil)
		expect(#StateSyncPublicPlayerStore.relevantOf(A)).to.equal(0)
	end)

	-- A viewer keeps a rejoiner's old puppet and only re-dresses it for a NEWER version (CustomizationOutfitSystem), so the
	-- sequence must not restart when the player leaves: found in staging, where a reset sequence would have
	-- left viewers on the previous session's look.
	it("keeps the version climbing across a leave and a rejoin", function()
		local appearance = { cosmetics = {}, accessories = {}, body = {}, headType = "Covered", surfaces = {} }
		StateSyncPublicPlayerStore.publish(A, appearance)
		StateSyncPublicPlayerStore.publish(A, appearance)
		StateSyncPublicPlayerStore.remove(A)
		StateSyncPublicPlayerStore.set(A, { health = 100, maxHealth = 100 }) -- the rejoin's vitals placeholder
		expect(StateSyncPublicPlayerStore.get(A).appearanceVersion).to.equal(0)
		StateSyncPublicPlayerStore.publish(A, appearance)
		expect(StateSyncPublicPlayerStore.get(A).appearanceVersion).to.equal(3)
	end)

	it("counts an explicit version written by set when picking the next one", function()
		StateSyncPublicPlayerStore.set(A, { appearanceVersion = 7 })
		StateSyncPublicPlayerStore.remove(A)
		StateSyncPublicPlayerStore.publish(
			A,
			{ cosmetics = {}, accessories = {}, body = {}, headType = "Covered", surfaces = {} }
		)
		expect(StateSyncPublicPlayerStore.get(A).appearanceVersion).to.equal(8)
	end)
end
