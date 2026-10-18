local CameraOcclusionFormulas = require(script.Parent.CameraOcclusionFormulas)

return function()
	describe("limit", function()
		it("snaps in at once when something comes between the subject and the camera", function()
			expect(CameraOcclusionFormulas.limit(12, 3, 1 / 60, 8)).to.equal(3)
		end)

		it("eases back out, frame-rate independently, never past the clear distance", function()
			local a = CameraOcclusionFormulas.limit(3, 12, 1 / 30, 8)
			local b = CameraOcclusionFormulas.limit(CameraOcclusionFormulas.limit(3, 12, 1 / 60, 8), 12, 1 / 60, 8)
			expect(a > 3 and a < 12).to.equal(true)
			expect(math.abs(a - b) < 1e-9).to.equal(true)
			expect(CameraOcclusionFormulas.limit(3, 12, 100, 8)).to.equal(12)
		end)

		it("starts at the clear distance when there was no limit", function()
			expect(CameraOcclusionFormulas.limit(nil, 7, 1 / 60, 8)).to.equal(7)
		end)
	end)

	describe("applies", function()
		it("only pulls the camera in when the limit is closer than the engine put it", function()
			expect(CameraOcclusionFormulas.applies(10, 4)).to.equal(true)
			expect(CameraOcclusionFormulas.applies(4, 10)).to.equal(false)
			expect(CameraOcclusionFormulas.applies(10, 10 - 1e-4)).to.equal(false)
		end)
	end)
end
