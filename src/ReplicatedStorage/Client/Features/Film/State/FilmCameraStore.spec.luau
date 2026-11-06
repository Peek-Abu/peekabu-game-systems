local FilmCameraStore = require(script.Parent.FilmCameraStore)

return function()
	describe("FilmCameraStore", function()
		afterEach(function()
			FilmCameraStore.status(nil)
		end)

		it("shows no status line while the film camera is off", function()
			expect(FilmCameraStore.status()).to.equal(nil)
		end)

		it("holds the latest status line", function()
			FilmCameraStore.status("FILM CAM")
			expect(FilmCameraStore.status()).to.equal("FILM CAM")
			FilmCameraStore.status(nil)
			expect(FilmCameraStore.status()).to.equal(nil)
		end)
	end)
end
