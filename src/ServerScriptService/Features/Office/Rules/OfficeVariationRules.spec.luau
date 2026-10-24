local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeVariationRules = require(script.Parent.OfficeVariationRules)
local OfficeAnomalyConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeAnomalyConstants)

local function has(list, value)
	return table.find(list, value) ~= nil
end

return function()
	describe("nil seed", function()
		it("returns the authored / neutral values", function()
			expect(OfficeVariationRules.keepProp(nil, "m", "deskPlant")).to.equal(true)
			expect(OfficeVariationRules.lightMood(nil, "r", "pods")).to.equal("normal")
			expect(OfficeVariationRules.doorStartsOpen(nil, "d")).to.equal(false)
			expect(next(OfficeVariationRules.dressing(nil, { "a", "b" }))).to.equal(nil)
			expect(#OfficeVariationRules.anomalies(nil)).to.equal(0)
		end)

		it("keeps the existing desk parity rule", function()
			local odd = OfficeVariationRules.deskClutter(nil, "pods1.desk.1")
			expect(table.concat(odd, ",")).to.equal("mug,stationeryCup,folder,paperTray")
			local even = OfficeVariationRules.deskClutter(nil, "pods1.desk.2")
			expect(table.concat(even, ",")).to.equal("mug,stationeryCup,paperStack,bookStack")
		end)
	end)

	describe("keepProp", function()
		it("always keeps arts without a chance", function()
			for seed = 1, 100 do
				expect(OfficeVariationRules.keepProp(seed, "m" .. seed, "column")).to.equal(true)
			end
		end)

		it("keeps about 60% of desk plants", function()
			local kept = 0
			for seed = 1, 1000 do
				if OfficeVariationRules.keepProp(seed, "m", "deskPlant") then
					kept += 1
				end
			end
			expect(math.abs(kept / 1000 - 0.6) < 0.06).to.equal(true)
		end)
	end)

	describe("deskClutter", function()
		it("never holds both folder and paperStack", function()
			for seed = 1, 500 do
				local items = OfficeVariationRules.deskClutter(seed, "r.desk." .. seed)
				expect(has(items, "folder") and has(items, "paperStack")).to.equal(false)
			end
		end)
	end)

	describe("lightMood", function()
		it("keeps halls, storage, server and reception normal", function()
			for seed = 1, 300 do
				expect(OfficeVariationRules.lightMood(seed, "h" .. seed, nil)).to.equal("normal")
				for _, roomType in { "storage", "server", "reception" } do
					expect(OfficeVariationRules.lightMood(seed, "r" .. seed, roomType)).to.equal("normal")
				end
			end
		end)

		it("gives pods all three moods", function()
			local seen = {}
			for seed = 1, 300 do
				seen[OfficeVariationRules.lightMood(seed, "pods1", "pods")] = true
			end
			expect(seen.normal and seen.dim and seen.dark).to.equal(true)
		end)
	end)

	describe("doorStartsOpen and dressing", function()
		it("opens about 30% of doors", function()
			local open = 0
			for seed = 1, 1000 do
				if OfficeVariationRules.doorStartsOpen(seed, "a|b") then
					open += 1
				end
			end
			expect(math.abs(open / 1000 - 0.3) < 0.05).to.equal(true)
		end)

		it("dresses about 20% stain and 20% paper", function()
			local ids = {}
			for i = 1, 1000 do
				ids[i] = "m" .. i
			end
			local stain, paper = 0, 0
			for _, kind in OfficeVariationRules.dressing(7, ids) do
				if kind == "stain" then
					stain += 1
				else
					paper += 1
				end
			end
			expect(math.abs(stain / 1000 - 0.2) < 0.05).to.equal(true)
			expect(math.abs(paper / 1000 - 0.2) < 0.05).to.equal(true)
		end)
	end)

	describe("anomalies", function()
		it("splits 1/2 near 65/35, never repeats, and covers every id", function()
			local ones, seen = 0, {}
			for seed = 1, 2000 do
				local list = OfficeVariationRules.anomalies(seed)
				expect(#list == 1 or #list == 2).to.equal(true)
				if #list == 1 then
					ones += 1
				else
					expect(list[1]).never.to.equal(list[2])
				end
				for _, id in list do
					expect(has(OfficeAnomalyConstants.IDS, id)).to.equal(true)
					seen[id] = true
				end
			end
			expect(math.abs(ones / 2000 - 0.65) < 0.05).to.equal(true)
			for _, id in OfficeAnomalyConstants.IDS do
				expect(seen[id]).to.equal(true)
			end
		end)
	end)
end
