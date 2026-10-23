local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeAtmosphereUtils = require(script.Parent.OfficeAtmosphereUtils)
local OfficeAtmosphereConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants)
local DepotAtmosphereConstants = require(ReplicatedStorage.Client.Features.Depot.Data.DepotAtmosphereConstants)

local ME = 101
local OTHER = 202

local function snapshot(overrides)
	local base = { phase = "running", sub = "normal", stage = "normal", tier = 0, quotaMet = false, crew = { ME } }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	describe("preset", function()
		it("is the depot's evening outside a shift, so a shift's lighting never outlasts it", function()
			expect(OfficeAtmosphereUtils.preset(nil, ME)).to.equal(DepotAtmosphereConstants.EVENING)
			expect(OfficeAtmosphereUtils.preset(snapshot({ phase = "lobby", crew = {} }), ME)).to.equal(
				DepotAtmosphereConstants.EVENING
			)
		end)

		it("keeps a player off the crew in the depot's evening while another crew works", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ crew = { OTHER }, tier = 2 }), ME)).to.equal(
				DepotAtmosphereConstants.EVENING
			)
			expect(OfficeAtmosphereUtils.preset(snapshot({ crew = { OTHER }, stage = "overtime" }), ME)).to.equal(
				DepotAtmosphereConstants.EVENING
			)
		end)

		it("is night from the arrival countdown through the results", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ phase = "starting" }), ME)).to.equal(
				OfficeAtmosphereConstants.NIGHT
			)
			expect(OfficeAtmosphereUtils.preset(snapshot(), ME)).to.equal(OfficeAtmosphereConstants.NIGHT)
			expect(OfficeAtmosphereUtils.preset(snapshot({ phase = "results", stage = "overtime", tier = 2 }), ME)).to.equal(
				OfficeAtmosphereConstants.NIGHT
			)
		end)

		it("darkens a step per pressure tier", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ tier = 1 }), ME)).to.equal(OfficeAtmosphereConstants.TIER1)
			expect(OfficeAtmosphereUtils.preset(snapshot({ tier = 2 }), ME)).to.equal(OfficeAtmosphereConstants.TIER2)
			expect(OfficeAtmosphereUtils.preset(snapshot({ stage = "warning", tier = 1 }), ME)).to.equal(
				OfficeAtmosphereConstants.TIER1
			)
		end)

		it("lifts a little for Harlow's break", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ stage = "break", tier = 2 }), ME)).to.equal(
				OfficeAtmosphereConstants.BREAK
			)
		end)

		it("picks overtime over the tier", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ stage = "overtime", tier = 2 }), ME)).to.equal(
				OfficeAtmosphereConstants.OVERTIME
			)
		end)

		it("is the moonlit exterior outside, for the whole shift, whatever the tier or break", function()
			expect(OfficeAtmosphereUtils.preset(snapshot(), ME, true)).to.equal("officeExterior")
			expect(OfficeAtmosphereUtils.preset(snapshot({ tier = 2 }), ME, true)).to.equal("officeExterior")
			expect(OfficeAtmosphereUtils.preset(snapshot({ stage = "break", tier = 1 }), ME, true)).to.equal(
				"officeExterior"
			)
			expect(OfficeAtmosphereUtils.preset(snapshot({ phase = "results" }), ME, true)).to.equal("officeExterior")
		end)

		it("turns the exterior red in overtime", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ stage = "overtime" }), ME, true)).to.equal(
				"officeExteriorOvertime"
			)
		end)

		it("keeps every inside answer when outside is nil or false", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ tier = 2 }), ME, false)).to.equal(
				OfficeAtmosphereConstants.TIER2
			)
			expect(OfficeAtmosphereUtils.preset(snapshot({ stage = "overtime" }), ME, nil)).to.equal(
				OfficeAtmosphereConstants.OVERTIME
			)
		end)

		it("is the depot's evening in the hub even when outside", function()
			expect(OfficeAtmosphereUtils.preset(nil, ME, true)).to.equal(DepotAtmosphereConstants.EVENING)
			expect(OfficeAtmosphereUtils.preset(snapshot({ crew = { OTHER } }), ME, true)).to.equal(
				DepotAtmosphereConstants.EVENING
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
					OfficeAtmosphereConstants.EXTERIOR,
					OfficeAtmosphereConstants.EXTERIOR_OVERTIME,
				}
			do
				expect(OfficeAtmosphereConstants.PRESETS[name]).to.be.ok()
			end
		end)
	end)

	describe("overtime", function()
		it("turns the lights red only while overtime runs", function()
			expect(OfficeAtmosphereUtils.overtime(snapshot({ stage = "overtime" }), ME)).to.equal(true)
			expect(OfficeAtmosphereUtils.overtime(snapshot({ stage = "warning" }), ME)).to.equal(false)
		end)

		it("drops overtime when the run ends", function()
			expect(OfficeAtmosphereUtils.overtime(snapshot({ phase = "results", stage = "overtime" }), ME)).to.equal(
				false
			)
			expect(OfficeAtmosphereUtils.overtime(nil, ME)).to.equal(false)
		end)

		it("never tints the hub red while another crew is in overtime", function()
			expect(OfficeAtmosphereUtils.overtime(snapshot({ stage = "overtime", crew = { OTHER } }), ME)).to.equal(
				false
			)
		end)
	end)

	describe("hum", function()
		it("hums whenever the office is in a shift", function()
			expect(OfficeAtmosphereUtils.hum(snapshot(), ME)).to.equal(true)
			expect(OfficeAtmosphereUtils.hum(snapshot({ phase = "results" }), ME)).to.equal(true)
			expect(OfficeAtmosphereUtils.hum(snapshot({ phase = "lobby" }), ME)).to.equal(false)
			expect(OfficeAtmosphereUtils.hum(nil, ME)).to.equal(false)
		end)

		it("keeps the hub quiet while another crew works", function()
			expect(OfficeAtmosphereUtils.hum(snapshot({ crew = { OTHER } }), ME)).to.equal(false)
		end)
	end)

	describe("hum outside", function()
		it("is silent outside", function()
			expect(OfficeAtmosphereUtils.hum(snapshot(), ME, true)).to.equal(false)
			expect(OfficeAtmosphereUtils.hum(snapshot(), ME, false)).to.equal(true)
		end)
	end)

	describe("outdoors", function()
		local boxes = {
			{ min = Vector3.new(0, 0, 0), max = Vector3.new(10, 120, 10) },
			{ min = Vector3.new(100, 0, 100), max = Vector3.new(120, 120, 120) },
		}

		it("is true inside any box", function()
			expect(OfficeAtmosphereUtils.outdoors(Vector3.new(5, 3, 5), boxes)).to.equal(true)
			expect(OfficeAtmosphereUtils.outdoors(Vector3.new(110, 50, 110), boxes)).to.equal(true)
		end)

		it("is false outside every box", function()
			expect(OfficeAtmosphereUtils.outdoors(Vector3.new(50, 3, 50), boxes)).to.equal(false)
			expect(OfficeAtmosphereUtils.outdoors(Vector3.new(5, 130, 5), boxes)).to.equal(false)
			expect(OfficeAtmosphereUtils.outdoors(Vector3.new(5, 3, 5), {})).to.equal(false)
		end)

		it("counts a point just past a box edge as outdoors when padded, never one far inside the office", function()
			local past = Vector3.new(20, 3, 5)
			expect(OfficeAtmosphereUtils.outdoors(past, boxes)).to.equal(false)
			expect(OfficeAtmosphereUtils.outdoors(past, boxes, 15)).to.equal(true)
			expect(OfficeAtmosphereUtils.outdoors(past, boxes, 9)).to.equal(false)
			expect(OfficeAtmosphereUtils.outdoors(Vector3.new(-5000, 3, -5000), boxes, 15)).to.equal(false)
		end)
	end)
end
