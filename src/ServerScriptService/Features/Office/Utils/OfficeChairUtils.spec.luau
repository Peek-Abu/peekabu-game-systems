local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService.Features.Office
local OfficeChairUtils = require(script.Parent.OfficeChairUtils)
local OfficeConstants = require(Server.Data.OfficeConstants)

return function()
	local desk = { id = "d1", room = "none", kind = "desk", x = 10, z = 20 }
	local alongZ = OfficeConstants.DESK_SIZE.Z / 2
		+ OfficeConstants.OFFICE_CHAIR_SIZE.Z / 2
		+ OfficeConstants.OFFICE_CHAIR_GAP

	describe("chairAt", function()
		it("puts the chair on the desk's -Z side when nothing is in the way", function()
			local layout = { rooms = {}, doors = {}, markers = { desk } }
			local frame = OfficeChairUtils.chairAt(layout, desk, CFrame.new())
			expect(frame).to.be.ok()
			expect((frame.Position - Vector3.new(10, 0, 20 - alongZ)).Magnitude < 0.001).to.equal(true)
		end)

		it("moves to the next side when floor furniture blocks the first", function()
			local cabinet = { id = "c1", room = "none", kind = "cabinet", x = 10, z = 20 - alongZ }
			local layout = { rooms = {}, doors = {}, markers = { desk, cabinet } }
			local frame = OfficeChairUtils.chairAt(layout, desk, CFrame.new())
			expect(frame).to.be.ok()
			expect((frame.Position - Vector3.new(10, 0, 20 + alongZ)).Magnitude < 0.001).to.equal(true)
		end)
	end)
end
