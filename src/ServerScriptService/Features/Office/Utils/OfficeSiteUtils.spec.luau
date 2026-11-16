local ServerScriptService = game:GetService("ServerScriptService")

local OfficeSiteUtils = require(script.Parent.OfficeSiteUtils)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)
local OfficeLayoutGenerationUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutGenerationUtils)
local OfficeLayoutUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutUtils)

local LAYOUT = OfficeLayoutConstants.LAYOUT

-- A fake authored site whose every answer is recognisable.
local function fakeSite()
	return {
		model = Instance.new("Model"),
		spawnCFrame = function(index)
			return CFrame.new(index, 0, 0)
		end,
		route = function()
			return { Vector3.new(7, 0, 7) }
		end,
		restPoint = function()
			return Vector3.new(1, 2, 3)
		end,
		safeZone = function()
			return Vector3.zero, Vector3.one
		end,
		loadingBay = function()
			return Vector3.one, Vector3.one * 2
		end,
		whereIs = function()
			return "Site Room", 4, 9
		end,
		truckBed = function()
			return nil
		end,
		spawn = function()
			return { piles = {}, items = {}, searchables = {}, value = 0 }
		end,
	}
end

local function below(a, b)
	return a.X <= b.X and a.Y <= b.Y and a.Z <= b.Z
end

return function()
	describe("floorAt", function()
		it("is the floor point under the marker at the office origin", function()
			expect(OfficeSiteUtils.floorAt({ x = 3, z = -4 })).to.equal(OfficeConstants.ORIGIN * CFrame.new(3, 0, -4))
		end)
	end)

	describe("with an authored site", function()
		local site = fakeSite()

		it("answers every question from the site", function()
			expect(OfficeSiteUtils.spawnCFrame(site, LAYOUT, 2)).to.equal(CFrame.new(2, 0, 0))
			expect(OfficeSiteUtils.route(site, {})[1]).to.equal(Vector3.new(7, 0, 7))
			expect(OfficeSiteUtils.restPoint(site, nil)).to.equal(Vector3.new(1, 2, 3))
			local low, high = OfficeSiteUtils.safeZone(site, LAYOUT)
			expect(low).to.equal(Vector3.zero)
			expect(high).to.equal(Vector3.one)
			local bayLow, bayHigh = OfficeSiteUtils.loadingBay(site, LAYOUT)
			expect(bayLow).to.equal(Vector3.one)
			expect(bayHigh).to.equal(Vector3.one * 2)
			local name, depth, index = OfficeSiteUtils.whereIs(site, LAYOUT, {}, Vector3.zero)
			expect(name).to.equal("Site Room")
			expect(depth).to.equal(4)
			expect(index).to.equal(9)
		end)

		it("has no outdoors and no entrances", function()
			expect(#OfficeSiteUtils.outdoors(site, LAYOUT)).to.equal(0)
			local outside, inside = OfficeSiteUtils.entrance(site, LAYOUT, "lobby")
			expect(outside).to.equal(nil)
			expect(inside).to.equal(nil)
		end)
	end)

	describe("on the generated layout", function()
		it("copies the route points", function()
			local points = { Vector3.new(1, 0, 1), Vector3.new(2, 0, 2) }
			local route = OfficeSiteUtils.route(nil, points)
			expect(route).never.to.equal(points)
			expect(#route).to.equal(2)
			expect(route[2]).to.equal(points[2])
		end)

		it("stands the rest point on the floor at the rest marker, and errors with none", function()
			local marker = { x = 5, z = 6 }
			expect(OfficeSiteUtils.restPoint(nil, marker)).to.equal(OfficeSiteUtils.floorAt(marker).Position)
			expect(function()
				OfficeSiteUtils.restPoint(nil, nil)
			end).to.throw()
		end)

		it("gives the safe zone and the loading bay as min and max corners", function()
			local low, high = OfficeSiteUtils.safeZone(nil, LAYOUT)
			expect(below(low, high)).to.equal(true)
			local bayLow, bayHigh = OfficeSiteUtils.loadingBay(nil, LAYOUT)
			expect(bayLow).to.be.ok()
			expect(bayHigh).to.be.ok()
		end)

		it("names the room a point stands in, with its depth and index", function()
			local depths = OfficeLayoutUtils.depths(LAYOUT)
			local room = LAYOUT.rooms[1]
			local x, z = (room.minX + room.maxX) / 2, (room.minZ + room.maxZ) / 2
			local expected, expectedIndex = OfficeLayoutUtils.roomAt(LAYOUT, x, z)
			local point = OfficeConstants.ORIGIN:PointToWorldSpace(Vector3.new(x, 1, z))
			local name, depth, index = OfficeSiteUtils.whereIs(nil, LAYOUT, depths, point)
			expect(name).to.equal(expected.name)
			expect(depth).to.equal(depths[expected.id])
			expect(index).to.equal(expectedIndex)
		end)

		it("has no outdoors on the authored layout (no grounds)", function()
			expect(#OfficeSiteUtils.outdoors(nil, LAYOUT)).to.equal(0)
		end)

		it("gives one box per ground, and frames for every entrance, on a generated office", function()
			local layout = OfficeLayoutGenerationUtils.generate(LAYOUT, 4)
			local grounds = layout.grounds or {}
			local boxes = OfficeSiteUtils.outdoors(nil, layout)
			expect(#boxes).to.equal(#grounds)
			for _, box in boxes do
				expect(below(box.min, box.max)).to.equal(true)
			end
			for _, entrance in layout.entrances or {} do
				if OfficeLayoutUtils.room(layout, entrance.exit.a) ~= nil then
					local outside, inside = OfficeSiteUtils.entrance(nil, layout, entrance.id)
					expect(outside).to.be.ok()
					expect(inside).to.be.ok()
				end
			end
			local outside, inside = OfficeSiteUtils.entrance(nil, layout, "no-such-entrance")
			expect(outside).to.equal(nil)
			expect(inside).to.equal(nil)
		end)
	end)
end
