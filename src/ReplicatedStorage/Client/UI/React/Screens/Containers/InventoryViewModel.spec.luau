--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.InventoryViewModel)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)

return function()
	-- Register test definitions once (the registry is a global singleton; other specs may run alongside).
	local function def(key, definition)
		if not ItemRegistry.isValidItemType(key) then
			ItemRegistry.register(key, definition)
		end
	end
	def("spec.sword", {
		kind = "weapon",
		name = "Iron Sword",
		rarity = "rare",
		icon = "rbxassetid://1",
		equipSlot = "weapon",
		statBonuses = { strength = 5 },
		requiredLevel = 3,
	})
	def("spec.axe", {
		kind = "weapon",
		name = "Battle Axe",
		rarity = "legendary",
		equipSlot = "weapon",
		statBonuses = { strength = 10 },
	})
	def("spec.helm", {
		kind = "armour",
		name = "Cloth Cap",
		rarity = "common",
		equipSlot = "helmet",
		statBonuses = { rotEndurance = 2 },
	})
	-- Two bonuses so the primary-stat pick has something to choose between; strength is the larger.
	def("spec.blade", {
		kind = "weapon",
		name = "Runed Blade",
		rarity = "epic",
		equipSlot = "weapon",
		statBonuses = { strength = 7, rotEndurance = 3 },
	})
	-- Equal bonuses, so the tie-break has to decide deterministically.
	def("spec.evenblade", {
		kind = "weapon",
		name = "Even Blade",
		rarity = "rare",
		equipSlot = "weapon",
		statBonuses = { strength = 4, rotEndurance = 4 },
	})
	def("spec.potion", { kind = "consumable", name = "Health Potion", rarity = "uncommon", stackMax = 20 })
	def("spec.junk", { kind = "misc", name = "Old Rag", rarity = "common", stackMax = 99 })

	local sword = { itemType = "spec.sword", uid = "u1" }
	local axe = { itemType = "spec.axe", uid = "u2" }
	local helm = { itemType = "spec.helm", uid = "u3" }
	local potion = { itemType = "spec.potion", quantity = 5 }
	local junk = { itemType = "spec.junk", quantity = 1 }
	local all = { sword, axe, helm, potion, junk }

	local function names(list)
		local out = {}
		for _, item in list do
			out[#out + 1] = item.name
		end
		return out
	end

	describe("toDisplay", function()
		it("resolves a unique entry (uid, no quantity)", function()
			local d = InventoryViewModel.toDisplay(sword)
			expect(d).to.be.ok()
			expect(d.name).to.equal("Iron Sword")
			expect(d.rarity).to.equal("rare")
			expect(d.kind).to.equal("weapon")
			expect(d.uid).to.equal("u1")
			expect(d.key).to.equal("u1")
			expect(d.quantity).never.to.be.ok()
			expect(d.requiredLevel).to.equal(3)
			expect(d.icon).to.equal("rbxassetid://1")
		end)

		it("resolves a stack entry (quantity, no uid; key is the itemType)", function()
			local d = InventoryViewModel.toDisplay(potion)
			expect(d.name).to.equal("Health Potion")
			expect(d.kind).to.equal("consumable")
			expect(d.quantity).to.equal(5)
			expect(d.uid).never.to.be.ok()
			expect(d.key).to.equal("spec.potion")
		end)

		it("returns nil for an unregistered itemType", function()
			expect(InventoryViewModel.toDisplay({ itemType = "spec.ghost", quantity = 1 })).never.to.be.ok()
		end)
	end)

	describe("stats", function()
		it("lists every bonus alphabetically by id", function()
			local item = InventoryViewModel.toDisplay({ itemType = "spec.blade", uid = "p1" })
			expect(#item.stats).to.equal(2)
			expect(item.stats[1].id).to.equal("rotEndurance")
			expect(item.stats[2].id).to.equal("strength")
			expect(item.statTotal).to.equal(10)
		end)

		it("folds a rolled affix ONTO the base bonus for the same stat", function()
			-- warriors rolls strength; spec.blade already grants strength 7.
			local plain = InventoryViewModel.toDisplay({ itemType = "spec.blade", uid = "a1" })
			local rolled =
				InventoryViewModel.toDisplay({ itemType = "spec.blade", uid = "a2", affixes = { warriors = 3 } })
			local function strengthOf(item)
				for _, bonus in item.stats do
					if bonus.id == "strength" then
						return bonus.value
					end
				end
				return nil
			end
			expect(strengthOf(plain)).to.equal(7)
			expect(strengthOf(rolled)).to.equal(10)
			-- and the sort total follows the same numbers the card shows
			expect(rolled.statTotal).to.equal(plain.statTotal + 3)
		end)

		it("is empty for an item with no bonuses at all", function()
			expect(#InventoryViewModel.toDisplay(potion).stats).to.equal(0)
			expect(#InventoryViewModel.toDisplay(junk).stats).to.equal(0)
		end)
	end)

	describe("statRows", function()
		local blade = InventoryViewModel.toDisplay({ itemType = "spec.blade", uid = "r1" })
		local axeItem = InventoryViewModel.toDisplay({ itemType = "spec.axe", uid = "r2" })

		local function rowFor(rows, id)
			for _, row in rows do
				if row.id == id then
					return row
				end
			end
			return nil
		end

		it("has no deltas when nothing is equipped", function()
			for _, row in InventoryViewModel.statRows(blade, nil) do
				expect(row.delta).never.to.be.ok()
			end
		end)

		it("reports the gain and the loss against the equipped item", function()
			-- blade: strength 7, rotEndurance 3. axe: strength 10, no rotEndurance.
			local rows = InventoryViewModel.statRows(blade, axeItem)
			expect(rowFor(rows, "strength").delta).to.equal(-3)
			expect(rowFor(rows, "rotEndurance").delta).to.equal(3)
		end)

		it("includes a stat only the EQUIPPED item has, so a swap's cost is visible", function()
			-- axe has no rotEndurance; equipping it from blade would lose 3.
			local rows = InventoryViewModel.statRows(axeItem, blade)
			local lost = rowFor(rows, "rotEndurance")
			expect(lost).to.be.ok()
			expect(lost.value).to.equal(0)
			expect(lost.delta).to.equal(-3)
		end)

		it("does not compare an equipped item against itself", function()
			for _, row in InventoryViewModel.statRows(blade, blade) do
				expect(row.delta).never.to.be.ok()
			end
		end)
	end)

	describe("stackMax", function()
		it("carries the stack ceiling for a stackable kind", function()
			expect(InventoryViewModel.toDisplay(potion).stackMax).to.equal(20)
			expect(InventoryViewModel.toDisplay(junk).stackMax).to.equal(99)
		end)

		it("is nil for gear, which is unique and does not stack", function()
			expect(InventoryViewModel.toDisplay(sword).stackMax).never.to.be.ok()
			expect(InventoryViewModel.toDisplay(helm).stackMax).never.to.be.ok()
		end)
	end)

	describe("equipped", function()
		it("resolves each occupied slot to its item, keyed by slot", function()
			local resolved = InventoryViewModel.equipped({
				slots = { weapon = sword, helmet = helm },
			})
			expect(resolved.weapon.name).to.equal("Iron Sword")
			expect(resolved.helmet.name).to.equal("Cloth Cap")
		end)

		it("leaves an empty equipment map empty", function()
			local resolved = InventoryViewModel.equipped({ slots = {} })
			expect(next(resolved)).never.to.be.ok()
		end)

		it("drops a slot whose item type no longer resolves, rather than erroring", function()
			local resolved = InventoryViewModel.equipped({
				slots = { weapon = { itemType = "spec.ghost", uid = "g1" }, helmet = helm },
			})
			expect(resolved.weapon).never.to.be.ok()
			expect(resolved.helmet).to.be.ok()
		end)
	end)

	describe("nextSort", function()
		it("flips direction when the ACTIVE mode is picked again", function()
			local mode, ascending = InventoryViewModel.nextSort("rarity", true, "rarity")
			expect(mode).to.equal("rarity")
			expect(ascending).to.equal(false)
		end)

		it("flips back on a second pick of the active mode", function()
			local mode, ascending = InventoryViewModel.nextSort("rarity", false, "rarity")
			expect(mode).to.equal("rarity")
			expect(ascending).to.equal(true)
		end)

		it("switches mode and KEEPS the direction when another mode is picked", function()
			-- The easy thing to get backwards: switching must not also flip.
			local mode, ascending = InventoryViewModel.nextSort("rarity", false, "alphabetical")
			expect(mode).to.equal("alphabetical")
			expect(ascending).to.equal(false)
		end)

		it("keeps an ascending direction across a switch too", function()
			local mode, ascending = InventoryViewModel.nextSort("alphabetical", true, "stats")
			expect(mode).to.equal("stats")
			expect(ascending).to.equal(true)
		end)
	end)

	describe("containerId", function()
		-- The Bank shows two containers at once. A stackable's key is its itemType, so the same potion in
		-- both would carry the SAME key — two different holdings claiming one identity, which the shared
		-- detail card and the drag both resolve BY key.
		it("qualifies a stack's key with the container, so two containers cannot collide", function()
			local bag = InventoryViewModel.toDisplay(potion, "bag")
			local bank = InventoryViewModel.toDisplay(potion, "bank")
			expect(bag.key).never.to.equal(bank.key)
			expect(bag.containerId).to.equal("bag")
			expect(bank.containerId).to.equal("bank")
		end)

		it("qualifies a unique's key too, so a moved item is not mistaken for the same slot", function()
			local bag = InventoryViewModel.toDisplay(sword, "bag")
			local bank = InventoryViewModel.toDisplay(sword, "bank")
			expect(bag.key).never.to.equal(bank.key)
		end)

		it("leaves the key UNqualified when no container is given", function()
			-- The single-container case, and the reason `equipped` passes nothing: the inventory's grid
			-- and paperdoll must match the same equipped item by key.
			local d = InventoryViewModel.toDisplay(potion)
			expect(d.key).to.equal("spec.potion")
			expect(d.containerId).never.to.be.ok()
		end)

		it("keeps the raw itemType and uid intact, so actions still address the item", function()
			local d = InventoryViewModel.toDisplay(sword, "bank")
			expect(d.itemType).to.equal(sword.itemType)
			expect(d.uid).to.equal(sword.uid)
		end)

		it("stamps the container through build", function()
			local items = InventoryViewModel.build(
				{ potion },
				{ sort = "alphabetical", ascending = true, containerId = "bank" }
			)
			expect(#items).to.equal(1)
			expect(items[1].containerId).to.equal("bank")
			-- Container-qualified AND ordinal-qualified: `build` numbers stacks so two stacks of one
			-- itemType stay distinct (see the "stacks" tests below).
			expect(items[1].key).to.equal("bank:spec.potion#1")
		end)
	end)

	describe("stacks of the same itemType", function()
		-- A container legitimately holds more than one stack of an itemType once the first fills up, so
		-- the itemType alone is NOT an identity within a container. Keyed by itemType, the grid wrote
		-- every such stack into the same dictionary cell: one slot rendered, the rest silently dropped.
		it("gives each stack of one itemType a distinct key", function()
			local threeStacks = {
				{ itemType = "spec.potion", quantity = 20 },
				{ itemType = "spec.potion", quantity = 20 },
				{ itemType = "spec.potion", quantity = 5 },
			}
			local items = InventoryViewModel.build(threeStacks, { sort = "alphabetical", ascending = true })
			expect(#items).to.equal(3)
			local seen = {}
			for _, item in items do
				expect(seen[item.key]).never.to.be.ok()
				seen[item.key] = true
			end
		end)

		it("keeps each stack addressable by its raw itemType and quantity", function()
			local twoStacks = {
				{ itemType = "spec.potion", quantity = 20 },
				{ itemType = "spec.potion", quantity = 5 },
			}
			local items = InventoryViewModel.build(twoStacks, { sort = "alphabetical", ascending = true })
			expect(items[1].itemType).to.equal("spec.potion")
			expect(items[2].itemType).to.equal("spec.potion")
			-- Both stacks survive, with their own counts, rather than collapsing to one.
			expect(items[1].quantity + items[2].quantity).to.equal(25)
		end)

		it("leaves a UNIQUE keyed by its uid, unaffected by the ordinal", function()
			-- Uniques must keep matching the paperdoll by key, which the ordinal must never disturb.
			local items = InventoryViewModel.build({ sword }, { sort = "alphabetical", ascending = true })
			expect(items[1].key).to.equal(sword.uid)
		end)
	end)

	describe("build", function()
		it("is empty for no entries", function()
			expect(#InventoryViewModel.build({}, { sort = "alphabetical", ascending = true })).to.equal(0)
		end)

		it("maps and alphabetically sorts all entries", function()
			local n = names(InventoryViewModel.build(all, { sort = "alphabetical", ascending = true }))
			expect(n[1]).to.equal("Battle Axe")
			expect(n[2]).to.equal("Cloth Cap")
			expect(n[3]).to.equal("Health Potion")
			expect(n[4]).to.equal("Iron Sword")
			expect(n[5]).to.equal("Old Rag")
		end)

		it("filters by category (kind)", function()
			local r = InventoryViewModel.build(all, { category = "weapon", sort = "alphabetical", ascending = true })
			expect(#r).to.equal(2)
			expect(r[1].name).to.equal("Battle Axe")
			expect(r[2].name).to.equal("Iron Sword")
		end)

		it("searches by name, case-insensitive", function()
			local r = InventoryViewModel.build(all, { search = "AXE", sort = "alphabetical", ascending = true })
			expect(#r).to.equal(1)
			expect(r[1].name).to.equal("Battle Axe")
		end)

		it("sorts by rarity rank ascending, name as tie-break", function()
			-- common(Cloth Cap, Old Rag) < uncommon(Health Potion) < rare(Iron Sword) < legendary(Battle Axe)
			local n = names(InventoryViewModel.build(all, { sort = "rarity", ascending = true }))
			expect(n[1]).to.equal("Cloth Cap")
			expect(n[2]).to.equal("Old Rag")
			expect(n[3]).to.equal("Health Potion")
			expect(n[4]).to.equal("Iron Sword")
			expect(n[5]).to.equal("Battle Axe")
		end)

		it("sorts by stat total ascending, name as tie-break", function()
			-- 0(Health Potion, Old Rag) < 2(Cloth Cap) < 5(Iron Sword) < 10(Battle Axe)
			local n = names(InventoryViewModel.build(all, { sort = "stats", ascending = true }))
			expect(n[1]).to.equal("Health Potion")
			expect(n[2]).to.equal("Old Rag")
			expect(n[3]).to.equal("Cloth Cap")
			expect(n[4]).to.equal("Iron Sword")
			expect(n[5]).to.equal("Battle Axe")
		end)

		it("reverses order when ascending is false", function()
			local asc = names(InventoryViewModel.build(all, { sort = "alphabetical", ascending = true }))
			local desc = names(InventoryViewModel.build(all, { sort = "alphabetical", ascending = false }))
			expect(desc[1]).to.equal(asc[5])
			expect(desc[5]).to.equal(asc[1])
		end)
	end)
end
