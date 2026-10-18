local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeLightUtils = require(script.Parent.OfficeLightUtils)
local OfficeAtmosphereConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants)

local function grid()
	local positions = {}
	for x = 0, 120, 15 do
		for z = 0, 90, 15 do
			table.insert(positions, Vector3.new(1000 + x, 11.5, z))
		end
	end
	return positions
end

return function()
	describe("hash", function()
		it("is stable per light and within 0..1", function()
			for _, position in grid() do
				local value = OfficeLightUtils.hash(position)
				expect(value >= 0 and value < 1).to.equal(true)
				expect(OfficeLightUtils.hash(position)).to.equal(value)
			end
		end)
	end)

	describe("broken", function()
		it("breaks none at 0 and all at 1", function()
			for _, position in grid() do
				expect(OfficeLightUtils.broken(position, 0)).to.equal(false)
				expect(OfficeLightUtils.broken(position, 1)).to.equal(true)
			end
		end)

		it("breaks some but not most of a real grid at the tuned fraction", function()
			local count, total = 0, 0
			for _, position in grid() do
				total += 1
				if OfficeLightUtils.broken(position, OfficeAtmosphereConstants.BROKEN_FRACTION) then
					count += 1
				end
			end
			expect(count >= 1).to.equal(true)
			expect(count < total / 2).to.equal(true)
		end)
	end)

	describe("nearbyBroken", function()
		it("selects only broken lights within the radius", function()
			local positions = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(500, 0, 0) }
			local all = OfficeLightUtils.nearbyBroken(positions, Vector3.zero, 50, 1)
			expect(#all).to.equal(2)
			expect(all[1]).to.equal(1)
			expect(all[2]).to.equal(2)
			expect(#OfficeLightUtils.nearbyBroken(positions, Vector3.zero, 50, 0)).to.equal(0)
		end)
	end)

	describe("glow", function()
		it("is either full or dimmed, and blinks dim now and then", function()
			local dims, fulls = 0, 0
			for step = 0, 600 do
				local value = OfficeLightUtils.glow(step * 0.05, 3.7)
				if value == 1 then
					fulls += 1
				elseif value == OfficeAtmosphereConstants.BROKEN_DIM then
					dims += 1
				end
			end
			expect(dims + fulls).to.equal(601)
			expect(dims >= 1).to.equal(true)
			expect(fulls > dims).to.equal(true)
		end)
	end)
end
