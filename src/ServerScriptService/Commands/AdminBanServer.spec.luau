local ServerScriptService = game:GetService("ServerScriptService")

local ban = require(ServerScriptService.Commands.AdminBanServer)

return function()
	describe("AdminBanServer", function()
		it("answers a bad input without calling Roblox", function()
			expect(ban(nil, 0, 1, "x"):find("Not banned")).to.be.ok()
			expect(ban(nil, 5, 1, ""):find("reason")).to.be.ok()
			expect(ban(nil, 5, -2, "x"):find("days")).to.be.ok()
		end)
	end)
end
