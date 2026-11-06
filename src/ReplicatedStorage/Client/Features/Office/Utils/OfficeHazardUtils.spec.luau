local OfficeHazardUtils = require(script.Parent.OfficeHazardUtils)

return function()
	describe("lit", function()
		it("is on for the first ON seconds of each period and off for the rest", function()
			expect(OfficeHazardUtils.lit(0, 1, 0.5)).to.equal(true)
			expect(OfficeHazardUtils.lit(0.49, 1, 0.5)).to.equal(true)
			expect(OfficeHazardUtils.lit(0.5, 1, 0.5)).to.equal(false)
			expect(OfficeHazardUtils.lit(0.99, 1, 0.5)).to.equal(false)
			expect(OfficeHazardUtils.lit(1, 1, 0.5)).to.equal(true)
		end)

		it("keeps every lamp in step: the same clock gives the same answer, far into a server's life", function()
			local now = 1762430000.25
			expect(OfficeHazardUtils.lit(now, 1, 0.5)).to.equal(true)
			expect(OfficeHazardUtils.lit(now + 0.5, 1, 0.5)).to.equal(false)
			expect(OfficeHazardUtils.lit(now + 7, 1, 0.5)).to.equal(true)
		end)

		it("stays off for a period of 0 or less, and on all the time when ON covers the period", function()
			expect(OfficeHazardUtils.lit(3, 0, 0.5)).to.equal(false)
			expect(OfficeHazardUtils.lit(0.9, 1, 1)).to.equal(true)
		end)
	end)

	describe("isLamp", function()
		it("finds a hazard lamp by its name under a part (the yard dressing's corner lights)", function()
			local lens = Instance.new("Part")
			local lamp = Instance.new("Attachment")
			lamp.Name = "HazardLamp"
			lamp.Parent = lens
			expect(OfficeHazardUtils.isLamp(lamp, "HazardLamp")).to.equal(true)
			lens:Destroy()
		end)

		it("ignores other names, non-attachments and a lamp not on a part", function()
			local lens = Instance.new("Part")
			local other = Instance.new("Attachment")
			other.Name = "Glow"
			other.Parent = lens
			local folder = Instance.new("Folder")
			folder.Name = "HazardLamp"
			folder.Parent = lens
			expect(OfficeHazardUtils.isLamp(other, "HazardLamp")).to.equal(false)
			expect(OfficeHazardUtils.isLamp(folder, "HazardLamp")).to.equal(false)
			local loose = Instance.new("Attachment")
			loose.Name = "HazardLamp"
			expect(OfficeHazardUtils.isLamp(loose, "HazardLamp")).to.equal(false)
			lens:Destroy()
			loose:Destroy()
		end)
	end)
end
