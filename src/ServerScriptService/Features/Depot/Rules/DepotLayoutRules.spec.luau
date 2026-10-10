local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotLayoutRules = require(script.Parent.DepotLayoutRules)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)

-- A small valid depot: three trucks along the back, boards at the front, spawns between them.
local function fixture()
	return {
		floor = { minX = 0, minZ = 0, maxX = 96, maxZ = 72 },
		trucks = {
			{ id = "t1", x = 20, z = 48, capacity = 4, countdown = 15 },
			{ id = "t2", x = 48, z = 48, capacity = 2, countdown = 10 },
			{ id = "t3", x = 76, z = 48, capacity = 1, countdown = 30 },
		},
		contractBoard = { x = 34, z = 12 },
		resultBoard = { x = 62, z = 12 },
		spawns = { { x = 40, z = 26 }, { x = 56, z = 26 } },
	}
end

local function hasError(errors, fragment)
	for _, message in errors do
		if string.find(message, fragment, 1, true) then
			return true
		end
	end
	return false
end

return function()
	describe("the authored depot", function()
		it("is valid", function()
			local ok, errors = DepotLayoutRules.validate(DepotLayoutConstants.LAYOUT)
			if not ok then
				error(table.concat(errors, "\n"))
			end
			expect(ok).to.equal(true)
		end)

		it("has a placeholder-or-real whole PlaceId for both roles", function()
			for _, role in { DepotConstants.ROLE_DEPOT, DepotConstants.ROLE_SHIFT } do
				local placeId = DepotConstants.PLACE_IDS[role]
				expect(type(placeId)).to.equal("number")
				expect(placeId >= 0 and placeId == math.floor(placeId)).to.equal(true)
			end
		end)
	end)

	describe("validate", function()
		it("accepts a small valid depot", function()
			local ok, errors = DepotLayoutRules.validate(fixture())
			expect(#errors).to.equal(0)
			expect(ok).to.equal(true)
		end)

		it("refuses a floor with no area", function()
			local layout = fixture()
			layout.floor.maxX = 0
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, "no area")).to.equal(true)
		end)

		it("needs three or four trucks", function()
			local layout = fixture()
			table.remove(layout.trucks)
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, "2 trucks")).to.equal(true)
		end)

		it("refuses a duplicate or empty truck id", function()
			local layout = fixture()
			layout.trucks[2].id = "t1"
			layout.trucks[3].id = ""
			local _, errors = DepotLayoutRules.validate(layout)
			expect(hasError(errors, 'truck "t1" is defined twice')).to.equal(true)
			expect(hasError(errors, "a truck has no id")).to.equal(true)
		end)

		it("refuses a capacity outside 1-4 or not whole", function()
			for _, bad in { 0, 5, 2.5 } do
				local layout = fixture()
				layout.trucks[1].capacity = bad
				local ok, errors = DepotLayoutRules.validate(layout)
				expect(ok).to.equal(false)
				expect(hasError(errors, 'truck "t1": capacity')).to.equal(true)
			end
		end)

		it("refuses a countdown outside 5-60 seconds", function()
			for _, bad in { 0, 4, 61 } do
				local layout = fixture()
				layout.trucks[2].countdown = bad
				local ok, errors = DepotLayoutRules.validate(layout)
				expect(ok).to.equal(false)
				expect(hasError(errors, 'truck "t2": countdown')).to.equal(true)
			end
		end)

		it("refuses a truck whose bed or cab leaves the floor", function()
			local layout = fixture()
			layout.trucks[1].z = 66
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, 'truck "t1" is not inside the floor')).to.equal(true)
		end)

		it("refuses trucks parked too close together", function()
			local layout = fixture()
			layout.trucks[2].x = 30
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, 'trucks "t1" and "t2"')).to.equal(true)
		end)

		it("refuses a board outside the floor or standing on a truck", function()
			local layout = fixture()
			layout.contractBoard = { x = 20, z = 48 }
			layout.resultBoard = { x = 200, z = 12 }
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, 'the contract board stands on truck "t1"')).to.equal(true)
			expect(hasError(errors, "the result board is not inside the floor")).to.equal(true)
		end)

		it("refuses two boards on top of each other", function()
			local layout = fixture()
			layout.resultBoard = { x = 36, z = 12 }
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, "boards overlap")).to.equal(true)
		end)

		it("refuses a spawn on or beside a truck bed, so nobody spawns into a queue", function()
			local layout = fixture()
			layout.spawns[1] = { x = 20, z = 38 }
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, "spawn 1 is within")).to.equal(true)
			expect(hasError(errors, 'of truck "t1"')).to.equal(true)
		end)

		it("needs a spawn, inside the floor", function()
			local none = fixture()
			none.spawns = {}
			local _, noneErrors = DepotLayoutRules.validate(none)
			expect(hasError(noneErrors, "no spawn points")).to.equal(true)
			local outside = fixture()
			outside.spawns = { { x = -5, z = 10 } }
			local _, outsideErrors = DepotLayoutRules.validate(outside)
			expect(hasError(outsideErrors, "spawn 1 is not inside the floor")).to.equal(true)
		end)

		it("lists every problem at once", function()
			local layout = fixture()
			layout.trucks[1].capacity = 9
			layout.spawns = {}
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(#errors >= 2).to.equal(true)
		end)
	end)
end
