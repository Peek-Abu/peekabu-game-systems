local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraFadeFormulas = require(script.Parent.CameraFadeFormulas)
local CameraConstants = require(ReplicatedStorage.Client.Features.Camera.Data.CameraConstants)

return function()
	describe("transparency", function()
		it("leaves the subject opaque at or beyond the far distance", function()
			expect(CameraFadeFormulas.transparency(3, 1, 3)).to.equal(0)
			expect(CameraFadeFormulas.transparency(13, 1, 3)).to.equal(0)
		end)

		it("hides the subject at or inside the near distance", function()
			expect(CameraFadeFormulas.transparency(1, 1, 3)).to.equal(1)
			expect(CameraFadeFormulas.transparency(0.2, 1, 3)).to.equal(1)
		end)

		it("fades linearly between the two", function()
			expect(CameraFadeFormulas.transparency(2, 1, 3)).to.be.near(0.5, 1e-9)
			expect(CameraFadeFormulas.transparency(2.5, 1, 3)).to.be.near(0.25, 1e-9)
		end)

		it("with the game's tuning, never fades less than the engine's own camera fade at the same distance", function()
			-- The engine (PlayerModule TransparencyController): 1 - (d - 0.5) / 1.5 under 2 studs, 0 below 0.5 of it.
			for step = 0, 40 do
				local distance = step * 0.05
				local engine = if distance < 2 then 1 - (distance - 0.5) / 1.5 else 0
				if engine < 0.5 then
					engine = 0
				end
				engine = math.clamp(engine, 0, 1)
				local ours =
					CameraFadeFormulas.transparency(distance, CameraConstants.FADE_NEAR, CameraConstants.FADE_FAR)
				expect(ours >= engine - 1e-9).to.equal(true)
			end
		end)

		it("with the game's tuning, never fades at the closest zoom the player may pick", function()
			-- Measured to the head, which rides up to about a stud above the focus the zoom is measured from.
			expect(
				CameraFadeFormulas.transparency(
					CameraConstants.MIN_ZOOM_DISTANCE - 1,
					CameraConstants.FADE_NEAR,
					CameraConstants.FADE_FAR
				)
			).to.equal(0)
		end)
	end)
end
