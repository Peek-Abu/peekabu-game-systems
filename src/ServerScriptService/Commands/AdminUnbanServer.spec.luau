local ServerScriptService = game:GetService("ServerScriptService")

local unban = require(ServerScriptService.Commands.AdminUnbanServer)

return function()
	describe("AdminUnbanServer", function()
		it("answers a bad user id without calling Roblox", function()
			expect(unban(nil, -1):find("Not unbanned")).to.be.ok()
			expect(unban(nil, 2.5):find("Not unbanned")).to.be.ok()
		end)
	end)
end
