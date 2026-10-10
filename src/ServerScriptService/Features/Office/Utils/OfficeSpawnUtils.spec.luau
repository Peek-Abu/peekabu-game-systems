local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeSpawnUtils = require(script.Parent.OfficeSpawnUtils)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)
local OfficeSpawnRules = require(ServerScriptService.Features.Office.Rules.OfficeSpawnRules)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

local LAYOUT = OfficeLayoutConstants.LAYOUT
local QUOTA = 350

local function options(variant)
	return { quota = QUOTA, variant = variant, piles = OfficeConstants.PILES, salvage = OfficeConstants.SALVAGE }
end

local function roll(seed, variant)
	return OfficeSpawnUtils.roll(LAYOUT, options(variant or "B"), Random.new(seed))
end

return function()
	it("meets every guarantee for fifty seeds in both variants", function()
		for seed = 1, 50 do
			for _, variant in { "A", "B" } do
				local ok, reason = OfficeSpawnRules.check(roll(seed, variant), LAYOUT, QUOTA)
				if not ok then
					error(`seed {seed} variant {variant}: {reason}`)
				end
			end
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

	it("hides nothing under piles in variant A", function()
		for seed = 1, 20 do
			for _, pile in roll(seed, "A").piles do
				expect(pile.hides).to.equal(nil)
			end
		end
	end)

	it("hides some salvage under piles in variant B", function()
		local hidden = 0
		for seed = 1, 20 do
			for _, pile in roll(seed, "B").piles do
				if pile.hides ~= nil then
					hidden += 1
				end
			end
		end
		expect(hidden > 0).to.equal(true)
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

	it("reports the trash total it rolled, counting canister output", function()
		for seed = 1, 10 do
			local plan = roll(seed)
			expect(plan.trashValue).to.equal(OfficeSpawnRules.trashValue(plan))
			expect(plan.trashValue >= QUOTA * OfficeConstants.TRASH_FACTOR).to.equal(true)
		end
	end)

	it("lists every desk and locker, empty or not", function()
		expect(#roll(3).searchables).to.equal(12)
	end)
end
