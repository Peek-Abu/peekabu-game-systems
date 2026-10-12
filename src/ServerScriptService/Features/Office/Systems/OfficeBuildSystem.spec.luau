local Server = game:GetService("ServerScriptService").Features.Office
local Build = require(script.Parent.OfficeBuildSystem)
local Layout = require(Server.Data.OfficeLayoutConstants).LAYOUT
return function()
	local built
	afterEach(function()
		if built then
			built.model:Destroy()
			built = nil
		end
	end)
	describe("physical enclosure", function()
		it("builds collidable visible ceiling geometry", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0))
			local ceiling = built.model:FindFirstChild("Ceiling", true)
			expect(ceiling ~= nil).to.equal(true)
			expect(ceiling.CanCollide).to.equal(true)
			expect(ceiling.Transparency).to.equal(0)
		end)
	end)
end
