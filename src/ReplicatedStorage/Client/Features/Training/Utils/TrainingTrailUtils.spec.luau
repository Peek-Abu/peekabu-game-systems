local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingTrailUtils = require(ReplicatedStorage.Client.Features.Training.Utils.TrainingTrailUtils)

return function()
	describe("segments", function()
		it("joins the path's points into legs, dropping points too close together", function()
			local legs = TrainingTrailUtils.segments({
				Vector3.new(0, 0, 0),
				Vector3.new(0.2, 0, 0),
				Vector3.new(10, 0, 0),
				Vector3.new(10, 0, 10),
			}, 1)
			expect(#legs).to.equal(2)
			expect(legs[1].from).to.equal(Vector3.new(0, 0, 0))
			expect(legs[1].to).to.equal(Vector3.new(10, 0, 0))
			expect(legs[2].to).to.equal(Vector3.new(10, 0, 10))
		end)

		it("merges straight runs into one leg", function()
			local legs = TrainingTrailUtils.segments({
				Vector3.new(0, 0, 0),
				Vector3.new(4, 0, 0),
				Vector3.new(8, 0, 0),
				Vector3.new(12, 0, 0),
			}, 1)
			expect(#legs).to.equal(1)
			expect(legs[1].to).to.equal(Vector3.new(12, 0, 0))
		end)

		it("has no legs for one point or none", function()
			expect(#TrainingTrailUtils.segments({ Vector3.zero }, 1)).to.equal(0)
			expect(#TrainingTrailUtils.segments({}, 1)).to.equal(0)
		end)
	end)

	describe("trimStart", function()
		it("starts the trail a little ahead of the player's feet", function()
			local legs = TrainingTrailUtils.segments({ Vector3.new(0, 0, 0), Vector3.new(10, 0, 0) }, 1)
			local trimmed = TrainingTrailUtils.trimStart(legs, 2)
			expect(trimmed[1].from).to.equal(Vector3.new(2, 0, 0))
		end)

		it("drops a first leg shorter than the trim", function()
			local legs = TrainingTrailUtils.segments({
				Vector3.new(0, 0, 0),
				Vector3.new(1.5, 0, 0),
				Vector3.new(1.5, 0, 10),
			}, 1)
			local trimmed = TrainingTrailUtils.trimStart(legs, 2)
			expect(#trimmed).to.equal(1)
			expect(trimmed[1].from).to.equal(Vector3.new(1.5, 0, 0.5))
		end)
	end)

	describe("bob", function()
		it("rises and falls between 0 and its height", function()
			for t = 0, 3, 0.25 do
				local y = TrainingTrailUtils.bob(t, 0.6, 3)
				expect(y >= 0 and y <= 0.6 + 1e-6).to.equal(true)
			end
		end)
	end)

	describe("repath", function()
		it("re-paths after moving far enough or waiting long enough", function()
			local here = Vector3.new(0, 0, 0)
			expect(TrainingTrailUtils.repath(nil, here, 0, 0, 4, 0.75)).to.equal(true)
			expect(TrainingTrailUtils.repath(here, Vector3.new(1, 0, 0), 0, 0.1, 4, 0.75)).to.equal(false)
			expect(TrainingTrailUtils.repath(here, Vector3.new(5, 0, 0), 0, 0.1, 4, 0.75)).to.equal(true)
			expect(TrainingTrailUtils.repath(here, here, 0, 0.8, 4, 0.75)).to.equal(true)
		end)
	end)
end
