local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantCameraReportUtils = require(script.Parent.OccupantCameraReportUtils)
local OccupantWatchRules = require(ServerScriptService.Features.Occupant.Rules.OccupantWatchRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local function data(extra)
	local value = {
		position = Vector3.new(1, 2, 3),
		look = Vector3.new(0, 0, 4),
		up = Vector3.new(0, 2, 0),
		fov = 70,
		aspect = 16 / 9,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("parseReport", function()
		it("keeps a finite camera with a unit look, an up square to it, and its screen", function()
			local report = OccupantCameraReportUtils.parseReport(data())
			expect(report).to.be.ok()
			expect(report.position).to.equal(Vector3.new(1, 2, 3))
			expect(report.look.Magnitude).to.be.near(1, 1e-6)
			expect(report.look.Z).to.be.near(1, 1e-6)
			expect(report.up.Magnitude).to.be.near(1, 1e-6)
			expect(report.up:Dot(report.look)).to.be.near(0, 1e-6)
			expect(report.receivedAt).to.equal(0)
			local tanV, tanH = OccupantWatchRules.screen(70, 16 / 9)
			expect(report.tanV).to.be.near(tanV, 1e-6)
			expect(report.tanH).to.be.near(tanH, 1e-6)
		end)

		it("squares a tilted up to the look, and falls back to world up for a broken one", function()
			local tilted = OccupantCameraReportUtils.parseReport(data({ up = Vector3.new(0, 1, 1) }))
			expect(tilted.up:Dot(tilted.look)).to.be.near(0, 1e-6)
			expect(tilted.up.Y).to.be.near(1, 1e-6)
			local broken = OccupantCameraReportUtils.parseReport(data({ up = Vector3.new(0, 0, 3) }))
			expect(broken.up:Dot(broken.look)).to.be.near(0, 1e-6)
			expect(broken.up.Y).to.be.near(1, 1e-6)
		end)

		it("looking straight up with a broken up, squares world forward instead", function()
			local report =
				OccupantCameraReportUtils.parseReport(data({ look = Vector3.new(0, 5, 0), up = Vector3.yAxis }))
			expect(report.up:Dot(report.look)).to.be.near(0, 1e-6)
			expect(report.up.Z).to.be.near(1, 1e-6)
		end)

		it("clamps a forged FOV and aspect to a real screen", function()
			local wide = OccupantCameraReportUtils.parseReport(data({ fov = 179, aspect = 40 }))
			local tanV, tanH = OccupantWatchRules.screen(C.FREEZE_FOV_MAX, C.FREEZE_ASPECT_MAX)
			expect(wide.tanV).to.be.near(tanV, 1e-6)
			expect(wide.tanH).to.be.near(tanH, 1e-6)
		end)

		it("refuses a zero look, NaN or infinity anywhere", function()
			local nan = 0 / 0
			expect(OccupantCameraReportUtils.parseReport(data({ look = Vector3.zero }))).to.equal(nil)
			expect(OccupantCameraReportUtils.parseReport(data({ position = Vector3.new(nan, 0, 0) }))).to.equal(nil)
			expect(OccupantCameraReportUtils.parseReport(data({ look = Vector3.new(math.huge, 0, 0) }))).to.equal(nil)
			expect(OccupantCameraReportUtils.parseReport(data({ fov = nan }))).to.equal(nil)
			expect(OccupantCameraReportUtils.parseReport(data({ aspect = math.huge }))).to.equal(nil)
		end)

		it("refuses a report whose position or look is not a vector", function()
			expect(OccupantCameraReportUtils.parseReport(data({ position = 5 }))).to.equal(nil)
			expect(OccupantCameraReportUtils.parseReport(data({ look = "ahead" }))).to.equal(nil)
		end)
	end)
end
