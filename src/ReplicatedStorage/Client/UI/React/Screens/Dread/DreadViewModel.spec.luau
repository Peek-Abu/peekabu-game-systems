local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DreadViewModel = require(script.Parent.DreadViewModel)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local DREAD = OccupantConstants.DREAD

local function frame(extra)
	local value = { vignette = 0, grain = 0, edge = 0, still = false }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	it("draws nothing while the dread is off", function()
		expect(DreadViewModel.layers(frame(), 0)).to.equal(nil)
	end)

	it("darkens the edges up to VIGNETTE_MAX and tightens as it grows", function()
		local light = DreadViewModel.layers(frame({ vignette = 0.2 }), 0)
		local full = DreadViewModel.layers(frame({ vignette = 1 }), 0)
		expect(full.vignetteTransparency).to.be.near(1 - DREAD.VIGNETTE_MAX, 1e-9)
		expect(light.vignetteTransparency > full.vignetteTransparency).to.equal(true)
		expect(full.vignetteScale).to.be.near(1, 1e-9)
		expect(light.vignetteScale > full.vignetteScale).to.equal(true)
	end)

	it("shows grain up to GRAIN_MAX, jittered over time unless still", function()
		local a = DreadViewModel.layers(frame({ grain = 1 }), 0)
		local b = DreadViewModel.layers(frame({ grain = 1 }), 0.5)
		expect(a.grainTransparency).to.be.near(1 - DREAD.GRAIN_MAX, 1e-9)
		expect(a.grainOffset ~= b.grainOffset).to.equal(true)
		local stillA = DreadViewModel.layers(frame({ grain = 1, still = true }), 0)
		local stillB = DreadViewModel.layers(frame({ grain = 1, still = true }), 0.5)
		expect(stillA.grainOffset).to.equal(stillB.grainOffset)
	end)

	it("splits the edge fringe apart on the beat", function()
		local rest = DreadViewModel.layers(frame({ vignette = 0.5 }), 0)
		local beat = DreadViewModel.layers(frame({ vignette = 0.5, edge = 1 }), 0)
		expect(rest.edgeTransparency).to.equal(1)
		expect(beat.edgeTransparency < 1).to.equal(true)
		expect(beat.redScale - beat.cyanScale).to.be.near(DREAD.EDGE_SPREAD * 1.5, 1e-9)
	end)
end
