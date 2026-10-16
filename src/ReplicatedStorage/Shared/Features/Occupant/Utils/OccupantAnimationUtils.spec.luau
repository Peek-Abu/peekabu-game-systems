local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantAnimationUtils = require(script.Parent.OccupantAnimationUtils)
local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)

local function slot(assetId, looped)
	return {
		assetId = assetId,
		looped = looped,
		priority = Enum.AnimationPriority.Movement,
		interruption = "ambient",
	}
end

local function hasOnly(ids)
	return function(id)
		return table.find(ids, id) ~= nil
	end
end

return function()
	describe("domain", function()
		it("keeps uploaded slots, copied as animation entries", function()
			local domain = OccupantAnimationUtils.domain({
				harlowWalk = slot("rbxassetid://1", true),
				harlowLook = slot("", true),
			}, "")
			expect(domain.harlowWalk).to.be.ok()
			expect(domain.harlowWalk.assetId).to.equal("rbxassetid://1")
			expect(domain.harlowWalk.looped).to.equal(true)
			expect(domain.harlowWalk.priority).to.equal(Enum.AnimationPriority.Movement)
			expect(domain.harlowWalk.interruption).to.equal("ambient")
			expect(domain.harlowLook).to.equal(nil)
		end)

		it("is empty while everything is pending", function()
			expect(next(OccupantAnimationUtils.domain({ harlowWalk = slot("", true) }, ""))).to.equal(nil)
		end)
	end)

	describe("poses", function()
		it("falls back to the base locomotion clips while Harlow's are pending", function()
			local poses = OccupantAnimationUtils.poses(hasOnly({ "idle", "walk", "run" }))
			expect(poses.idle).to.equal("idle")
			expect(poses.walk).to.equal("walk")
			expect(poses.run).to.equal("run")
		end)

		it("uses his lurch walk and look-around once uploaded, the base run without his own", function()
			local poses = OccupantAnimationUtils.poses(hasOnly({ "idle", "walk", "run", "harlowWalk", "harlowLook" }))
			expect(poses.walk).to.equal("harlowWalk")
			expect(poses.idle).to.equal("harlowLook")
			expect(poses.run).to.equal("run")
			expect(OccupantAnimationUtils.poses(hasOnly({ "harlowRun" })).run).to.equal("harlowRun")
		end)

		it(
			"names his own clips' planted speeds, so the base plays them at his speed; none for the base clips",
			function()
				local own = OccupantAnimationUtils.poses(hasOnly({ "harlowWalk", "harlowRun" }))
				expect(own.walkPlantedSpeed).to.equal(OccupantAssets.PLANTED_SPEEDS.harlowWalk)
				expect(own.runPlantedSpeed).to.equal(OccupantAssets.PLANTED_SPEEDS.harlowRun)
				local base = OccupantAnimationUtils.poses(hasOnly({ "walk", "run" }))
				expect(base.walkPlantedSpeed).to.equal(nil)
				expect(base.runPlantedSpeed).to.equal(nil)
			end
		)
	end)

	describe("action", function()
		it("names an uploaded action, nothing otherwise", function()
			expect(OccupantAnimationUtils.action("harlowGrab", hasOnly({ "harlowGrab" }))).to.equal("harlowGrab")
			expect(OccupantAnimationUtils.action("harlowThrow", hasOnly({ "harlowGrab" }))).to.equal(nil)
		end)
	end)
end
