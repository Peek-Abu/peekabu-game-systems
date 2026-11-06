local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeShadowUtils = require(ReplicatedStorage.Client.Features.Office.Utils.OfficeShadowUtils)

local SMALL = Vector3.new(1, 1, 1)
local BIG = Vector3.new(12, 10, 1)

return function()
	describe("smallProp", function()
		it("is small when every side is under the size limit", function()
			expect(OfficeShadowUtils.smallProp(SMALL)).to.equal(true)
			expect(OfficeShadowUtils.smallProp(BIG)).to.equal(false)
			expect(OfficeShadowUtils.smallProp(Vector3.new(1, 1, OfficeShadowUtils.SIZE_LIMIT))).to.equal(false)
		end)
	end)

	describe("propShadows", function()
		it("on: small props always cast shadows", function()
			expect(OfficeShadowUtils.propShadows("on", 1, true)).to.equal(true)
		end)

		it("off: small props never cast shadows", function()
			expect(OfficeShadowUtils.propShadows("off", 10, false)).to.equal(false)
		end)

		it("auto: off at graphics 1-3 and on a phone left on Automatic, on otherwise", function()
			expect(OfficeShadowUtils.propShadows("auto", 3, false)).to.equal(false)
			expect(OfficeShadowUtils.propShadows("auto", 4, false)).to.equal(true)
			expect(OfficeShadowUtils.propShadows("auto", nil, true)).to.equal(false)
			expect(OfficeShadowUtils.propShadows("auto", nil, false)).to.equal(true)
			-- A phone whose player picked a high level keeps them.
			expect(OfficeShadowUtils.propShadows("auto", 8, true)).to.equal(true)
		end)
	end)

	describe("qualityOf", function()
		it("reads QualityLevel1-10 as 1-10 and Automatic as nil", function()
			expect(OfficeShadowUtils.qualityOf(Enum.SavedQualitySetting.QualityLevel3)).to.equal(3)
			expect(OfficeShadowUtils.qualityOf(Enum.SavedQualitySetting.QualityLevel10)).to.equal(10)
			expect(OfficeShadowUtils.qualityOf(Enum.SavedQualitySetting.Automatic)).to.equal(nil)
		end)
	end)
end
