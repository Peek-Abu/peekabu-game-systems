local FilmConstants = require(script.Parent.FilmConstants)

return function()
	it("hides the UI on F6: a key the game does not use, and not F7, which Roblox reserves", function()
		expect(FilmConstants.HIDE_KEY).to.equal(Enum.KeyCode.F6)
	end)

	it("turns the film camera on F8, above every other camera mode", function()
		expect(FilmConstants.CAMERA_KEY).to.equal(Enum.KeyCode.F8)
		expect(FilmConstants.CAMERA_PRIORITY > 100).to.equal(true)
	end)

	it("keeps the admin console showing so the UI can be brought back", function()
		expect(FilmConstants.KEEP_GUIS.Cmdr).to.equal(true)
	end)

	it("has a normal light preset at no change, darker below it and brighter above it", function()
		local presets = FilmConstants.LIGHT_PRESETS
		expect(presets.normal).to.equal(0)
		expect(presets.dark < 0).to.equal(true)
		expect(presets.bright > 0).to.equal(true)
		for _, value in presets do
			expect(math.abs(value) <= 2).to.equal(true)
		end
	end)
end
