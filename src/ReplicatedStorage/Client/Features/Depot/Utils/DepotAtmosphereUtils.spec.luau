local DepotAtmosphereUtils = require(script.Parent.DepotAtmosphereUtils)

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
	describe("inHub", function()
		it("is the hub before the first sync and in the lobby", function()
			expect(DepotAtmosphereUtils.inHub(nil, ME)).to.equal(true)
			expect(DepotAtmosphereUtils.inHub(snapshot({ phase = "lobby", crew = {} }), ME)).to.equal(true)
		end)

		it("is the hub for a player who is not on the running crew (both roles in one server)", function()
			expect(DepotAtmosphereUtils.inHub(snapshot({ crew = { OTHER } }), ME)).to.equal(true)
			expect(DepotAtmosphereUtils.inHub(snapshot({ phase = "results", crew = { OTHER } }), ME)).to.equal(true)
		end)

		it("is not the hub for the crew, from the arrival countdown through the results", function()
			expect(DepotAtmosphereUtils.inHub(snapshot({ phase = "starting" }), ME)).to.equal(false)
			expect(DepotAtmosphereUtils.inHub(snapshot(), ME)).to.equal(false)
			expect(DepotAtmosphereUtils.inHub(snapshot({ phase = "results" }), ME)).to.equal(false)
		end)
	end)
end
