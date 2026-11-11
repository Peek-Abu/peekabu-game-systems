local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotMapRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotMapRules)
local OccupantRosterRegistry = require(script.Parent.OccupantRosterRegistry)
local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)

return function()
	describe("the rosters", function()
		it("runs the monster each map's run words are about (DepotMapRules.siteOf's monster)", function()
			for _, map in { "office", "school" } do
				local kinds = {}
				for _, entry in OccupantRosterRegistry.get(map).entries do
					kinds[entry.kind] = true
				end
				expect(kinds[DepotMapRules.siteOf(map).monster]).to.equal(true)
			end
		end)

		it("puts Harlow alone in the Office", function()
			local office = OccupantRosterRegistry.get("office")
			expect(#office.entries).to.equal(1)
			expect(office.entries[1].kind).to.equal("harlow")
			expect(office.entries[1].weight).to.equal(1)
		end)

		it("puts Bramble alone in the School", function()
			local school = OccupantRosterRegistry.get("school")
			expect(#school.entries).to.equal(1)
			expect(school.entries[1].kind).to.equal("bramble")
			expect(school.entries[1].weight).to.equal(1)
		end)

		it("allows one monster per shift at launch", function()
			for _, mapId in OccupantRosterRegistry.mapIds() do
				expect(OccupantRosterRegistry.get(mapId).budget).to.equal(1)
			end
		end)

		it("has no roster for an unknown map", function()
			expect(OccupantRosterRegistry.get("moon")).to.equal(nil)
		end)

		it("lists its maps, sorted", function()
			local ids = OccupantRosterRegistry.mapIds()
			expect(#ids).to.equal(2)
			expect(ids[1]).to.equal("office")
			expect(ids[2]).to.equal("school")
		end)

		it("names only registered kinds, each with a positive weight", function()
			for _, mapId in OccupantRosterRegistry.mapIds() do
				for _, entry in OccupantRosterRegistry.get(mapId).entries do
					expect(OccupantKindRegistry.has(entry.kind)).to.equal(true)
					expect(entry.weight > 0).to.equal(true)
				end
			end
		end)
	end)
end
