local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeSpawnUtils = require(script.Parent.OfficeSpawnUtils)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)
local OfficeLayoutGenerationUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutGenerationUtils)
local OfficeLayoutUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutUtils)
local OfficeSpawnRules = require(ServerScriptService.Features.Office.Rules.OfficeSpawnRules)
local OfficeLootUtils = require(ServerScriptService.Features.Office.Utils.OfficeLootUtils)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoAppraisalFormulas = require(ReplicatedStorage.Shared.Features.Cargo.Utils.CargoAppraisalFormulas)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

local LAYOUT = OfficeLayoutConstants.LAYOUT
-- The biggest crew's quota: every roll on a generated office (what a shift plays) must be able to meet it. The authored
-- base layout is two rooms deep and never played as is; its rolls are checked for placement with no quota.
local QUOTA = ShiftConstants.QUOTA_BY_CREW[#ShiftConstants.QUOTA_BY_CREW]

local function options(variant, quota)
	return {
		quota = quota or 0,
		variant = variant,
		piles = OfficeConstants.PILES,
		valuables = OfficeConstants.VALUABLES,
	}
end

-- Every valuable in a plan with its marker id and appraisal: open, buried and in desks.
local function valuablesOf(plan)
	local list = {}
	local function add(kind, marker, appraisal)
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		if def ~= nil and def.grimy then
			table.insert(list, { kind = kind, marker = marker, appraisal = appraisal, def = def })
		end
	end
	for _, item in plan.items do
		add(item.kind, item.marker, item.appraisal)
	end
	for _, pile in plan.piles do
		add(pile.hides, pile.marker, pile.appraisal)
	end
	for _, search in plan.searchables do
		add(search.kind, search.marker, search.appraisal)
	end
	return list
end

local function roll(seed, variant)
	return OfficeSpawnUtils.roll(LAYOUT, options(variant or "B"), Random.new(seed))
end

return function()
	it("meets every guarantee on the base layout without a quota, for fifty seeds in both variants", function()
		for seed = 1, 50 do
			for _, variant in { "A", "B" } do
				local ok, reason = OfficeSpawnRules.check(roll(seed, variant), LAYOUT, 0)
				if not ok then
					error(`seed {seed} variant {variant}: {reason}`)
				end
			end
		end
	end)

	it("meets every guarantee, the biggest crew's quota included, on generated offices", function()
		for seed = 1, 30 do
			if seed % 5 == 0 then
				task.wait()
			end
			local layout = OfficeLayoutGenerationUtils.generate(LAYOUT, seed)
			local plan = OfficeSpawnUtils.roll(layout, options("B", QUOTA), Random.new(seed))
			local ok, reason = OfficeSpawnRules.check(plan, layout, QUOTA)
			if not ok then
				error(`seed {seed}: {reason}`)
			end
		end
	end)

	it("keeps at most DESK_VALUABLES_MAX valuables in desks, besides a desk greed target", function()
		for seed = 1, 20 do
			local layout = OfficeLayoutGenerationUtils.generate(LAYOUT, seed)
			local plan = OfficeSpawnUtils.roll(layout, options("B"), Random.new(seed))
			local count = 0
			for _, search in plan.searchables do
				if search.appraisal ~= nil and search.kind ~= "goldenStapler" then
					count += 1
				end
			end
			expect(count <= OfficeConstants.DESK_VALUABLES_MAX).to.equal(true)
		end
	end)

	it("rolls the same plan for the same seed", function()
		local first = roll(7)
		local second = roll(7)
		expect(#first.piles).to.equal(#second.piles)
		expect(#first.items).to.equal(#second.items)
		for index, pile in first.piles do
			expect(pile.marker).to.equal(second.piles[index].marker)
			expect(pile.kind).to.equal(second.piles[index].kind)
			expect(pile.hides).to.equal(second.piles[index].hides)
		end
		for index, item in first.items do
			expect(item.marker).to.equal(second.items[index].marker)
			expect(item.kind).to.equal(second.items[index].kind)
		end
		expect(first.greed.kind).to.equal(second.greed.kind)
	end)

	it("rolls a pile count inside the configured range", function()
		for seed = 1, 20 do
			local count = #roll(seed).piles
			expect(count >= OfficeConstants.PILES.min and count <= OfficeConstants.PILES.max).to.equal(true)
		end
	end)

	it("buries loot in both variants, the same way (the variant no longer changes the roll)", function()
		for seed = 1, 20 do
			local a, b = roll(seed, "A"), roll(seed, "B")
			for index, pile in a.piles do
				expect(pile.hides).to.equal(b.piles[index].hides)
			end
		end
	end)

	it("buries a valuable under roughly a third of the piles, only buriable kinds or the stapler", function()
		local piles, buried = 0, 0
		for seed = 1, 60 do
			for _, pile in roll(seed).piles do
				piles += 1
				if pile.hides ~= nil then
					buried += 1
					local def = CargoRegistry.get(pile.hides)
					expect(def.buriable or def.id == "goldenStapler").to.equal(true)
					expect(pile.appraisal ~= nil).to.equal(true)
				end
			end
		end
		local share = buried / piles
		expect(share > 0.2 and share < 0.42).to.equal(true)
	end)

	it("offers 10-14 valuables, a few more when topped up, and puts no trash on the open floor", function()
		for seed = 1, 50 do
			local plan = roll(seed)
			local count = #valuablesOf(plan)
			expect(count >= OfficeConstants.VALUABLES.min).to.equal(true)
			expect(count <= OfficeConstants.VALUABLES.max + OfficeConstants.TOP_UP_MAX).to.equal(true)
			for _, item in plan.items do
				expect(CargoRegistry.get(item.kind).category).to.equal("salvage")
			end
		end
	end)

	it("appraises every valuable inside its range scaled by depth (and jackpot), and no trash", function()
		local depths = OfficeLayoutUtils.depths(LAYOUT)
		for seed = 1, 30 do
			local plan = roll(seed)
			for _, entry in valuablesOf(plan) do
				local appraisal = entry.appraisal
				expect(appraisal ~= nil).to.equal(true)
				local marker = OfficeLayoutUtils.marker(LAYOUT, entry.marker)
				local scale = CargoAppraisalFormulas.depthMultiplier(depths[marker.room] or 0)
				local jackpot = if appraisal.variant ~= nil then entry.def.jackpot.multiplier else 1
				expect(appraisal.base >= math.floor(entry.def.valueMin * scale * jackpot)).to.equal(true)
				expect(appraisal.base <= math.ceil(entry.def.valueMax * scale * jackpot)).to.equal(true)
			end
			for _, search in plan.searchables do
				if search.kind ~= nil and not CargoRegistry.get(search.kind).grimy then
					expect(search.appraisal).to.equal(nil)
				end
			end
		end
	end)

	it("pays more for valuables found deeper (generated offices)", function()
		local shallow, shallowCount, deep, deepCount = 0, 0, 0, 0
		for seed = 1, 30 do
			local layout = OfficeLayoutGenerationUtils.generate(LAYOUT, seed)
			local depths = OfficeLayoutUtils.depths(layout)
			for _, entry in valuablesOf(OfficeSpawnUtils.roll(layout, options("B"), Random.new(seed))) do
				local marker = OfficeLayoutUtils.marker(layout, entry.marker)
				local depth = depths[marker.room] or 0
				local ratio = entry.appraisal.base / entry.def.value
				if depth <= 1 then
					shallow += ratio
					shallowCount += 1
				elseif depth >= 3 then
					deep += ratio
					deepCount += 1
				end
			end
		end
		expect(shallowCount > 0 and deepCount > 0).to.equal(true)
		expect(deep / deepCount > shallow / shallowCount).to.equal(true)
	end)

	it("offers the same salvage for the same seed in both variants (only where it sits differs)", function()
		local function salvageOf(plan)
			local kinds = {}
			for _, item in plan.items do
				if CargoRegistry.get(item.kind).category == "salvage" then
					table.insert(kinds, item.kind)
				end
			end
			for _, pile in plan.piles do
				if pile.hides ~= nil then
					table.insert(kinds, pile.hides)
				end
			end
			table.sort(kinds)
			return table.concat(kinds, ",")
		end
		for seed = 1, 30 do
			local a = roll(seed, "A")
			local b = roll(seed, "B")
			expect(salvageOf(a)).to.equal(salvageOf(b))
			expect(#a.piles).to.equal(#b.piles)
			expect(a.greed.kind).to.equal(b.greed.kind)
		end
	end)

	it("keeps a hidden greed target out of the open", function()
		for seed = 1, 50 do
			local plan = roll(seed)
			for _, item in plan.items do
				expect(CargoRegistry.get(item.kind).hidden).to.equal(false)
			end
			if plan.greed.kind == "goldenStapler" then
				local marker = plan.greed.marker
				local inDesk = string.find(marker, ".desk.", 1, true) ~= nil
				local inLocker = string.find(marker, ".locker.", 1, true) ~= nil
				local underPile = string.find(marker, ".pile.", 1, true) ~= nil
				expect(inDesk or inLocker or underPile).to.equal(true)
			end
		end
	end)

	it("reports the value it rolled", function()
		for seed = 1, 30 do
			local plan = roll(seed)
			expect(plan.value).to.equal(OfficeLootUtils.valueOf(plan).full)
		end
	end)

	it("tops a poor map up with open valuables for a big quota, at most TOP_UP_MAX", function()
		for seed = 1, 20 do
			local plain = roll(seed)
			local topped = OfficeSpawnUtils.roll(LAYOUT, options("B", QUOTA), Random.new(seed))
			local extra = #topped.items - #plain.items
			expect(extra >= 0 and extra <= OfficeConstants.TOP_UP_MAX).to.equal(true)
			if not OfficeLootUtils.shortfall(plain, QUOTA) then
				expect(extra).to.equal(0)
			end
		end
	end)

	it("lists every desk and locker, empty or not", function()
		expect(#roll(3).searchables).to.equal(12)
	end)

	describe("counter surfaces", function()
		local APPLIANCES = { coffeeMachine = true, waterJug = true, fishTank = true }
		local function generated(seed, variant)
			local layout = OfficeLayoutGenerationUtils.generate(LAYOUT, seed)
			return layout, OfficeSpawnUtils.roll(layout, options(variant or "B"), Random.new(seed))
		end
		it("sits appliances on kitchen counters, at most one per counter", function()
			for seed = 1, 30 do
				local layout, plan = generated(seed)
				local ok, reason = OfficeSpawnRules.check(plan, layout, 0)
				expect(ok).to.equal(true)
				if not ok then
					error(`seed {seed}: {reason}`)
				end
				local used: { [string]: boolean } = {}
				for _, item in plan.items do
					local marker = OfficeLayoutUtils.marker(layout, item.marker)
					expect(marker ~= nil).to.equal(true)
					if marker ~= nil and marker.kind == "counter" then
						expect(used[item.marker]).to.equal(nil)
						used[item.marker] = true
						expect(APPLIANCES[item.kind]).to.equal(true)
					end
				end
			end
		end)
		it("only leaves appliances on the floor when every counter is taken", function()
			for seed = 1, 30 do
				local layout, plan = generated(seed)
				local counters = OfficeLayoutUtils.markersOf(layout, "counter")
				local used = 0
				for _, item in plan.items do
					local marker = OfficeLayoutUtils.marker(layout, item.marker)
					if marker ~= nil and marker.kind == "counter" then
						used += 1
					end
				end
				for _, item in plan.items do
					if APPLIANCES[item.kind] then
						local marker = OfficeLayoutUtils.marker(layout, item.marker)
						if marker ~= nil and marker.kind == "item" then
							expect(used).to.equal(#counters)
						end
					end
				end
			end
		end)
	end)

	describe("table and cabinet surfaces", function()
		local TABLETOP = {
			plaque = true,
			monitor = true,
			coffeeMachine = true,
			waterJug = true,
			coffeeMug = true,
			deskClock = true,
			snowGlobe = true,
			deskPhone = true,
		}
		it("sits plaques and monitors on tables and cabinets, at most one piece each", function()
			for seed = 1, 30 do
				local layout = OfficeLayoutGenerationUtils.generate(LAYOUT, seed)
				local plan = OfficeSpawnUtils.roll(layout, options("B"), Random.new(seed))
				local ok, reason = OfficeSpawnRules.check(plan, layout, 0)
				expect(ok).to.equal(true)
				if not ok then
					error(`seed {seed}: {reason}`)
				end
				local used: { [string]: boolean } = {}
				for _, item in plan.items do
					local marker = OfficeLayoutUtils.marker(layout, item.marker)
					expect(marker ~= nil).to.equal(true)
					if marker ~= nil and (marker.kind == "table" or marker.kind == "cabinet") then
						expect(used[item.marker]).to.equal(nil)
						used[item.marker] = true
						expect(TABLETOP[item.kind]).to.equal(true)
					end
				end
			end
		end)
		it("only leaves tabletop loot on the floor when its own surfaces are all taken", function()
			for seed = 1, 30 do
				local layout = OfficeLayoutGenerationUtils.generate(LAYOUT, seed)
				local plan = OfficeSpawnUtils.roll(layout, options("B"), Random.new(seed))
				local totals: { [string]: number } = {}
				local used: { [string]: number } = {}
				for _, marker in layout.markers do
					if OfficeSpawnRules.surfaceKinds()[marker.kind] ~= nil then
						totals[marker.kind] = (totals[marker.kind] or 0) + 1
					end
				end
				for _, item in plan.items do
					local marker = OfficeLayoutUtils.marker(layout, item.marker)
					if marker ~= nil and totals[marker.kind] ~= nil then
						used[marker.kind] = (used[marker.kind] or 0) + 1
					end
				end
				for _, item in plan.items do
					local kinds = OfficeSpawnRules.surfaceKindsFor(item.kind)
					if #kinds > 0 then
						local marker = OfficeLayoutUtils.marker(layout, item.marker)
						if marker ~= nil and table.find(kinds, marker.kind) == nil then
							for _, kind in kinds do
								expect(used[kind] or 0).to.equal(totals[kind])
							end
						end
					end
				end
			end
		end)
	end)

	describe("salvageCount", function()
		it("counts salvage on the floor, under piles and in desks, and nothing else", function()
			local plan = {
				items = { { marker = "a", kind = "monitor" }, { marker = "b", kind = "rubbishBag" } },
				piles = { { marker = "c", kind = "paper", hides = "plaque" }, { marker = "d", kind = "paper" } },
				searchables = { { marker = "e", kind = "goldenStapler" }, { marker = "f" } },
				value = 0,
			}
			expect(OfficeSpawnUtils.salvageCount(plan)).to.equal(3)
		end)
	end)
	it("never rolls free-floor appliances when eligible furniture is absent", function()
		local layout = table.clone(LAYOUT)
		layout.markers = {}
		for _, marker in LAYOUT.markers do
			if marker.kind ~= "counter" and marker.kind ~= "table" then
				table.insert(layout.markers, marker)
			end
		end
		for seed = 1, 50 do
			local plan = OfficeSpawnUtils.roll(layout, options("A"), Random.new(seed))
			for _, item in plan.items do
				expect(OfficeSpawnRules.requiresSurface(item.kind)).to.equal(false)
			end
		end
	end)
	it("preserves A/B rewards even with only one shared overflow table", function()
		local layout = table.clone(LAYOUT)
		layout.markers = {}
		for _, marker in LAYOUT.markers do
			if marker.kind ~= "counter" and marker.kind ~= "table" then
				table.insert(layout.markers, marker)
			end
		end
		table.insert(layout.markers, { id = "lobby.table.single", room = "lobby", kind = "table", x = 10, z = 35 })
		local function rewards(plan)
			local ids = {}
			for _, item in plan.items do
				if CargoRegistry.get(item.kind).category == "salvage" then
					table.insert(ids, item.kind)
				end
			end
			for _, pile in plan.piles do
				if pile.hides then
					table.insert(ids, pile.hides)
				end
			end
			table.sort(ids)
			return table.concat(ids, ",")
		end
		for seed = 1, 50 do
			local a = OfficeSpawnUtils.roll(layout, options("A"), Random.new(seed))
			local b = OfficeSpawnUtils.roll(layout, options("B"), Random.new(seed))
			expect(rewards(a)).to.equal(rewards(b))
		end
	end)
end
