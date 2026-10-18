local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeAtmosphereUtils = require(script.Parent.OfficeAtmosphereUtils)
local OfficeAtmosphereConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants)

local function snapshot(overrides)
	local base = { phase = "running", sub = "normal", stage = "normal", tier = 0, quotaMet = false }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	describe("preset", function()
		it("keeps the place's own lighting outside a shift", function()
			expect(OfficeAtmosphereUtils.preset(nil)).to.equal(nil)
			expect(OfficeAtmosphereUtils.preset(snapshot({ phase = "lobby" }))).to.equal(nil)
		end)

		it("is night from the arrival countdown through the results", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ phase = "starting" }))).to.equal(
				OfficeAtmosphereConstants.NIGHT
			)
			expect(OfficeAtmosphereUtils.preset(snapshot())).to.equal(OfficeAtmosphereConstants.NIGHT)
			expect(OfficeAtmosphereUtils.preset(snapshot({ phase = "results", stage = "overtime", tier = 2 }))).to.equal(
				OfficeAtmosphereConstants.NIGHT
			)
		end)

		it("darkens a step per pressure tier", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ tier = 1 }))).to.equal(OfficeAtmosphereConstants.TIER1)
			expect(OfficeAtmosphereUtils.preset(snapshot({ tier = 2 }))).to.equal(OfficeAtmosphereConstants.TIER2)
			expect(OfficeAtmosphereUtils.preset(snapshot({ stage = "warning", tier = 1 }))).to.equal(
				OfficeAtmosphereConstants.TIER1
			)
		end)

		it("lifts a little for Harlow's break", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ stage = "break", tier = 2 }))).to.equal(
				OfficeAtmosphereConstants.BREAK
			)
		end)

		it("picks overtime over the tier", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ stage = "overtime", tier = 2 }))).to.equal(
				OfficeAtmosphereConstants.OVERTIME
			)
		end)

		it("only names registered presets", function()
			for _, name in
				{
					OfficeAtmosphereConstants.NIGHT,
					OfficeAtmosphereConstants.TIER1,
					OfficeAtmosphereConstants.TIER2,
					OfficeAtmosphereConstants.BREAK,
					OfficeAtmosphereConstants.OVERTIME,
				}
			do
				expect(OfficeAtmosphereConstants.PRESETS[name]).to.be.ok()
			end
		end)
	end)

	describe("overtime", function()
		it("turns the lights red only while overtime runs", function()
			expect(OfficeAtmosphereUtils.overtime(snapshot({ stage = "overtime" }))).to.equal(true)
			expect(OfficeAtmosphereUtils.overtime(snapshot({ stage = "warning" }))).to.equal(false)
		end)

		it("drops overtime when the run ends", function()
			expect(OfficeAtmosphereUtils.overtime(snapshot({ phase = "results", stage = "overtime" }))).to.equal(false)
			expect(OfficeAtmosphereUtils.overtime(nil)).to.equal(false)
		end)
	end)

	describe("hum", function()
		it("hums whenever the office is in a shift", function()
			expect(OfficeAtmosphereUtils.hum(snapshot())).to.equal(true)
			expect(OfficeAtmosphereUtils.hum(snapshot({ phase = "results" }))).to.equal(true)
			expect(OfficeAtmosphereUtils.hum(snapshot({ phase = "lobby" }))).to.equal(false)
			expect(OfficeAtmosphereUtils.hum(nil)).to.equal(false)
		end)
	end)
end
