local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotAtmosphereConstants = require(script.Parent.DepotAtmosphereConstants)
local OfficeAtmosphereConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants)

local function luma(color)
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
end

return function()
	local evening = DepotAtmosphereConstants.PRESETS[DepotAtmosphereConstants.EVENING]

	it("names a preset it defines, apart from the office's", function()
		expect(evening).to.be.ok()
		expect(OfficeAtmosphereConstants.PRESETS[DepotAtmosphereConstants.EVENING]).to.equal(nil)
	end)

	it("sets every value the atmosphere system manages, within the registry's limits", function()
		expect(evening.clockTime >= 0 and evening.clockTime <= 24).to.equal(true)
		expect(evening.brightness >= 0).to.equal(true)
		expect(evening.exposure).to.be.ok()
		expect(evening.outdoorAmbient).to.be.ok()
		expect(evening.fogStart <= evening.fogEnd).to.equal(true)
	end)

	it("is dusk, not day or midnight", function()
		expect(evening.clockTime >= 17 and evening.clockTime <= 20).to.equal(true)
	end)

	it("is warm: the ambient and the fog lean orange", function()
		expect(evening.ambient.R > evening.ambient.B).to.equal(true)
		expect(evening.ambient.R >= evening.ambient.G).to.equal(true)
		expect(evening.fogColor.R > evening.fogColor.B).to.equal(true)
	end)

	it("stays readable: brighter than the office at night, and the fog clears the whole garage", function()
		local night = OfficeAtmosphereConstants.PRESETS[OfficeAtmosphereConstants.NIGHT]
		expect(luma(evening.ambient) > luma(night.ambient)).to.equal(true)
		expect(evening.brightness > night.brightness).to.equal(true)
		expect(evening.exposure > night.exposure).to.equal(true)
		-- The garage is 96 x 72: no wall is lost in fog from anywhere inside it.
		expect(evening.fogStart >= 120).to.equal(true)
	end)

	it("is a warm fill, not a tint: characters keep their own colours", function()
		-- Measured live: (138, 104, 76) on top of the strips washed a lavender skin pink-white. The ambient stays
		-- below this brightness and leans orange only a little.
		expect(luma(evening.ambient) <= 0.41).to.equal(true)
		expect(evening.ambient.R - evening.ambient.B <= 0.18).to.equal(true)
		expect(luma(evening.outdoorAmbient) <= luma(evening.ambient)).to.equal(true)
	end)
end
