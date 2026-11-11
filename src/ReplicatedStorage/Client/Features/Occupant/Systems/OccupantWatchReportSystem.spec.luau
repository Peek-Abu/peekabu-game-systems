local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantWatchReportSystem = require(script.Parent.OccupantWatchReportSystem)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local function rig(kind)
	local model = Instance.new("Model")
	if kind ~= nil then
		model:SetAttribute(C.KIND_ATTRIBUTE, kind)
	end
	return model
end

return function()
	describe("freezeKindOut", function()
		it("is true while a freeze kind's rig exists", function()
			local bramble = rig("bramble")
			expect(OccupantWatchReportSystem.freezeKindOut({ bramble })).to.equal(true)
			bramble:Destroy()
		end)

		it("is false for Harlow (with or without the attribute) and with no rig at all", function()
			local harlow = rig("harlow")
			local bare = rig(nil)
			expect(OccupantWatchReportSystem.freezeKindOut({ harlow, bare })).to.equal(false)
			expect(OccupantWatchReportSystem.freezeKindOut({})).to.equal(false)
			harlow:Destroy()
			bare:Destroy()
		end)

		it("ignores a tagged instance that is not a model", function()
			local part = Instance.new("Part")
			part:SetAttribute(C.KIND_ATTRIBUTE, "bramble")
			expect(OccupantWatchReportSystem.freezeKindOut({ part })).to.equal(false)
			part:Destroy()
		end)
	end)
end
